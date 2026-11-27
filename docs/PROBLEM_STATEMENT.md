# Problem Statement

Traditional emergency safety applications rely almost exclusively on a user manually unlocking their smartphone and pressing an SOS button. During severe road accidents, sudden falls, unconsciousness, shock, or physical immobilization, manual activation fails precisely when help is needed most.

Conversely, naive threshold-only sensor triggers suffer from high false-alarm rates during everyday vigorous movements (running, climbing stairs, dropping a phone on a sofa), causing alert fatigue among family contacts.

**Core Challenge:** Design and validate a modular, privacy-preserving safety platform that:
1. Processes multi-axis smartphone motion telemetry (accelerometer + gyroscope) through signal filtering, time-domain feature extraction, and machine learning classification.
2. Enforces a human-in-the-loop verification countdown before dispatching external alerts.
3. Supports manual SOS, timed safe check-ins, offline queueing, primary-to-secondary escalation, and interactive data analytics—while remaining strictly transparent about sensor and dataset limitations.
