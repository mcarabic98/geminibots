@echo off
rem Commit + push to GitHub. Usage: git_push.bat "commit message"
set PATH=C:\Program Files\Git\bin;%PATH%
if "%~1"=="" (
    echo Usage: git_push.bat "commit message"
    exit /b 1
)
git add -A
git commit -m "%~1" -m "Co-authored-by: OpenCode <opencode@local>"
git push origin main
