# User Guide — SOSense Mobile Application

## 1. Getting Started
1. Launch SOSense -> **Welcome** -> **Register** (or **Sign In**).
2. Open **Permission Center** to grant **Location (While Using / Always if background needed)** and **Notifications** permissions, and review Android battery optimization guidance.
3. Open **Family Contacts** -> **Add Contact** to add at least one **Primary** contact and optional **Secondary** escalation contact.

## 2. Manual SOS
- Navigate to the **SOS** tab.
- **Tap** the red SOS circle for a cancellable 5-second countdown, or **Press and Hold** (or disable the countdown switch) for immediate activation.
- Check the status card to verify whether your alert was **dispatched** or **queued offline**.

## 3. Smart Sensor Monitoring & Verification
- Open **Monitor** -> **Start Monitoring** to stream 50 Hz accelerometer & gyroscope windows through the on-device Random Forest classifier.
- Adjust thresholds in **Detection Rules** (`Low`, `Medium`, `High`, countdown duration, escalation delay).
- If a fall-like or crash-like event is detected, tap **"I'm Safe"** before the countdown ends to cancel false alarms, or **"Confirm Emergency"** to dispatch immediately.

## 4. Safe Check-In
- Open **Safe Check-In**, enter your trip label, expected arrival time, and check-in interval.
- Tap **"Confirm I'm Safe"** at each interval or **"Extend +15m"** if delayed. Missed check-ins enter a grace period before alerting contacts.

## 5. Safe Demo Center
- Use **Demo Center** to test all 10 scenarios (`Manual SOS`, `Possible Accident`, `Possible Fall`, `Unusual Movement`, `Missed Check-In`, `Family Ack`, `Escalation`, `Safe Cancel`, `GPS Unavailable`, `Offline Mode`).
- Demo events are tagged `[SIMULATION]` and **never** notify real family contacts.
