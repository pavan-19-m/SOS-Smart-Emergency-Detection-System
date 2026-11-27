# Limitations and Future Scope

## Current Technical & Scientific Limitations
1. **No Real Road-Crash Telemetry Dataset:** Public HAR datasets (UCI HAR) contain everyday human activities, not real vehicle crashes. Controlled physics-informed simulations validate the detection pipeline, **not** clinical or automotive crash sensitivity in the wild.
2. **Smartphone Placement Sensitivity:** Pocket, bag, dashboard mount, and handheld phone placements produce different impact attenuation and rotational signatures.
3. **Android OS Background Restrictions:** Doze mode and OEM battery killers (MIUI, ColorOS, OneUI) can throttle or halt background sensor listeners unless users exempt the app and run an explicit Android Foreground Service.
4. **Offline & GPS Gaps:** Underground garages or cellular dead zones block real-time FCM delivery; SOSense queues incidents locally and refuses to claim alert delivery succeeded while offline.
5. **Prolonged Inactivity Ambiguity:** As shown by Isolation Forest evaluation (90 missed `PROLONGED_INACTIVITY` windows), single-window stillness cannot distinguish an unconscious user from someone peacefully sitting or sleeping—requiring Safe Check-In session context.
6. **Host Environment Constraints:** Flutter SDK, Android SDK, Firebase CLI, and GitHub CLI were unavailable on the build workstation, so Flutter tests and Android APK compilation remain to be run on a Flutter-equipped machine.

## Future Scope
- Validate against IRB-approved real fall corpora (e.g., MobiAct v2 / SisFall resampled to 50 Hz) and automotive OBD-II / telematics crash logs.
- Add Android native Foreground Service Kotlin plugin with persistent notification for screen-off monitoring.
- Integrate smartwatch wearable IMU fusion (Wear OS / BLE heart rate + wrist accelerometry).
- Add SMS fallback gateway (Twilio / local SIM SMS intent) when mobile data is unavailable but cellular voice/SMS exists.
- Train 1D-CNN / TCN quantized TFLite sequence models directly on raw 128x6 waveforms once large real impact datasets are acquired.
