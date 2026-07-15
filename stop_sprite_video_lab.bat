@echo off
setlocal
cd /d "%~dp0"

if "%SPRITE_VIDEO_LAB_PORT%"=="" set "SPRITE_VIDEO_LAB_PORT=8894"

echo Sprite Video Lab
echo Project: %CD%
echo Port:    %SPRITE_VIDEO_LAB_PORT%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$projectRoot = [System.IO.Path]::GetFullPath('%~dp0');" ^
  "$serverPath = [System.IO.Path]::GetFullPath('%~dp0server.py');" ^
  "$serverPattern = [Regex]::Escape($serverPath);" ^
  "$projectPattern = [Regex]::Escape($projectRoot.TrimEnd('\'));" ^
  "$port = [int]'%SPRITE_VIDEO_LAB_PORT%';" ^
  "$matched = @{};" ^
  "$servers = Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'python*' -and $_.CommandLine -and ($_.CommandLine -match $serverPattern -or ($_.CommandLine -match 'server\.py' -and $_.CommandLine -match $projectPattern)) };" ^
  "foreach ($proc in $servers) { $matched[$proc.ProcessId] = $proc };" ^
  "Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $ownerPid = $_.OwningProcess; $proc = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $ownerPid }; if ($proc -and $proc.CommandLine -and $proc.CommandLine -match 'server\.py' -and ($proc.CommandLine -match $projectPattern -or $proc.CommandLine -match 'sprite-video-lab')) { $matched[$ownerPid] = $proc } };" ^
  "if ($matched.Count -eq 0) { Write-Host 'No Sprite Video Lab server is running.'; exit 0 };" ^
  "Write-Host 'Stopping PID(s):'; $matched.Keys | Sort-Object | ForEach-Object { Write-Host ('  ' + $_) };" ^
  "foreach ($processId in $matched.Keys) { try { Stop-Process -Id $processId -Force -ErrorAction Stop } catch { Write-Warning $_.Exception.Message } };" ^
  "Start-Sleep -Seconds 1;" ^
  "$remaining = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue;" ^
  "if ($remaining) { Write-Warning ('Port ' + $port + ' is still listening. Check Task Manager or run Get-NetTCPConnection manually.') } else { Write-Host 'Stopped.' }"

pause
