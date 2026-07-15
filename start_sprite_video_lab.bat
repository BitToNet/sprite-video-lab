@echo off
setlocal
cd /d "%~dp0"

if "%SPRITE_VIDEO_LAB_HOST%"=="" set "SPRITE_VIDEO_LAB_HOST=127.0.0.1"
if "%SPRITE_VIDEO_LAB_PORT%"=="" set "SPRITE_VIDEO_LAB_PORT=8894"
if "%SPRITE_VIDEO_LAB_WORK_DIR%"=="" if exist "E:\" set "SPRITE_VIDEO_LAB_WORK_DIR=E:\sprite-video-lab-work"
if "%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"=="" if exist "E:\" set "SPRITE_VIDEO_LAB_AI_MODEL_CACHE=E:\sprite-video-lab-models\huggingface"
if "%SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT%"=="" if exist "E:\" set "SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT=E:\sprite-video-lab-models\CorridorKey"
if "%HF_HOME%"=="" set "HF_HOME=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%"
if "%HUGGINGFACE_HUB_CACHE%"=="" set "HUGGINGFACE_HUB_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\hub"
if "%TRANSFORMERS_CACHE%"=="" set "TRANSFORMERS_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\transformers"
if "%HF_MODULES_CACHE%"=="" set "HF_MODULES_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\modules"
if "%HF_XET_CACHE%"=="" set "HF_XET_CACHE=%SPRITE_VIDEO_LAB_AI_MODEL_CACHE%\xet"
if "%HF_HUB_DISABLE_SYMLINKS_WARNING%"=="" set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

set "PYTHON_EXE="
if not "%SPRITE_VIDEO_LAB_PYTHON%"=="" if exist "%SPRITE_VIDEO_LAB_PYTHON%" (
  set "PYTHON_EXE=%SPRITE_VIDEO_LAB_PYTHON%"
  goto :python_ready
)
if exist "%~dp0.venv\Scripts\python.exe" (
  set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"
  goto :python_ready
)
if exist "E:\sprite-video-lab-models\venv\Scripts\python.exe" (
  set "PYTHON_EXE=E:\sprite-video-lab-models\venv\Scripts\python.exe"
  goto :python_ready
)
for /f "delims=" %%i in ('where python 2^>nul') do (
  set "PYTHON_EXE=%%i"
  goto :python_ready
)
for /f "delims=" %%i in ('where py 2^>nul') do (
  set "PYTHON_EXE=%%i"
  goto :python_ready
)

echo Python not found.
exit /b 1

:python_ready
set "SPRITE_VIDEO_LAB_PYTHON=%PYTHON_EXE%"
set "SVL_LOG_DIR=%~dp0work\logs"
set "SVL_STDOUT_LOG=%SVL_LOG_DIR%\server.log"
set "SVL_STDERR_LOG=%SVL_LOG_DIR%\server-error.log"
if not exist "%SVL_LOG_DIR%" mkdir "%SVL_LOG_DIR%" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$serverPath = [System.IO.Path]::GetFullPath('%~dp0server.py');" ^
  "$escaped = [Regex]::Escape($serverPath);" ^
  "$self = $PID;" ^
  "$port = [int]'%SPRITE_VIDEO_LAB_PORT%';" ^
  "Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $self -and $_.CommandLine -and $_.CommandLine -match $escaped } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} };" ^
  "Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $ownerPid = $_.OwningProcess; $proc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $ownerPid }; if ($proc.CommandLine -and $proc.CommandLine -match 'server\.py' -and ($proc.CommandLine -match 'sprite-video-lab' -or $proc.CommandLine -match 'SVL')) { try { Stop-Process -Id $ownerPid -Force -ErrorAction Stop } catch {} } }"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$python = '%PYTHON_EXE%';" ^
  "$serverPath = [System.IO.Path]::GetFullPath('%~dp0server.py');" ^
  "$workDir = [System.IO.Path]::GetFullPath('%~dp0');" ^
  "$hostName = '%SPRITE_VIDEO_LAB_HOST%';" ^
  "$port = [int]'%SPRITE_VIDEO_LAB_PORT%';" ^
  "$url = 'http://' + $hostName + ':' + $port;" ^
  "$healthUrl = $url + '/api/health';" ^
  "$stdoutLog = [System.IO.Path]::GetFullPath('%SVL_STDOUT_LOG%');" ^
  "$stderrLog = [System.IO.Path]::GetFullPath('%SVL_STDERR_LOG%');" ^
  "Remove-Item -LiteralPath $stdoutLog,$stderrLog -Force -ErrorAction SilentlyContinue;" ^
  "$proc = Start-Process -FilePath $python -ArgumentList @('-u', $serverPath, '--serve', '--host', $hostName, '--port', [string]$port) -WorkingDirectory $workDir -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -WindowStyle Hidden -PassThru;" ^
  "$ready = $false;" ^
  "for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; if ($proc.HasExited) { break }; try { $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2; if ($response.StatusCode -eq 200) { $ready = $true; break } } catch {} };" ^
  "if ($ready) { Write-Host ('Sprite Video Lab running at ' + $url); Write-Host ('Logs: ' + $stdoutLog); Start-Process $url; exit 0 };" ^
  "Write-Host 'Sprite Video Lab failed to become ready.' -ForegroundColor Red;" ^
  "if ($proc.HasExited) { Write-Host ('Server process exited with code ' + $proc.ExitCode + '.') } else { Write-Host ('Server PID ' + $proc.Id + ' is still running, but health check timed out.'); $listeners = @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue); $listeners | Format-Table -AutoSize | Out-String | Write-Host; $listeners | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { $owner = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $_) -ErrorAction SilentlyContinue; if ($owner) { Write-Host ('Port owner PID ' + $owner.ProcessId + ': ' + $owner.CommandLine) } } };" ^
  "Write-Host ('Stdout log: ' + $stdoutLog);" ^
  "Write-Host ('Stderr log: ' + $stderrLog);" ^
  "if (Test-Path -LiteralPath $stdoutLog) { Write-Host '--- server.log tail ---'; Get-Content -LiteralPath $stdoutLog -Tail 40 };" ^
  "if (Test-Path -LiteralPath $stderrLog) { Write-Host '--- server-error.log tail ---'; Get-Content -LiteralPath $stderrLog -Tail 80 };" ^
  "exit 1"
if errorlevel 1 (
  echo.
  echo Start failed. See:
  echo   %SVL_STDOUT_LOG%
  echo   %SVL_STDERR_LOG%
  pause
  exit /b 1
)
