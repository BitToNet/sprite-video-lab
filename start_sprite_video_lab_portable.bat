@echo off
setlocal
cd /d "%~dp0"

set "APP_ROOT=%~dp0"
set "RUNTIME_ROOT=%APP_ROOT%runtime"
set "PYTHON_ROOT=%RUNTIME_ROOT%\python"
set "PYTHON_EXE=%PYTHON_ROOT%\python.exe"
set "FFMPEG_ROOT=%RUNTIME_ROOT%\ffmpeg"
set "PORTABLE_MODEL_ROOT=%RUNTIME_ROOT%\models\portable-models"

if "%SPRITE_VIDEO_LAB_HOST%"=="" set "SPRITE_VIDEO_LAB_HOST=127.0.0.1"
if "%SPRITE_VIDEO_LAB_PORT%"=="" set "SPRITE_VIDEO_LAB_PORT=8894"
if "%SPRITE_VIDEO_LAB_FFMPEG_DIR%"=="" set "SPRITE_VIDEO_LAB_FFMPEG_DIR=%FFMPEG_ROOT%"
if "%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"=="" set "SPRITE_VIDEO_LAB_AI_MODEL_CACHE=%PORTABLE_MODEL_ROOT%\huggingface"
if "%SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT%"=="" set "SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT=%PORTABLE_MODEL_ROOT%\CorridorKey"
if "%HF_HOME%"=="" set "HF_HOME=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"
if "%HUGGINGFACE_HUB_CACHE%"=="" set "HUGGINGFACE_HUB_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\hub"
if "%TRANSFORMERS_CACHE%"=="" set "TRANSFORMERS_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\transformers"
if "%HF_MODULES_CACHE%"=="" set "HF_MODULES_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\modules"
if "%HF_XET_CACHE%"=="" set "HF_XET_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\xet"
if "%HF_HUB_DISABLE_SYMLINKS_WARNING%"=="" set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"
set "PATH=%PYTHON_ROOT%;%PYTHON_ROOT%\Scripts;%FFMPEG_ROOT%;%PATH%"

if not exist "%PYTHON_EXE%" (
  echo Missing bundled Python runtime:
  echo   %PYTHON_EXE%
  pause
  exit /b 1
)

if not exist "%SPRITE_VIDEO_LAB_FFMPEG_DIR%\ffmpeg.exe" (
  echo Missing bundled ffmpeg:
  echo   %SPRITE_VIDEO_LAB_FFMPEG_DIR%\ffmpeg.exe
  pause
  exit /b 1
)

set "SVL_LOG_DIR=%APP_ROOT%work\logs"
set "SVL_STDOUT_LOG=%SVL_LOG_DIR%\server.log"
set "SVL_STDERR_LOG=%SVL_LOG_DIR%\server-error.log"
if not exist "%SVL_LOG_DIR%" mkdir "%SVL_LOG_DIR%" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$serverPath = [System.IO.Path]::GetFullPath('%~dp0server.py');" ^
  "$escaped = [Regex]::Escape($serverPath);" ^
  "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match $escaped } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start_sprite_video_lab_server.ps1" ^
  -PythonExe "%PYTHON_EXE%" ^
  -ServerPath "%~dp0server.py" ^
  -HostName "%SPRITE_VIDEO_LAB_HOST%" ^
  -Port "%SPRITE_VIDEO_LAB_PORT%" ^
  -StdoutLog "%SVL_STDOUT_LOG%" ^
  -StderrLog "%SVL_STDERR_LOG%"
if errorlevel 1 (
  echo.
  echo Start failed. See:
  echo   %SVL_STDOUT_LOG%
  echo   %SVL_STDERR_LOG%
  pause
  exit /b 1
)
