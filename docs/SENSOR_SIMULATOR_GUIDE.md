# Sensor Simulation Lab

Open Sensor Lab and note the persistent banner **SIMULATED SENSOR DATA — NOT FROM A REAL DEVICE**. Start, pause/resume, stop or reset the stream; adjust playback speed; and choose walking, running, sudden movement, impact-like event, fall-like sequence, stationary, irregular or repeatable random movement. Custom mode exposes axis controls.

The stream uses bounded accelerometer/gyroscope values in device-like units, draws live SVG traces, and retains a rolling sample window. Model input matches the Flutter 20-feature schema: 128 samples at 50 Hz (2.56 seconds). The exported Random Forest and scaler are used for inference; no random predictions are generated. A result from this lab is a model label on simulated input, never a real accident determination. Model benchmark metrics do not establish field emergency accuracy.

Browser timers control visual playback; speed changes the display/sample cadence, not the underlying device physics. Laptop sensors are not read. The simulator does not exercise physical sensor noise, orientation calibration, OS permissions, dropped sensor events, or phone GPS. See `docs/reports/FEATURE_ENGINEERING.md` and `docs/reports/ML_MODEL_DOCUMENTATION.md` for the model pipeline.
