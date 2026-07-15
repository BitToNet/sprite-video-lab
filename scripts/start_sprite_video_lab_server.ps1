param(
  [Parameter(Mandatory = $true)][string]$PythonExe,
  [Parameter(Mandatory = $true)][string]$ServerPath,
  [Parameter(Mandatory = $true)][string]$HostName,
  [Parameter(Mandatory = $true)][int]$Port,
  [Parameter(Mandatory = $true)][string]$StdoutLog,
  [Parameter(Mandatory = $true)][string]$StderrLog,
  [Parameter(Mandatory = $false)][string]$LaunchLog = ""
)

$ErrorActionPreference = "Stop"

function Write-SvlLog {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message)

  $line = "[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + "] " + $Message
  Write-Host $line
  if ($script:LaunchLogPath) {
    try {
      Add-Content -LiteralPath $script:LaunchLogPath -Value $line -Encoding UTF8
    } catch {
      Write-Host ("[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") + "] Failed to write launcher log: " + $_.Exception.Message)
    }
  }
}

function Test-SvlHealth {
  param(
    [Parameter(Mandatory = $true)][string]$TargetHost,
    [Parameter(Mandatory = $true)][int]$TargetPort
  )

  $client = $null
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $connect = $client.BeginConnect($TargetHost, $TargetPort, $null, $null)
    if (-not $connect.AsyncWaitHandle.WaitOne(2000, $false)) {
      return $false
    }
    $client.EndConnect($connect)

    $stream = $client.GetStream()
    $stream.ReadTimeout = 2000
    $stream.WriteTimeout = 2000
    $request = "GET /api/health HTTP/1.1`r`nHost: $TargetHost`r`nConnection: close`r`n`r`n"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
    $stream.Write($bytes, 0, $bytes.Length)

    $buffer = New-Object byte[] 512
    $count = $stream.Read($buffer, 0, $buffer.Length)
    if ($count -le 0) {
      return $false
    }
    $text = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $count)
    return $text.StartsWith("HTTP/1.0 200") -or $text.StartsWith("HTTP/1.1 200")
  } catch {
    return $false
  } finally {
    if ($client -ne $null) {
      $client.Close()
    }
  }
}

function Test-SvlServerLogReady {
  param(
    [Parameter(Mandatory = $true)][string]$TargetLog,
    [Parameter(Mandatory = $true)][string]$TargetUrl
  )

  if (-not (Test-Path -LiteralPath $TargetLog)) {
    return $false
  }
  try {
    $recent = @(Get-Content -LiteralPath $TargetLog -Tail 20 -ErrorAction Stop)
    return ($recent | Where-Object { $_ -like ("*Sprite Video Lab running at " + $TargetUrl + "*") }).Count -gt 0
  } catch {
    return $false
  }
}

function Write-PortOwners {
  param([int]$TargetPort)

  $listeners = @(Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue)
  $listeners | Format-Table -AutoSize | Out-String | ForEach-Object {
    if (-not [string]::IsNullOrWhiteSpace($_)) {
      Write-SvlLog $_
    }
  }
  $listeners |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
      $owner = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $_) -ErrorAction SilentlyContinue
      if ($owner) {
        Write-SvlLog ("Port owner PID " + $owner.ProcessId + ": " + $owner.CommandLine)
      }
    }
}

$serverPath = [System.IO.Path]::GetFullPath($ServerPath)
$workDir = Split-Path -Parent $serverPath
$stdoutLog = [System.IO.Path]::GetFullPath($StdoutLog)
$stderrLog = [System.IO.Path]::GetFullPath($StderrLog)
$logDir = Split-Path -Parent $stdoutLog
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$script:LaunchLogPath = ""
if (-not [string]::IsNullOrWhiteSpace($LaunchLog)) {
  $script:LaunchLogPath = [System.IO.Path]::GetFullPath($LaunchLog)
  $launchLogDir = Split-Path -Parent $script:LaunchLogPath
  if (-not (Test-Path -LiteralPath $launchLogDir)) {
    New-Item -ItemType Directory -Path $launchLogDir -Force | Out-Null
  }
}

Write-SvlLog "PowerShell server launcher started."
Write-SvlLog ("PythonExe: " + $PythonExe)
Write-SvlLog ("ServerPath: " + $serverPath)
Write-SvlLog ("WorkingDirectory: " + $workDir)
Write-SvlLog ("Host: " + $HostName)
Write-SvlLog ("Port: " + $Port)
Write-SvlLog ("StdoutLog: " + $stdoutLog)
Write-SvlLog ("StderrLog: " + $stderrLog)

Write-SvlLog "Clearing previous server stdout/stderr logs..."
Remove-Item -LiteralPath $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

$url = "http://$($HostName):$Port"
$browserUrl = $url
if ($HostName -eq "127.0.0.1") {
  $browserUrl = "http://localhost:$Port"
}

Write-SvlLog "Starting Python server process..."
$proc = Start-Process `
  -FilePath $PythonExe `
  -ArgumentList @("-u", $serverPath, "--serve", "--host", $HostName, "--port", [string]$Port) `
  -WorkingDirectory $workDir `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -WindowStyle Hidden `
  -PassThru
Write-SvlLog ("Python server process started. PID: " + $proc.Id)

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  if ($proc.HasExited) {
    Write-SvlLog ("Python server process exited during readiness check. ExitCode: " + $proc.ExitCode)
    break
  }
  if ($i -eq 0 -or (($i + 1) % 5) -eq 0) {
    Write-SvlLog ("Health check attempt " + ($i + 1) + "/40...")
    if (Test-Path -LiteralPath $stderrLog) {
      $recentStderr = @(Get-Content -LiteralPath $stderrLog -Tail 12 -ErrorAction SilentlyContinue)
      if ($recentStderr.Count -gt 0) {
        Write-SvlLog "--- recent server-error.log ---"
        $recentStderr | ForEach-Object { Write-SvlLog ([string]$_) }
      }
    }
  }
  if (Test-SvlHealth -TargetHost $HostName -TargetPort $Port) {
    $ready = $true
    Write-SvlLog ("Health check succeeded on attempt " + ($i + 1) + ".")
    break
  }
  if (Test-SvlServerLogReady -TargetLog $stdoutLog -TargetUrl $url) {
    $ready = $true
    Write-SvlLog ("Server log readiness confirmed on attempt " + ($i + 1) + ".")
    break
  }
}

if ($ready) {
  Write-SvlLog ("Sprite Video Lab running at " + $url)
  Write-SvlLog ("Opening " + $browserUrl)
  Write-SvlLog ("Logs: " + $stdoutLog)
  Start-Process $browserUrl
  exit 0
}

Write-SvlLog "Sprite Video Lab failed to become ready."
if ($proc.HasExited) {
  Write-SvlLog ("Server process exited with code " + $proc.ExitCode + ".")
} else {
  Write-SvlLog ("Server PID " + $proc.Id + " is still running, but raw TCP health check timed out.")
  Write-PortOwners -TargetPort $Port
}
Write-SvlLog ("Stdout log: " + $stdoutLog)
Write-SvlLog ("Stderr log: " + $stderrLog)
if (Test-Path -LiteralPath $stdoutLog) {
  Write-SvlLog "--- server.log tail ---"
  Get-Content -LiteralPath $stdoutLog -Tail 40 | ForEach-Object { Write-SvlLog ([string]$_) }
}
if (Test-Path -LiteralPath $stderrLog) {
  Write-SvlLog "--- server-error.log tail ---"
  Get-Content -LiteralPath $stderrLog -Tail 80 | ForEach-Object { Write-SvlLog ([string]$_) }
}
exit 1
