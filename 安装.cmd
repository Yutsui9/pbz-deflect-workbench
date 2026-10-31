@echo off
setlocal
chcp 65001 >nul
title PBZ Deflect Workbench Setup
set "RESULT=1"
where powershell.exe >nul 2>&1
if errorlevel 1 goto no_powershell
if not exist "%~dp0deploy\Launch.ps1" goto incomplete
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0deploy\Launch.ps1" -Action Install
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (echo SETUP COMPLETED.) else (echo SETUP FAILED. Read the error and log path above.)
goto finish
:no_powershell
echo Windows PowerShell was not found. Run this package on Windows with PowerShell 5.1.
goto finish
:incomplete
echo PACKAGE INCOMPLETE: Extract the entire windows-x64.zip before running this file.
echo Download: https://github.com/Yutsui9/pbz-deflect-workbench/releases/latest
:finish
echo.
echo Press any key to close this window. Closing it does not undo the operation.
pause >nul
exit /b %RESULT%
