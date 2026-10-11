@echo off
REM Builds the browser app and copies it into backend\webapp\ so the online server (Render)
REM can serve it at /app/. Run this before every "git push" when the app screens changed.
cd /d "%~dp0..\mobile"
call "%~dp0..\env.bat"

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed - using the last build in mobile\build\web instead.
  if not exist "%~dp0..\mobile\build\web\index.html" (
    echo No earlier build found either. Install Flutter first.
    pause
    exit /b 1
  )
  goto copy
)
echo Building the browser app...
call flutter pub get
call flutter build web --base-href /app/
if errorlevel 1 (
  echo Build failed. Send a screenshot of the first red error to Claude.
  pause
  exit /b 1
)

:copy

echo Copying to backend\webapp ...
if exist "%~dp0..\backend\webapp" rmdir /s /q "%~dp0..\backend\webapp"
xcopy /e /i /q "%~dp0..\mobile\build\web" "%~dp0..\backend\webapp" >nul

echo.
echo Done. Now commit and push to GitHub (see deploy\ONLINE_GUIDE.md) - Render updates automatically.
pause
