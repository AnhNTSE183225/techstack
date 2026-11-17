# ==============================================================================
# TECHSTACK Windows Log Shipper (App stdout/stderr -> VictoriaLogs HTTP)
# ==============================================================================
# Tails redirected stdout/stderr files from managed Windows processes with
# FileShare.ReadWrite and pushes structured JSON lines to VictoriaLogs
# (/insert/jsonline) so Windows apps share the same LogsQL + vmui workflow
# as Linux systemd-journald.
#
# Graceful Shutdown Handshake:
#   When stop.ps1 confirms all application processes are dead, it writes
#   StopSentinelFile (e.g. .logs\.stop-shipper). This shipper executes one final
#   read-to-EOF flush across all log files, writes FlushDoneFile, and exits 0.
# ==============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [string]$IngestUrl = "http://127.0.0.1:9428/insert/jsonline?_stream_fields=app,service,host&_msg_field=message&_time_field=timestamp",
    [int]$PollIntervalMs = 150
)

$ErrorActionPreference = "Continue"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try {
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
} catch {}

if (-not (Test-Path $ConfigPath)) {
    throw "Shipper config file not found: $ConfigPath"
}

$cfg = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$appName = if ($cfg.app) { [string]$cfg.app } else { "app" }
$hostName = $env:COMPUTERNAME
$stopSentinel = [string]$cfg.stop_sentinel
$flushDoneFile = [string]$cfg.flush_done_file

# Track byte offset per source file so partial lines are buffered cleanly
$states = @()
foreach ($src in $cfg.sources) {
    $states += [PSCustomObject]@{
        Service  = [string]$src.service
        Stream   = [string]$src.stream
        Path     = [string]$src.path
        Offset   = [long]0
        Carry    = ""
    }
}

$httpClient = New-Object System.Net.Http.HttpClient
$httpClient.Timeout = [TimeSpan]::FromSeconds(5)

function Format-VictoriaLogLine {
    param(
        [string]$RawLine,
        [string]$Service,
        [string]$Stream
    )

    $trimmed = $RawLine.TrimEnd("`r", "`n")
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $null
    }

    $fallbackTs = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
    $fallbackLevel = if ($Stream -eq "stderr") { "error" } else { "info" }

    if ($trimmed.StartsWith("{") -and $trimmed.EndsWith("}")) {
        try {
            $obj = $trimmed | ConvertFrom-Json
            if ($null -ne $obj) {
                $flat = [ordered]@{}
                $ts = $fallbackTs
                if ($obj.PSObject.Properties["timestamp"] -and $obj.timestamp) {
                    $ts = [string]$obj.timestamp
                } elseif ($obj.PSObject.Properties["_time"] -and $obj._time) {
                    $ts = [string]$obj._time
                }
                $flat["timestamp"] = $ts

                $lvl = $fallbackLevel
                if ($obj.PSObject.Properties["level"] -and $obj.level) {
                    $lvl = ([string]$obj.level).ToLowerInvariant()
                }
                $flat["level"] = $lvl
                $flat["app"] = $appName
                $flat["service"] = $Service
                $flat["stream"] = $Stream
                $flat["host"] = $hostName

                $msgText = ""
                if ($obj.PSObject.Properties["fields"] -and $obj.fields) {
                    foreach ($prop in $obj.fields.PSObject.Properties) {
                        if ($prop.Name -eq "message") {
                            $msgText = [string]$prop.Value
                        } elseif (-not $flat.Contains($prop.Name)) {
                            $flat[$prop.Name] = $prop.Value
                        }
                    }
                }
                if (-not $msgText -and $obj.PSObject.Properties["message"] -and $obj.message) {
                    $msgText = [string]$obj.message
                }
                if (-not $msgText -and $obj.PSObject.Properties["msg"] -and $obj.msg) {
                    $msgText = [string]$obj.msg
                }
                if (-not $msgText) {
                    $msgText = $trimmed
                }
                $flat["message"] = $msgText

                foreach ($prop in $obj.PSObject.Properties) {
                    if ($prop.Name -in @("timestamp", "_time", "level", "fields", "message", "msg")) {
                        continue
                    }
                    if (-not $flat.Contains($prop.Name)) {
                        $flat[$prop.Name] = $prop.Value
                    }
                }

                return ($flat | ConvertTo-Json -Compress -Depth 6)
            }
        } catch {
            # Fall back to wrapping non-JSON line cleanly
        }
    }

    $inferredLevel = $fallbackLevel
    if ($trimmed -match '(?i)\b(panic|fatal|error)\b') {
        $inferredLevel = "error"
    } elseif ($trimmed -match '(?i)\bwarn(ing)?\b') {
        $inferredLevel = "warn"
    }

    $wrapped = [ordered]@{
        timestamp = $fallbackTs
        level     = $inferredLevel
        app       = $appName
        service   = $Service
        stream    = $Stream
        host      = $hostName
        message   = $trimmed
    }
    return ($wrapped | ConvertTo-Json -Compress -Depth 4)
}

