@echo off
REM Starts the API on port 8000, reachable from phones on the same Wi-Fi.
cd /d "%~dp0"
if not exist .venv (
  echo Creating Python virtual environment...
  python -m venv .venv
  .venv\Scripts\pip install -r requirements.txt
)
if not exist .env (
  copy .env.example .env
  echo  Created backend\.env - uses SQLite, no database server needed.
)
echo.
echo  Your PC's IP addresses (use one of these in the app's Server setting):
ipconfig | findstr /i "IPv4"
echo.
echo  Keep THIS window open while using the app. Test page: http://localhost:8000/docs
echo.
.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
echo.
echo  The server has stopped. If you see a red error above, send a screenshot to Claude.
pause
