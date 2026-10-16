@echo off
setlocal

rem Bat lives in tools/: project folder = parent dir
for %%I in ("%~dp0..") do set "SRC=%%~fI"

rem Override install path via GEMINIBOTS_GMOD_ADDON env var (default: local install below)
set "DST=%GEMINIBOTS_GMOD_ADDON%"
if "%DST%"=="" set "DST=D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\addons\geminibots"

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
