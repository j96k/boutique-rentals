@echo off
REM Copies only the clean source code into the "live" folder (for your private GitHub).
REM Never copies: passwords (.env), databases, photos, keys, Flutter/Android SDKs, build outputs.
REM Safe to run again: it updates live\ and keeps live\.git (your git history).
setlocal
set "SRC=%~dp0.."
set "DST=%~dp0..\live"
if not exist "%DST%" mkdir "%DST%"

robocopy "%SRC%\backend" "%DST%\backend" /MIR /NFL /NDL /NJH /NJS /NP ^
  /XD .venv __pycache__ database uploads ^
  /XF .env *.db *.pem reset_mysql_password.bat

robocopy "%SRC%\mobile" "%DST%\mobile" /MIR /NFL /NDL /NJH /NJS /NP ^
  /XD build .dart_tool .idea .gradle Pods .symlinks ephemeral ^
  /XF local.properties *.iml .flutter-plugins .flutter-plugins-dependencies *.jks *.keystore key.properties

robocopy "%SRC%\deploy" "%DST%\deploy" /MIR /NFL /NDL /NJH /NJS /NP /XF *.tar.gz *.pem

for %%F in (render.yaml README.md .gitattributes env.bat start_public_link.bat) do (
  if exist "%SRC%\%%F" copy /y "%SRC%\%%F" "%DST%\%%F" >nul
)

> "%DST%\.gitignore" (
  echo # Never upload these
  echo .env
  echo *.db
  echo *.pem
  echo *.jks
  echo *.keystore
  echo __pycache__/
  echo .venv/
  echo backend/database/
  echo backend/uploads/
  echo deploy/*.tar.gz
  echo tools/
  echo flutter/
  echo android-sdk/
  echo .pub-cache/
)

echo.
echo Clean code is in: %DST%
echo Next: see "Push to GitHub" in deploy\ONLINE_GUIDE.md
exit /b 0
