# Emergency simulation guide

The Emergency Simulation page is isolated from the mobile/Firebase emergency workflow. Start a manual test or run an automated scenario. An automated verification prompt is offered only when the actual exported classifier emits a supported non-normal label. The user can confirm, cancel, or let the configurable timer expire. Each result is marked SIMULATED in local incident history; a confirmation shows only a local mock notification preview.

The web server accepts simulation incident writes only when the request explicitly contains `isSimulation: true`. It has no SMS, email, FCM, Firestore incident creation, or contact dispatch client. Real Firebase incident history reports disconnected. Events are held in memory for the server session. This page tests UI and local logic; it does not prove real emergency delivery or mobile countdown behavior.
