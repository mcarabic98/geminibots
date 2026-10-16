@echo off
rem Pull latest from GitHub (rebase).
set PATH=C:\Program Files\Git\bin;%PATH%
git pull --rebase origin main
