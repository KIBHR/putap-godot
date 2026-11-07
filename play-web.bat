@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 tools\serve_web.py
) else (
    python tools\serve_web.py
)
if errorlevel 1 (
    echo.
    echo Install Python 3 and try again if the web server did not start.
    pause
)
