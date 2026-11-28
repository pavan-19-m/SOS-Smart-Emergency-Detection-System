# Local setup on Windows

## Laptop dashboard

1. Install Node.js 18 or newer and reopen the VS Code terminal.
2. Open the repository folder in VS Code.
3. Run `start_sos.bat`, or in PowerShell run `npm start` from the repository root.
4. Open `http://localhost:3000` in Chrome or Edge. The server binds to loopback and requires no `npm install`.

If port 3000 is occupied, run `$env:SOS_PORT=3001; npm start` and open `http://localhost:3001`. Press Ctrl+C in the server terminal to stop it. Browser simulations are local, memory-only, and never contact real emergency contacts.

## Existing project commands

| Task | Command | Requirements |
|---|---|---|
| Laptop web server | `npm start` | Node 18+ |
| Web syntax checks | `npm run check` | Node 18+ |
| Web tests | `npm test` | Node 18+ |
| Firebase Functions tests | `npm run test:backend` | Node/npm; function package dependencies installed |
| Python tests | `npm run test:python` | Existing `.venv` and Python dependencies |
| Mobile tests/build | `cd mobile_app; flutter test` / `flutter build apk` | Flutter SDK, Android SDK, project Firebase setup as needed |
| Data refresh | See `DATA_REFRESH_GUIDE.md` | Source CSV access; download currently blocked in recorded environment |

No Firebase project id or browser Firebase configuration is included. Live auth, cloud history and notification delivery are not part of the local dashboard. Do not add private credentials to source control.

## Troubleshooting

- `node` not found: install Node.js LTS and reopen the terminal.
- Port error: select a different `SOS_PORT` as above.
- Browser cannot connect: keep the `npm start` terminal open and use the printed loopback URL.
- Safety datasets show unavailable: source CSV downloads previously returned a Cloudflare challenge; follow the documented manual refresh steps.
- Flutter command not found: install Flutter and Android tooling; this checkout's audit environment did not have Flutter/Dart available.
