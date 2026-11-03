@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy\Install.ps1"
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (echo COMPLETED.) else (echo FAILED. Please read the error above.)
pause
exit /b %RESULT%
