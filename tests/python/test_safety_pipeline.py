import csv
import json
from pathlib import Path

import pytest

from safety import pipeline


CRASH_HEADER = ["Zone", "Sub-division", "Station", "2023 - Fatal Cases", "2023 - Killed People", "2023 - Non-Fatal", "2023 - Injured People", "2023 - Total Cases"]
CRIME_HEADER = ["Type of Crime", "2021 Reported", "2021 Detected", "2022 Reported", "2022 Detected", "2023 Reported", "2023 Detected"]


def registry_fixture():
    registry = json.loads((pipeline.ROOT / "safety" / "registry.json").read_text(encoding="utf-8"))
    for dataset in registry["datasets"]:
        dataset["status"] = "catalogued_not_ingested"
    return registry


def write_rows(path: Path, columns: list[str], rows: list[dict]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)


def test_no_sources_yields_explicit_unavailable_empty_snapshot(tmp_path, monkeypatch):
    monkeypatch.setattr(pipeline, "RAW", tmp_path / "raw")
    monkeypatch.setattr(pipeline, "PROCESSED", tmp_path / "processed")
    monkeypatch.setattr(pipeline, "REGISTRY_PATH", tmp_path / "registry.json")
    pipeline.REGISTRY_PATH.write_text(json.dumps(registry_fixture()), encoding="utf-8")

    result = pipeline.process(registry_fixture())

    assert result["availability"] == "unavailable"
    assert result["accidents"]["records"] == []
    assert result["crimes"]["records"] == []
    assert "not live" in result["message"]


def test_valid_aggregates_normalize_without_inventing_coordinates(tmp_path, monkeypatch):
    monkeypatch.setattr(pipeline, "RAW", tmp_path / "raw")
    monkeypatch.setattr(pipeline, "PROCESSED", tmp_path / "processed")
    monkeypatch.setattr(pipeline, "REGISTRY_PATH", tmp_path / "registry.json")
    pipeline.REGISTRY_PATH.write_text(json.dumps(registry_fixture()), encoding="utf-8")
    write_rows(pipeline.RAW / "bengaluru_btp_station_crashes_2023" / "source.csv", CRASH_HEADER, [
        dict(zip(CRASH_HEADER, ["North", "A", "Station A", "2", "2", "10", "12", "12"])),
        dict(zip(CRASH_HEADER, ["South", "B", "Station B", "0", "0", "3", "3", "3"])),
    ])
    write_rows(pipeline.RAW / "bengaluru_bcp_crime_2023" / "source.csv", CRIME_HEADER, [
        dict(zip(CRIME_HEADER, ["Robbery", "4", "3", "5", "4", "7", "6"])),
        dict(zip(CRIME_HEADER, ["Theft", "20", "16", "22", "18", "25", "20"])),
    ])

    result = pipeline.process(registry_fixture())

    assert result["availability"] == "available"
    assert result["accidents"]["records"][0]["latitude"] is None
    assert result["accidents"]["records"][0]["totalCases"] == 12
    assert result["crimes"]["records"][0]["sourceCategory"] == "Robbery"
    assert result["crimes"]["records"][0]["reported2023"] == 7
    quality = json.loads((tmp_path / "processed" / "data_quality.json").read_text())
    assert quality["datasets"]["bengaluru_btp_station_crashes_2023"]["coordinateColumnsPresent"] is False


def test_schema_mismatch_and_duplicate_stations_are_rejected(tmp_path, monkeypatch):
    monkeypatch.setattr(pipeline, "RAW", tmp_path / "raw")
    monkeypatch.setattr(pipeline, "PROCESSED", tmp_path / "processed")
    monkeypatch.setattr(pipeline, "REGISTRY_PATH", tmp_path / "registry.json")
    registry = registry_fixture()
    pipeline.REGISTRY_PATH.write_text(json.dumps(registry), encoding="utf-8")
    write_rows(pipeline.RAW / "bengaluru_btp_station_crashes_2023" / "source.csv", ["Station"], [{"Station": "Station A"}])
    with pytest.raises(ValueError, match="missing expected columns"):
        pipeline.process(registry)

    write_rows(pipeline.RAW / "bengaluru_btp_station_crashes_2023" / "source.csv", CRASH_HEADER, [
        dict(zip(CRASH_HEADER, ["North", "A", "Station A", "1", "1", "2", "2", "3"])),
        dict(zip(CRASH_HEADER, ["North", "A", "station a", "1", "1", "2", "2", "3"])),
    ])
    with pytest.raises(ValueError, match="Duplicate police station"):
        pipeline.process(registry)
