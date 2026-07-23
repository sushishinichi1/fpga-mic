$ErrorActionPreference = "Stop"

# Scan devices with GOWIN Programmer.
# This script only scans. It does not program the FPGA.
function Find-GowinTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ($env:GOWIN_HOME) {
        $FromEnv = Join-Path $env:GOWIN_HOME $RelativePath
        if (Test-Path $FromEnv) {
            return $FromEnv
        }
    }

    $FromPath = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($FromPath) {
        return $FromPath.Source
    }

    throw "$ToolName was not found. Set GOWIN_HOME or add GOWIN Programmer\bin to PATH."
}

$ProgrammerCli = Find-GowinTool -ToolName "programmer_cli.exe" -RelativePath "Programmer\bin\programmer_cli.exe"

& $ProgrammerCli --scan
