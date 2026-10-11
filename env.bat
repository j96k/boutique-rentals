@echo off
REM Uses the Flutter, Android SDK and package cache stored inside this project folder.
REM Other scripts call this automatically. For your own flutter commands, open cmd in this
REM folder and run:  env.bat   then e.g.  cd mobile  and  flutter build apk
set "PROJECT_ROOT=%~dp0"
set "PATH=%~dp0flutter\bin;%~dp0android-sdk\platform-tools;%PATH%"
set "ANDROID_HOME=%~dp0android-sdk"
set "ANDROID_SDK_ROOT=%~dp0android-sdk"
set "PUB_CACHE=%~dp0.pub-cache"
