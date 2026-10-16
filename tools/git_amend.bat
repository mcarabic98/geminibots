@echo off
rem Rewrite last commit message. Usage: git_amend.bat "new message"
set PATH=C:\Program Files\Git\bin;%PATH%
if "%~1"=="" (
    echo Usage: git_amend.bat "new message"
    exit /b 1
)
git commit --amend -m "%~1" -m "Co-authored-by: OpenCode <opencode@local>"
git push --force-with-lease origin main
