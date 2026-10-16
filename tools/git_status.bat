@echo off
rem Short status + last commits.
set PATH=C:\Program Files\Git\bin;%PATH%
git status --short
echo ---
git log --oneline -5
