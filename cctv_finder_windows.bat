@echo off
setlocal
title CCTV Auto-Finder (Advanced Mode)
color 0B

echo.
echo  ╔══════════════════════════════════════════════════════════╗
echo  ║   CCTV Auto-Finder — Windows (Advanced)                 ║
echo  ╚══════════════════════════════════════════════════════════╝
echo.

:: Check PowerShell
where powershell.exe >nul 2>nul
if errorlevel 1 (
  color 0C
  echo  [ERROR] Windows PowerShell was not found.
  pause
  exit /b 1
)

:: Check Nmap
where nmap.exe >nul 2>nul
if errorlevel 1 (
  color 0E
  echo  [ERROR] Nmap is required but was not found in PATH.
  echo.
  echo  Install Nmap for Windows from:
  echo    https://nmap.org/download.html
  echo.
  echo  After installing, reopen this file.
  pause
  exit /b 1
)

:: Check credentials file
if not exist "%~dp0camera_credentials.txt" (
  color 0E
  echo  [WARNING] camera_credentials.txt not found!
  echo.
  echo  Creating default credential list...
  (
    echo # Camera Credentials List
    echo # Add multiple username:password pairs, one per line.
    echo # The scanner will try each one and show which works.
    echo.
    echo admin:admin
    echo admin:12345
    echo admin:password
    echo admin:123456
    echo root:root
    echo root:admin
    echo admin:
    echo admin:888888
  ) > "%~dp0camera_credentials.txt"
  echo  Created with common defaults.
  echo  Edit with: notepad "%~dp0camera_credentials.txt"
  echo.
  color 0B
)

echo  [OK] Starting scanner...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0cctv_finder_windows.ps1"
endlocal
