@echo off
setlocal

rem Project folder = folder with this bat
set "SRC=%~dp0"
set "SRC=%SRC:~0,-1%"

set "DST=D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\addons\geminibots"

echo [GeminiBots] SRC: "%SRC%"
echo [GeminiBots] DST: "%DST%"

if not exist "%DST%" mkdir "%DST%"

robocopy "%SRC%" "%DST%" /MIR /XD .git .vscode .github __pycache__ /XF Thumbs.db desktop.ini *.tmp deploy_to_gmod.bat sync_to_gmod.bat

rem robocopy codes 0-7 = success, 8+ = error
if %ERRORLEVEL% LSS 8 (
    echo [GeminiBots] Done, addon synced.
) else (
    echo [GeminiBots] ERROR robocopy code: %ERRORLEVEL%
)

pause
