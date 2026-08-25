@echo off
chcp 65001 >nul
cd /d "%~dp0tools\voice-preview"
echo Starting PVP Sound voice preview...
python serve.py
if errorlevel 1 py serve.py
pause
