# Laptop web dashboard guide

Start with `npm start` and visit `http://localhost:3000`. The Overview contains only measured project/model/source status and labels local event counts as tests. Navigation opens the Safety Map, Analytics, Sensor Lab, Emergency Simulation, Journey Simulator, Incident History, local Profile/Contacts, Model & Data, and Diagnostics pages.

The Safety Map page frames Bengaluru in OpenStreetMap and reports the available safety aggregates. Current source schemas lack coordinate geometries, so it intentionally draws no crash or crime incident pins or intensity surface. Analytics uses the shipped model evaluation outputs and labels their controlled-data limits. Profile/contact labels remain in browser local storage; no phone/email fields or real contact delivery exist in this local workspace.

Every test event is marked SIMULATED. The local API does not connect the browser to Firebase. Simulated history is in memory and resets on server restart. See [Sensor Simulator](SENSOR_SIMULATOR_GUIDE.md) and [Emergency Simulation](EMERGENCY_SIMULATION_GUIDE.md).