function Send-BatchToVictoriaLogs {
    param([System.Collections.Generic.List[string]]$Lines)
    if ($Lines.Count -eq 0) { return }

    $ndjson = ([string]::Join("`n", $Lines)) + "`n"
    $bytes = $utf8NoBom.GetBytes($ndjson)
    $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$bytes)
    $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/stream+json; charset=utf-8")

    try {
        $resp = $httpClient.PostAsync($IngestUrl, $content).GetAwaiter().GetResult()
        $resp.Dispose()
    } catch {
        # Best-effort retry if VictoriaLogs is temporarily busy
    } finally {
        $content.Dispose()
    }
}

function Read-AvailableLines {
    param([bool]$FlushPartialTail = $false)

    $batch = New-Object 'System.Collections.Generic.List[string]'

    foreach ($st in $states) {
        if (-not (Test-Path $st.Path)) { continue }

        try {
            $fs = [System.IO.File]::Open(
                $st.Path,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            )
            try {
                if ($fs.Length -lt $st.Offset) {
                    $st.Offset = 0
                    $st.Carry = ""
                }
                if ($fs.Length -gt $st.Offset) {
                    $fs.Seek($st.Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $remaining = [int][Math]::Min(($fs.Length - $st.Offset), 1048576)
                    $buf = New-Object byte[] $remaining
                    $read = $fs.Read($buf, 0, $remaining)
                    $st.Offset += $read

                    if ($read -gt 0) {
                        $chunk = $st.Carry + $utf8NoBom.GetString($buf, 0, $read)
                        $parts = $chunk.Split("`n")
                        for ($i = 0; $i -lt ($parts.Length - 1); $i++) {
                            $formatted = Format-VictoriaLogLine -RawLine $parts[$i] -Service $st.Service -Stream $st.Stream
                            if ($formatted) { $batch.Add($formatted) }
                        }
                        $st.Carry = $parts[$parts.Length - 1]
                    }
                }
            } finally {
                $fs.Dispose()
            }
        } catch {
            # File may not be initialized yet
        }

        if ($FlushPartialTail -and (-not [string]::IsNullOrWhiteSpace($st.Carry))) {
            $formatted = Format-VictoriaLogLine -RawLine $st.Carry -Service $st.Service -Stream $st.Stream
            if ($formatted) { $batch.Add($formatted) }
            $st.Carry = ""
        }
    }

    if ($batch.Count -gt 0) {
        Send-BatchToVictoriaLogs -Lines $batch
    }
}

try {
    while ($true) {
        if ($stopSentinel -and (Test-Path $stopSentinel)) {
            # Drain any final shutdown/crash lines completely to EOF before exiting
            Read-AvailableLines -FlushPartialTail $true
            if ($flushDoneFile) {
                [System.IO.File]::WriteAllText($flushDoneFile, [DateTime]::UtcNow.ToString("o"), $utf8NoBom)
            }
            break
        }

        Read-AvailableLines -FlushPartialTail $false
        Start-Sleep -Milliseconds $PollIntervalMs
    }
} finally {
    $httpClient.Dispose()
}

exit 0
