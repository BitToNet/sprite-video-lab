param(
  [Parameter(Mandatory = $true)][string]$PythonExe,
  [Parameter(Mandatory = $true)][string]$ServerPath,
  [Parameter(Mandatory = $true)][string]$HostName,
  [Parameter(Mandatory = $true)][int]$Port,
  [Parameter(Mandatory = $true)][string]$StdoutLog,
  [Parameter(Mandatory = $true)][string]$StderrLog
)

$ErrorActionPreference = "Stop"

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

function Write-PortOwners {
  param([int]$TargetPort)

  $listeners = @(Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue)
  $listeners | Format-Table -AutoSize | Out-String | Write-Host
  $listeners |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
      $owner = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $_) -ErrorAction SilentlyContinue
      if ($owner) {
        Write-Host ("Port owner PID " + $owner.ProcessId + ": " + $owner.CommandLine)
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

Remove-Item -LiteralPath $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

$url = "http://$($HostName):$Port"
$browserUrl = $url
if ($HostName -eq "127.0.0.1") {
  $browserUrl = "http://localhost:$Port"
}

$proc = Start-Process `
  -FilePath $PythonExe `
  -ArgumentList @("-u", $serverPath, "--serve", "--host", $HostName, "--port", [string]$Port) `
  -WorkingDirectory $workDir `
  -RedirectStandardOutput $stdoutLog `
  -RedirectStandardError $stderrLog `
  -WindowStyle Hidden `
  -PassThru

$ready = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  if ($proc.HasExited) {
    break
  }
  if (Test-SvlHealth -TargetHost $HostName -TargetPort $Port) {
    $ready = $true
    break
  }
}

if ($ready) {
  Write-Host ("Sprite Video Lab running at " + $url)
  Write-Host ("Opening " + $browserUrl)
  Write-Host ("Logs: " + $stdoutLog)
  Start-Process $browserUrl
  exit 0
}

Write-Host "Sprite Video Lab failed to become ready." -ForegroundColor Red
if ($proc.HasExited) {
  Write-Host ("Server process exited with code " + $proc.ExitCode + ".")
} else {
  Write-Host ("Server PID " + $proc.Id + " is still running, but raw TCP health check timed out.")
  Write-PortOwners -TargetPort $Port
}
Write-Host ("Stdout log: " + $stdoutLog)
Write-Host ("Stderr log: " + $stderrLog)
if (Test-Path -LiteralPath $stdoutLog) {
  Write-Host "--- server.log tail ---"
  Get-Content -LiteralPath $stdoutLog -Tail 40
}
if (Test-Path -LiteralPath $stderrLog) {
  Write-Host "--- server-error.log tail ---"
  Get-Content -LiteralPath $stderrLog -Tail 80
}
exit 1
