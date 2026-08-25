@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Starting PVP Sound voice preview...
python serve.py
if errorlevel 1 (
  echo.
  echo Python failed. Try: py serve.py
  py serve.py
)
pause
