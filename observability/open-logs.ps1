<#
.SYNOPSIS
    Opens a secure SSH tunnel to VictoriaLogs (127.0.0.1:9428) and launches the default browser to vmui.

.DESCRIPTION
    Connects to a remote Linux host via OpenSSH, forwards local port 9428 to remote 127.0.0.1:9428,
    waits until the tunnel is listening, opens the default web browser to http://localhost:9428/select/vmui/,
    and closes the SSH tunnel cleanly when you press Ctrl+C.

    If -Target / -HostName are omitted, it automatically loads SSH_HOST/HOSTNAME/HOST,
    SSH_USER/USER, and SSH_PORT/PORT from:
      1. -EnvFile (if specified)
      2. .\.env in the current working directory
      3. ..\.env at the TECHSTACK root (e.g., C:\GIT\TECHSTACK\.env)

.EXAMPLE
    .\open-logs.ps1
.EXAMPLE
    .\open-logs.ps1 user@203.0.113.10
.EXAMPLE
    .\open-logs.ps1 -EnvFile C:\path\to\.env
.EXAMPLE
    .\open-logs.ps1 -HostName 192.168.1.50 -User pi -Port 2222
#>
param(
    [Parameter(Position = 0)]
    [string]$Target,
    [string]$HostName,
    [string]$User,
    [int]$Port = 0,
    [int]$LocalPort = 9428,
    [int]$RemotePort = 9428,
    [string]$EnvFile
)

$ErrorActionPreference = "Stop"

function Test-LocalPortOpen {
    param([int]$PortToCheck)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect("127.0.0.1", $PortToCheck, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(250, $false)) {
            $client.EndConnect($iar)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Read-DotEnvFile {
    param([string]$Path)
    $map = @{}
    if ($Path -and (Test-Path $Path)) {
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line -match "^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$") {
                $k = $matches[1].Trim()
                $rawVal = $matches[2].Trim()
                if (($rawVal.StartsWith('"') -and $rawVal.EndsWith('"')) -or ($rawVal.StartsWith("'") -and $rawVal.EndsWith("'"))) {
                    $v = $rawVal.Substring(1, $rawVal.Length - 2)
                } else {
                    $v = ($rawVal -split "\s+#")[0].Trim()
                }
                $map[$k] = $v
            }
        }
    }
    return $map
}

function Get-FirstMapValue {
    param([hashtable]$Map, [string[]]$Keys)
    foreach ($k in $Keys) {
        if ($Map.ContainsKey($k) -and $Map[$k]) {
            return $Map[$k]
        }
    }
    return ""
}

# Resolve .env file: explicit -EnvFile -> CWD .env -> TECHSTACK root .env
$techstackRoot = Split-Path -Parent $PSScriptRoot
$candidateEnvPaths = @()
if ($EnvFile) {
    $candidateEnvPaths += $EnvFile
} else {
    $candidateEnvPaths += (Join-Path (Get-Location).Path ".env")
    $candidateEnvPaths += (Join-Path $techstackRoot ".env")
}

$resolvedEnvPath = $candidateEnvPaths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($EnvFile -and -not $resolvedEnvPath) {
    Write-Host "ERROR: Specified -EnvFile not found: $EnvFile" -ForegroundColor Red
    exit 1
}
$envMap = if ($resolvedEnvPath) { Read-DotEnvFile -Path $resolvedEnvPath } else { @{} }

if (-not $Target) {
    if (-not $HostName) {
        $HostName = Get-FirstMapValue -Map $envMap -Keys @("SSH_HOST", "HOSTNAME", "HOST")
        if (-not $HostName -and $env:SSH_HOST) { $HostName = $env:SSH_HOST }
    }
    if (-not $User) {
        $User = Get-FirstMapValue -Map $envMap -Keys @("SSH_USER", "USER")
        if (-not $User -and $env:SSH_USER) { $User = $env:SSH_USER }
    }
    if ($Port -eq 0) {
        $rawPort = Get-FirstMapValue -Map $envMap -Keys @("SSH_PORT", "PORT")
        if (-not $rawPort -and $env:SSH_PORT) { $rawPort = $env:SSH_PORT }
        if ($rawPort -match "^\d+$") { $Port = [int]$rawPort }
    }

    if (-not $HostName) {
        Write-Host "ERROR: No target specified and no SSH_HOST/HOSTNAME found in .env." -ForegroundColor Red
        Write-Host "Checked .env locations: $($candidateEnvPaths -join ', ')" -ForegroundColor DarkGray
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\open-logs.ps1 <user@server-ip>"
        Write-Host "  .\open-logs.ps1 -EnvFile path\to\.env"
        Write-Host "  .\open-logs.ps1 -HostName <server-ip> -User <user> [-Port 22]"
        exit 1
    }

    if ($resolvedEnvPath) {
        Write-Host "Loaded target config from: $resolvedEnvPath" -ForegroundColor DarkGray
    }
    $Target = if ($User) { "${User}@${HostName}" } else { $HostName }
}

$uiUrl = "http://localhost:$LocalPort/select/vmui/"

if (Test-LocalPortOpen -PortToCheck $LocalPort) {
    Write-Host "Local port $LocalPort is already open. Launching browser to $uiUrl ..." -ForegroundColor Green
    Start-Process $uiUrl
    exit 0
}

$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshCmd) {
    Write-Host "ERROR: OpenSSH client ('ssh') not found in PATH." -ForegroundColor Red
    exit 1
}

$sshArgs = @(
    "-N",
    "-o", "ExitOnForwardFailure=yes",
    "-o", "ServerAliveInterval=30",
    "-o", "ServerAliveCountMax=3",
    "-L", "${LocalPort}:127.0.0.1:${RemotePort}"
)
if ($Port -gt 0) {
    $sshArgs += @("-p", "$Port")
}
$sshArgs += $Target

Write-Host "Opening SSH tunnel to $Target (127.0.0.1:$LocalPort -> remote 127.0.0.1:$RemotePort)..." -ForegroundColor Cyan
Write-Host "If prompted, enter your SSH password or key passphrase." -ForegroundColor DarkGray

$sshProc = Start-Process -FilePath $sshCmd.Source -ArgumentList $sshArgs -NoNewWindow -PassThru

try {
    $opened = $false
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        if ($sshProc.HasExited) {
            Write-Host "ERROR: SSH tunnel exited prematurely (exit code $($sshProc.ExitCode))." -ForegroundColor Red
            exit 1
        }
        if (Test-LocalPortOpen -PortToCheck $LocalPort) {
            $opened = $true
            break
        }
        Start-Sleep -Milliseconds 300
    }

    if (-not $opened) {
        Write-Host "ERROR: Timed out waiting for SSH tunnel on local port $LocalPort." -ForegroundColor Red
        exit 1
    }

    Write-Host "OK: Tunnel active! Opening $uiUrl in your default browser..." -ForegroundColor Green
    Write-Host "Press Ctrl+C in this terminal when you are done viewing logs to close the tunnel." -ForegroundColor Yellow
    Start-Process $uiUrl

    Wait-Process -Id $sshProc.Id
} finally {
    if ($sshProc -and -not $sshProc.HasExited) {
        Write-Host "`nClosing SSH tunnel..." -ForegroundColor Yellow
        Stop-Process -Id $sshProc.Id -Force -ErrorAction SilentlyContinue
    }
}
