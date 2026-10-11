@echo off
REM Builds the browser version of the app. The API server (backend\run_server.bat)
REM then serves it at http://localhost:8000/app/  - one address for app + API.
cd /d "%~dp0"
REM Use the Flutter + package cache inside this project.
call "%~dp0..\env.bat"

echo Building the app for the browser (takes a few minutes)...
call flutter pub get
call flutter build web --base-href /app/
if errorlevel 1 (
  echo.
  echo  Build failed. Send a screenshot of the first red error to Claude.
  pause
  exit /b 1
)

echo.
echo  Done! Make sure backend\run_server.bat is running (restart it if this is the first build), then open:
echo    On this PC:              http://localhost:8000/app/
echo    On a phone (same Wi-Fi): http://YOUR-PC-IP:8000/app/
ipconfig | findstr /i "IPv4"
echo    From anywhere:           run start_public_link.bat
start "" http://localhost:8000/app/
pause
