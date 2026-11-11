@echo off
setlocal
title CCTV Finder for Windows

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo Windows PowerShell was not found.
  pause
  exit /b 1
)

where nmap.exe >nul 2>nul
if errorlevel 1 (
  echo Nmap is required but was not found in PATH.
  echo Install Nmap for Windows from: https://nmap.org/download.html
  echo Then reopen this file.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0cctv_finder_windows.ps1"
endlocal
