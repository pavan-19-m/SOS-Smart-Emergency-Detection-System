@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Install Node.js 18 or newer, then reopen this terminal.
  pause
  exit /b 1
)
where npm >nul 2>nul
if errorlevel 1 (
  echo npm was not found. Repair the Node.js installation and reopen this terminal.
  pause
  exit /b 1
)
for /f %%V in ('node -p "Number(process.versions.node.split('.')[0])"') do set NODE_MAJOR=%%V
if %NODE_MAJOR% LSS 18 (
  echo Node.js 18 or newer is required. Current major version: %NODE_MAJOR%
  pause
  exit /b 1
)
echo Starting SOSense local laptop workspace...
echo Open http://localhost:3000 in Chrome or Edge.
echo Simulation mode is enforced. No emergency notifications will be sent.
npm run start
if errorlevel 1 (
  echo SOS did not start. If port 3000 is occupied, use PowerShell: $env:SOS_PORT=3001; npm run start
  pause
  exit /b 1
)
endlocal
