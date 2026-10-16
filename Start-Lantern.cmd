@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
  echo Python 3.10 or newer is required. Install Python from python.org with the Python launcher enabled.
  pause
  exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
  py -3 -m venv .venv
  if errorlevel 1 goto fail
)
if not exist ".venv\lantern-ready" (
  .venv\Scripts\python.exe -m pip install -e .
  if errorlevel 1 goto fail
  echo ready> .venv\lantern-ready
)
.venv\Scripts\python.exe -m lantern app
if errorlevel 1 goto fail
exit /b 0
:fail
echo Lantern could not start. Read the error above. First setup requires internet to install dependencies.
pause
exit /b 1
