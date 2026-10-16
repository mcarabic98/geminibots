@echo off
setlocal EnableDelayedExpansion

rem Bat lives in tools/: project folder = parent dir
for %%I in ("%~dp0..") do set "SRC=%%~fI"

rem 1. Explicit override wins
set "DST=%GEMINIBOTS_GMOD_ADDON%"
if not "%DST%"=="" goto found

rem 2. Steam install path from registry
set "STEAMDIR="
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do set "STEAMDIR=%%B"
if not defined STEAMDIR for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Valve\Steam" /v InstallPath 2^>nul') do set "STEAMDIR=%%B"
if not defined STEAMDIR for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\Wow6432Node\Valve\Steam" /v InstallPath 2^>nul') do set "STEAMDIR=%%B"

set "FOUND="
rem 2a. Main library
if defined STEAMDIR call :checklib "%STEAMDIR%"
rem 2b. Secondary libraries from libraryfolders.vdf ("path" lines, both formats).
rem Take rest of line after the key, strip quotes (paths may contain spaces).
if defined STEAMDIR if exist "%STEAMDIR%\steamapps\libraryfolders.vdf" (
    for /f "tokens=1*" %%A in ('findstr /r "[A-Za-z]:\\\\" "%STEAMDIR%\steamapps\libraryfolders.vdf" 2^>nul') do (
        set "LIB=%%B"
        set "LIB=!LIB:"=!"
        set "LIB=!LIB:\\=\!"
        call :checklib "!LIB!"
    )
)
if defined FOUND goto found

rem 3. Last resort: sweep drives for common library roots
for %%D in (C D E F G H) do (
    call :checklib "%%D:\SteamLibrary"
    if defined FOUND goto found
    call :checklib "%%D:\Steam"
    if defined FOUND goto found
    call :checklib "%%D:\Program Files\Steam"
    if defined FOUND goto found
    call :checklib "%%D:\Program Files (x86)\Steam"
    if defined FOUND goto found
)

echo [GeminiBots] ERROR: GarrysMod install not found.
echo [GeminiBots] Set GEMINIBOTS_GMOD_ADDON env var to your addons folder, e.g.
echo [GeminiBots]   setx GEMINIBOTS_GMOD_ADDON "D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\addons\geminibots"
pause
exit /b 1

rem %1 = steam library root (folder containing steamapps)
:checklib
if "%~1"=="" exit /b 0
if defined FOUND exit /b 0
if exist "%~1\steamapps\common\GarrysMod\garrysmod\addons" (
    set "DST=%~1\steamapps\common\GarrysMod\garrysmod\addons\geminibots"
    set "FOUND=1"
)
exit /b 0

:found
echo [GeminiBots] SRC: "%SRC%"
echo [GeminiBots] DST: "%DST%"

if not exist "%DST%" mkdir "%DST%"

robocopy "%SRC%" "%DST%" /MIR /XD .git .vscode .github __pycache__ tools /XF Thumbs.db desktop.ini *.tmp sync_to_gmod.bat

rem robocopy codes 0-7 = success, 8+ = error
if %ERRORLEVEL% LSS 8 (
    echo [GeminiBots] Done, addon synced.
) else (
    echo [GeminiBots] ERROR robocopy code: %ERRORLEVEL%
)

pause
