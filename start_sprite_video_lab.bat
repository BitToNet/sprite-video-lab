@echo off
setlocal
cd /d "%~dp0"

set "SVL_LOG_DIR=%~dp0work\logs"
set "SVL_STDOUT_LOG=%SVL_LOG_DIR%\server.log"
set "SVL_STDERR_LOG=%SVL_LOG_DIR%\server-error.log"
set "SVL_LAUNCH_LOG=%SVL_LOG_DIR%\launcher.log"
if not exist "%SVL_LOG_DIR%" mkdir "%SVL_LOG_DIR%" >nul 2>nul
> "%SVL_LAUNCH_LOG%" echo [%DATE% %TIME%] Sprite Video Lab launcher started.
call :log "Project directory: %CD%"

if "%SPRITE_VIDEO_LAB_HOST%"=="" set "SPRITE_VIDEO_LAB_HOST=127.0.0.1"
if "%SPRITE_VIDEO_LAB_PORT%"=="" set "SPRITE_VIDEO_LAB_PORT=8894"
call :log "Host: %SPRITE_VIDEO_LAB_HOST%"
call :log "Port: %SPRITE_VIDEO_LAB_PORT%"

set "SVL_HAS_E_DRIVE="
call :log "Checking E: drive defaults..."
if exist "E:\" set "SVL_HAS_E_DRIVE=1"
if "%SVL_HAS_E_DRIVE%"=="1" (
  call :log "E: drive found."
) else (
  call :log "E: drive not found; using project-local defaults unless environment variables override them."
)

if "%SPRITE_VIDEO_LAB_WORK_DIR%"=="" if "%SVL_HAS_E_DRIVE%"=="1" set "SPRITE_VIDEO_LAB_WORK_DIR=E:\sprite-video-lab-work"
if "%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"=="" if "%SVL_HAS_E_DRIVE%"=="1" set "SPRITE_VIDEO_LAB_AI_MODEL_CACHE=E:\sprite-video-lab-models\huggingface"
if "%SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT%"=="" if "%SVL_HAS_E_DRIVE%"=="1" set "SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT=E:\sprite-video-lab-models\CorridorKey"
if "%HF_HOME%"=="" set "HF_HOME=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"
if "%HUGGINGFACE_HUB_CACHE%"=="" set "HUGGINGFACE_HUB_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\hub"
if "%TRANSFORMERS_CACHE%"=="" set "TRANSFORMERS_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\transformers"
if "%HF_MODULES_CACHE%"=="" set "HF_MODULES_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\modules"
if "%HF_XET_CACHE%"=="" set "HF_XET_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\xet"
if "%HF_HUB_DISABLE_SYMLINKS_WARNING%"=="" set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"
call :log "Work dir: %SPRITE_VIDEO_LAB_WORK_DIR%"
call :log "AI model cache: %SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"

set "PYTHON_EXE="
call :log "Resolving Python executable..."
if not "%SPRITE_VIDEO_LAB_PYTHON%"=="" if exist "%SPRITE_VIDEO_LAB_PYTHON%" (
  set "PYTHON_EXE=%SPRITE_VIDEO_LAB_PYTHON%"
  call :log "Using SPRITE_VIDEO_LAB_PYTHON."
  goto :python_ready
)
call :log "Checking project virtualenv..."
if exist "%~dp0.venv\Scripts\python.exe" (
  set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"
  call :log "Using project virtualenv Python."
  goto :python_ready
)
call :log "Checking E: AI runtime virtualenv..."
if exist "E:\sprite-video-lab-models\venv\Scripts\python.exe" (
  set "PYTHON_EXE=E:\sprite-video-lab-models\venv\Scripts\python.exe"
  call :log "Using E: AI runtime Python."
  goto :python_ready
)
call :log "Searching PATH with where python..."
for /f "delims=" %%i in ('where python 2^>nul') do (
  set "PYTHON_EXE=%%i"
  call :log "Using PATH python: %%i"
  goto :python_ready
)
call :log "Searching PATH with where py..."
for /f "delims=" %%i in ('where py 2^>nul') do (
  set "PYTHON_EXE=%%i"
  call :log "Using PATH py launcher: %%i"
  goto :python_ready
)

echo Python not found.
call :log "Python not found."
exit /b 1

:python_ready
set "SPRITE_VIDEO_LAB_PYTHON=%PYTHON_EXE%"
call :log "Python executable: %PYTHON_EXE%"
call :log "Stopping stale Sprite Video Lab processes on this project/port..."
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$launchLog = [System.IO.Path]::GetFullPath('%SVL_LAUNCH_LOG%');" ^
  "function Write-LaunchLog([string]$message) { $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') + '] cleanup: ' + $message; Write-Host $line; Add-Content -LiteralPath $launchLog -Value $line -Encoding UTF8 };" ^
  "Write-LaunchLog 'PowerShell cleanup started.';" ^
  "$serverPath = [System.IO.Path]::GetFullPath('%~dp0server.py');" ^
  "$escaped = [Regex]::Escape($serverPath);" ^
  "$self = $PID;" ^
  "$port = [int]'%SPRITE_VIDEO_LAB_PORT%';" ^
  "Write-LaunchLog 'Scanning Win32_Process for this server.py path...';" ^
  "Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $self -and $_.CommandLine -and $_.CommandLine -match $escaped } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} };" ^
  "Write-LaunchLog 'Checking TCP listeners on the configured port...';" ^
  "Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $ownerPid = $_.OwningProcess; $proc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $ownerPid }; if ($proc.CommandLine -and $proc.CommandLine -match 'server\.py' -and ($proc.CommandLine -match 'sprite-video-lab' -or $proc.CommandLine -match 'SVL')) { try { Stop-Process -Id $ownerPid -Force -ErrorAction Stop } catch {} } }"
if errorlevel 1 (
  call :log "Stale process cleanup returned an errorlevel; continuing to startup."
) else (
  call :log "Stale process cleanup completed."
)

call :log "Starting PowerShell server launcher..."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start_sprite_video_lab_server.ps1" ^
  -PythonExe "%PYTHON_EXE%" ^
  -ServerPath "%~dp0server.py" ^
  -HostName "%SPRITE_VIDEO_LAB_HOST%" ^
  -Port "%SPRITE_VIDEO_LAB_PORT%" ^
  -StdoutLog "%SVL_STDOUT_LOG%" ^
  -StderrLog "%SVL_STDERR_LOG%" ^
  -LaunchLog "%SVL_LAUNCH_LOG%"
if errorlevel 1 (
  call :log "Start failed."
  echo.
  echo Start failed. See:
  echo   %SVL_LAUNCH_LOG%
  echo   %SVL_STDOUT_LOG%
  echo   %SVL_STDERR_LOG%
  pause
  exit /b 1
)
call :log "Start completed successfully."
exit /b 0

:log
echo [%DATE% %TIME%] %~1
>> "%SVL_LAUNCH_LOG%" echo [%DATE% %TIME%] %~1
exit /b 0
