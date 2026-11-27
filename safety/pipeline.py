"""Download, validate and aggregate official SOS safety datasets.

Raw source files are immutable and date-stamped. The script intentionally emits
aggregate station/city tables; it does not geocode or invent incident points.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import logging
import sqlite3
import time
from urllib.error import HTTPError
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / "safety" / "registry.json"
RAW = ROOT / "safety" / "data" / "raw"
PROCESSED = ROOT / "analytics" / "safety"
LOG = logging.getLogger("safety.pipeline")


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_registry() -> dict:
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def download_sources() -> dict:
    registry = read_registry()
    for dataset in registry["datasets"]:
        if dataset["id"] not in {"bengaluru_btp_station_crashes_2023", "bengaluru_bcp_crime_2023"}:
            continue
        folder = RAW / dataset["id"]
        folder.mkdir(parents=True, exist_ok=True)
        manual = folder / "source.csv"
        if manual.exists():
            LOG.info("Keeping manually supplied raw source: %s", manual)
            continue
        try:
            headers = {"User-Agent": "SOSenseSafetyPipeline/1.0"}
            if dataset.get("etag"):
                headers["If-None-Match"] = dataset["etag"]
            if dataset.get("httpLastModified"):
                headers["If-Modified-Since"] = dataset["httpLastModified"]
            request = Request(dataset["downloadUrl"], headers=headers)
            try:
                with urlopen(request, timeout=30) as response:
                    content = response.read()
                    etag = response.headers.get("ETag")
                    modified = response.headers.get("Last-Modified")
            except HTTPError as exc:
                if exc.code == 304:
                    dataset["lastCheckedAt"] = now()
                    dataset["status"] = "unchanged"
                    LOG.info("No publisher change for %s (HTTP 304)", dataset["id"])
                    continue
                raise
            if not content or content.lstrip().lower().startswith((b"<!doctype html", b"<html")):
                raise ValueError("Publisher returned an HTML challenge/error instead of source data")
            digest = hashlib.sha256(content).hexdigest()
            if digest == dataset.get("downloadSha256"):
                dataset["lastCheckedAt"] = now()
                dataset["etag"] = etag or dataset.get("etag")
                dataset["httpLastModified"] = modified or dataset.get("httpLastModified")
                dataset["status"] = "unchanged"
                LOG.info("Content hash unchanged for %s", dataset["id"])
                continue
            suffix = "csv" if dataset["format"] == "CSV" else "pdf"
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            target = folder / f"{stamp}_{digest[:12]}.{suffix}"
            target.write_bytes(content)
            dataset["lastDownloadedAt"] = now()
            dataset["lastCheckedAt"] = now()
            dataset["etag"] = etag
            dataset["httpLastModified"] = modified
            dataset["downloadSha256"] = digest
            dataset["downloadedFile"] = str(target.relative_to(ROOT)).replace("\\", "/")
            dataset["status"] = "downloaded_unvalidated"
            LOG.info("Downloaded %s (%d bytes)", dataset["id"], len(content))
        except Exception as exc:  # network/publisher failures are recorded, not replaced
            dataset["status"] = "download_failed"
            dataset["lastAttemptAt"] = now()
            dataset["lastError"] = f"{type(exc).__name__}: {exc}"[:300]
            LOG.error("Download failed for %s: %s", dataset["id"], exc)
            time.sleep(1)
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return registry


def load_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise ValueError(f"CSV has no header: {path}")
        return list(reader.fieldnames), list(reader)


def require_columns(dataset: dict, headers: list[str]) -> None:
    missing = sorted(set(dataset["expectedColumns"]) - set(headers))
    if missing:
        raise ValueError(f"{dataset['id']} missing expected columns: {missing}")


def number(value: str | None) -> int | None:
    if value is None or not value.strip():
        return None
    try:
        result = int(float(value.replace(",", "").strip()))
    except ValueError:
        return None
    return result if result >= 0 else None


def write_csv(path: Path, rows: list[dict], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def quartile_level(value: int, sorted_values: list[int]) -> str:
    # Relative recorded count tiers, not an absolute safety/danger judgment.
    n = len(sorted_values)
    rank = sum(v <= value for v in sorted_values) / n if n else 0
    if rank <= .25:
        return "lower_recorded_concentration"
    if rank <= .50:
        return "moderate_recorded_concentration"
    if rank <= .75:
        return "elevated_recorded_concentration"
    return "highest_recorded_concentration_in_dataset"


def process(registry: dict) -> dict:
    by_id = {d["id"]: d for d in registry["datasets"]}
    result = {
        "generatedAt": now(),
        "dataStatus": "historical",
        "availability": "unavailable",
        "message": "No verified source files have been processed. Safety records are not live.",
        "accidents": {"sourceId": "bengaluru_btp_station_crashes_2023", "reportingPeriod": "2023", "geographicPrecision": "police station aggregate; no coordinates", "records": []},
        "crimes": {"sourceId": "bengaluru_bcp_crime_2023", "reportingPeriod": "2021-2023", "geographicPrecision": "city aggregate; no coordinates", "records": []},
    }
    def raw_path(dataset_id: str) -> Path:
        source = by_id[dataset_id].get("downloadedFile")
        if source:
            resolved = ROOT / source
            if resolved.is_file():
                return resolved
        return RAW / dataset_id / "source.csv"

    acc_path = raw_path("bengaluru_btp_station_crashes_2023")
    crime_path = raw_path("bengaluru_bcp_crime_2023")
    quality = {"generatedAt": now(), "datasets": {}}
    if acc_path.exists():
        headers, rows = load_csv(acc_path)
        require_columns(by_id["bengaluru_btp_station_crashes_2023"], headers)
        quality["datasets"]["bengaluru_btp_station_crashes_2023"] = {
            "rawRecordCount": len(rows),
            "missingByColumn": {key: sum(not (row.get(key) or "").strip() for row in rows) for key in headers},
            "duplicateStationRows": len(rows) - len({(row.get("Station") or "").strip().casefold() for row in rows if (row.get("Station") or "").strip()}),
            "coordinateColumnsPresent": any(key.casefold() in {"lat", "latitude", "lon", "longitude"} for key in headers),
            "temporalColumnsPresent": any("date" in key.casefold() or "time" in key.casefold() for key in headers),
        }
        normalized = []
        for row in rows:
            station = (row.get("Station") or "").strip()
            if not station:
                continue
            normalized.append({
                "zone": (row.get("Zone") or "").strip() or None,
                "subdivision": (row.get("Sub-division") or "").strip() or None,
                "station": station,
                "fatalCases": number(row.get("2023 - Fatal Cases")),
                "peopleKilled": number(row.get("2023 - Killed People")),
                "nonFatalCases": number(row.get("2023 - Non-Fatal")),
                "peopleInjured": number(row.get("2023 - Injured People")),
                "totalCases": number(row.get("2023 - Total Cases")),
                "latitude": None,
                "longitude": None,
                "geographicPrecision": "police_station_aggregate",
                "sourceId": by_id["bengaluru_btp_station_crashes_2023"]["id"],
                "reportingPeriod": "2023",
            })
        if len({r["station"].casefold() for r in normalized}) != len(normalized):
            raise ValueError("Duplicate police station rows in crash CSV")
        values = sorted(r["totalCases"] or 0 for r in normalized)
        for row in normalized:
            row["concentration"] = quartile_level(row["totalCases"] or 0, values)
        result["accidents"].update(records=normalized, recordCount=len(normalized), status="historical")
        by_id["bengaluru_btp_station_crashes_2023"]["status"] = "processed"
        by_id["bengaluru_btp_station_crashes_2023"]["lastSuccessfulUpdateAt"] = now()
    if crime_path.exists():
        headers, rows = load_csv(crime_path)
        require_columns(by_id["bengaluru_bcp_crime_2023"], headers)
        quality["datasets"]["bengaluru_bcp_crime_2023"] = {
            "rawRecordCount": len(rows),
            "missingByColumn": {key: sum(not (row.get(key) or "").strip() for row in rows) for key in headers},
            "duplicateCategoryRows": len(rows) - len({(row.get("Type of Crime") or "").strip().casefold() for row in rows if (row.get("Type of Crime") or "").strip()}),
            "coordinateColumnsPresent": any(key.casefold() in {"lat", "latitude", "lon", "longitude"} for key in headers),
            "temporalColumnsPresent": any("date" in key.casefold() or "time" in key.casefold() for key in headers),
        }
        normalized = []
        for row in rows:
            category = (row.get("Type of Crime") or "").strip()
            if not category:
                continue
            normalized.append({
                "sourceCategory": category,
                "category": category.casefold().replace(" ", "_"),
                "reported2021": number(row.get("2021 Reported")),
                "detected2021": number(row.get("2021 Detected")),
                "reported2022": number(row.get("2022 Reported")),
                "detected2022": number(row.get("2022 Detected")),
                "reported2023": number(row.get("2023 Reported")),
                "detected2023": number(row.get("2023 Detected")),
                "latitude": None,
                "longitude": None,
                "geographicPrecision": "city_aggregate",
                "sourceId": by_id["bengaluru_bcp_crime_2023"]["id"],
            })
        if len({r["sourceCategory"].casefold() for r in normalized}) != len(normalized):
            raise ValueError("Duplicate crime category rows in crime CSV")
        result["crimes"].update(records=normalized, recordCount=len(normalized), status="historical")
        by_id["bengaluru_bcp_crime_2023"]["status"] = "processed"
        by_id["bengaluru_bcp_crime_2023"]["lastSuccessfulUpdateAt"] = now()
    loaded = [by_id[key].get("status") == "processed" for key in (
        "bengaluru_btp_station_crashes_2023", "bengaluru_bcp_crime_2023")]
    result["availability"] = "available" if all(loaded) else ("partial" if any(loaded) else "unavailable")
    if result["availability"] == "available":
        result["message"] = "Historical aggregate records are available. No incident coordinates are supplied."
    if result["availability"] == "partial":
        result["message"] = "Some historical aggregates are available; other source files are missing."

    PROCESSED.mkdir(parents=True, exist_ok=True)
    (PROCESSED / "safety_summary.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (PROCESSED / "data_quality.json").write_text(json.dumps(quality, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_csv(PROCESSED / "accident_station_summary.csv", result["accidents"]["records"], ["zone", "subdivision", "station", "fatalCases", "peopleKilled", "nonFatalCases", "peopleInjured", "totalCases", "concentration", "geographicPrecision", "sourceId", "reportingPeriod"])
    write_csv(PROCESSED / "crime_city_summary.csv", result["crimes"]["records"], ["sourceCategory", "category", "reported2021", "detected2021", "reported2022", "detected2022", "reported2023", "detected2023", "geographicPrecision", "sourceId"])
    if PROCESSED == ROOT / "analytics" / "safety":
        db_path = ROOT / "analytics" / "sosense_analytics.db"
        with sqlite3.connect(db_path) as connection:
            connection.executescript("""
                CREATE TABLE IF NOT EXISTS safety_accident_stations (
                    zone TEXT, subdivision TEXT, station TEXT NOT NULL,
                    fatalCases INTEGER, peopleKilled INTEGER, nonFatalCases INTEGER,
                    peopleInjured INTEGER, totalCases INTEGER, concentration TEXT,
                    geographicPrecision TEXT NOT NULL, sourceId TEXT NOT NULL, reportingPeriod TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS safety_crime_city (
                    sourceCategory TEXT NOT NULL, category TEXT NOT NULL,
                    reported2021 INTEGER, detected2021 INTEGER, reported2022 INTEGER, detected2022 INTEGER,
                    reported2023 INTEGER, detected2023 INTEGER,
                    geographicPrecision TEXT NOT NULL, sourceId TEXT NOT NULL
                );
                CREATE VIEW IF NOT EXISTS vw_safety_accident_by_station AS
                    SELECT station, zone, subdivision, reportingPeriod, totalCases, fatalCases, peopleKilled,
                           nonFatalCases, peopleInjured, concentration, geographicPrecision, sourceId
                    FROM safety_accident_stations;
                CREATE VIEW IF NOT EXISTS vw_safety_crime_by_category AS
                    SELECT sourceCategory, category, reported2021, detected2021, reported2022, detected2022,
                           reported2023, detected2023, geographicPrecision, sourceId FROM safety_crime_city;
            """)
            connection.execute("DELETE FROM safety_accident_stations")
            connection.execute("DELETE FROM safety_crime_city")
            connection.executemany(
                "INSERT INTO safety_accident_stations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [(r.get("zone"), r.get("subdivision"), r["station"], r.get("fatalCases"), r.get("peopleKilled"), r.get("nonFatalCases"), r.get("peopleInjured"), r.get("totalCases"), r.get("concentration"), r["geographicPrecision"], r["sourceId"], r["reportingPeriod"]) for r in result["accidents"]["records"]],
            )
            connection.executemany(
                "INSERT INTO safety_crime_city VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [(r["sourceCategory"], r["category"], r.get("reported2021"), r.get("detected2021"), r.get("reported2022"), r.get("detected2022"), r.get("reported2023"), r.get("detected2023"), r["geographicPrecision"], r["sourceId"]) for r in result["crimes"]["records"]],
            )
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if PROCESSED == ROOT / "analytics" / "safety":
        for destination in (ROOT / "backend" / "functions", ROOT / "mobile_app" / "assets"):
            destination.mkdir(parents=True, exist_ok=True)
            (destination / "safety_summary.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (ROOT / "backend" / "functions" / "safety_registry.json").write_text(json.dumps(registry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["download", "process", "refresh"])
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    registry = download_sources() if args.action in {"download", "refresh"} else read_registry()
    snapshot = process(registry)
    print(json.dumps({"availability": snapshot["availability"], "accidentStations": len(snapshot["accidents"]["records"]), "crimeCategories": len(snapshot["crimes"]["records"]), "generatedAt": snapshot["generatedAt"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
