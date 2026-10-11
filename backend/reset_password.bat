@echo off
REM Set a new password for a boutique login (passwords can't be decrypted, only replaced).
cd /d "%~dp0"
.venv\Scripts\python.exe reset_password.py
echo.
pause
