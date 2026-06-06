@echo off
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0install.ps1" %*
pause
