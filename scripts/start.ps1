$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SerialLoggerPath = Join-Path $RepoRoot "pc_app\serial_logger.py"
$CountServerPath = Join-Path $RepoRoot "scripts\count_log_server.mjs"

Set-Location $RepoRoot.Path

function Test-ProjectScriptCommandLine {
    param(
        [string] $CommandLine,
        [string] $ScriptPath
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $false
    }

    $normalizedCommandLine = $CommandLine.Replace("/", "\")
    $normalizedScriptPath = $ScriptPath.Replace("/", "\")
    $relativeScriptPath = $normalizedScriptPath.Substring($RepoRoot.Path.Length + 1)

    return $normalizedCommandLine.Contains($normalizedScriptPath) -or
        $normalizedCommandLine.Contains($relativeScriptPath)
}

function Stop-ProjectScriptProcess {
    param(
        [string] $ScriptPath
    )

    Get-CimInstance Win32_Process |
        Where-Object { Test-ProjectScriptCommandLine $_.CommandLine $ScriptPath } |
        ForEach-Object {
            Write-Host "Stopping existing process $($_.ProcessId): $($_.CommandLine)"
            Stop-Process -Id $_.ProcessId -Force
        }
}

Stop-ProjectScriptProcess $SerialLoggerPath
Stop-ProjectScriptProcess $CountServerPath

Start-Process powershell -WorkingDirectory $RepoRoot.Path -ArgumentList '-NoExit', '-Command', "py `"$SerialLoggerPath`""

Start-Sleep -Seconds 1

node $CountServerPath
