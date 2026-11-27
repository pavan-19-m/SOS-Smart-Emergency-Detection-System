// Power Query (M) Import Template for SOSense Power BI Dashboard
// Replace <REPO_ROOT> with your local path to SOS-Smart-Emergency-Detection-System

let
    ExportsFolder = "<REPO_ROOT>\analytics\exports\",
    LoadCsv = (fileName as text) =>
        let
            Source = Csv.Document(File.Contents(ExportsFolder & fileName), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
            Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars=true])
        in
            Promoted,

    FactSensorEvents = LoadCsv("fact_sensor_events.csv"),
    FactIncidents = LoadCsv("fact_incidents.csv"),
    FactNotifications = LoadCsv("fact_notifications.csv"),
    DimDate = LoadCsv("dim_date.csv"),
    ModelComparison = LoadCsv("ml_model_comparison.csv"),
    ConfusionMatrix = LoadCsv("ml_confusion_matrix.csv"),
    TimeSeriesSample = LoadCsv("sensor_timeseries_sample.csv")
in
    [
        fact_sensor_events = FactSensorEvents,
        fact_incidents = FactIncidents,
        fact_notifications = FactNotifications,
        dim_date = DimDate,
        ml_model_comparison = ModelComparison,
        ml_confusion_matrix = ConfusionMatrix,
        sensor_timeseries_sample = TimeSeriesSample
    ]
