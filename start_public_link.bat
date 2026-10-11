@echo off
REM Gives your local server a temporary PUBLIC https link (Cloudflare Tunnel, free, no account),
REM so phones anywhere can use the app. Start backend\run_server.bat first and keep it open.
REM The link changes every time you run this. Close this window to make the link stop working.
cd /d "%~dp0"
set CF=%~dp0tools\cloudflared.exe

if not exist "%CF%" (
  echo Downloading cloudflared ^(about 60 MB, one time only^) from Cloudflare's official GitHub...
  if not exist "%~dp0tools" mkdir "%~dp0tools"
  curl -L -o "%CF%" https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe
  if errorlevel 1 (
    echo Download failed. Check your internet connection.
    pause
    exit /b 1
  )
)

echo.
echo  ==================================================================
echo   Look below for a line like:  https://something.trycloudflare.com
echo.
echo   Browser (any phone, anywhere):  https://something.trycloudflare.com/app/
echo   Android APK:  tap the gear on the login screen and enter
echo                 https://something.trycloudflare.com
echo  ==================================================================
echo.
"%CF%" tunnel --url http://localhost:8000
pause
