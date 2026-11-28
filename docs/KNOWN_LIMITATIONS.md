# Known limitations

- Laptop dashboard is local, single-user and unauthenticated; server binds to loopback by default. It is not a deployed production service.
- Browser real Firebase history, auth, GPS, SMS/email/FCM and actual contact management are not connected. Local contact labels use browser storage only.
- Simulation incidents and journeys are memory-only and clear when the server stops. They cannot enter Firebase through these routes.
- The shipped classifier is evaluated on controlled anomaly windows and UCI HAR activity data, not a representative labeled real accident/fall corpus. A model output is not a diagnosis or verified emergency.
- OpenCity catalogue sources currently documented are aggregate counts: police-station-level crashes and citywide crime categories. They cannot support exact pins, defensible nearby distances, density maps, route scores, or a spatial combined hotspot. Raw source downloads remain unverified because the download host returned a browser challenge.
- The web map shows general Bengaluru geography only. Its basemap does not indicate incident concentration or safety.
- Flutter/Dart, Firebase deployment, physical sensor hardware and Power BI Desktop were not available for verification in the recorded environment.
