@echo off
REM Packs the app for the AWS server (see deploy\AWS_GUIDE.md).
REM   rental_app.tar.gz  = backend code + browser app (no passwords, no database)
REM   rental_data.tar.gz = your local database + cloth photos (only used on the server's first setup)
cd /d "%~dp0.."

if not exist mobile\build\web\index.html (
  echo The browser app is not built yet. Run mobile\run_web.bat first, then run this again.
  pause
  exit /b 1
)

echo Packing code...
tar -czf deploy\rental_app.tar.gz --exclude=.venv --exclude=__pycache__ --exclude=.env --exclude="backend/database/*" --exclude="backend/uploads/*" --exclude="*.bat" backend mobile/build/web
if errorlevel 1 goto fail

echo Packing your data (database + photos)...
tar -czf deploy\rental_data.tar.gz backend/database backend/uploads
if errorlevel 1 goto fail

echo.
echo Created:
dir /b deploy\*.tar.gz
echo.
echo Next: upload them with scp (step 5 in deploy\AWS_GUIDE.md).
pause
exit /b 0

:fail
echo Packing failed.
pause
exit /b 1
