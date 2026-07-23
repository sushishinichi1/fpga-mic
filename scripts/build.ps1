$ErrorActionPreference = "Stop"

# Build only. This script does not program the FPGA.
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$BuildTcl = Join-Path $RepoRoot "scripts\build.tcl"

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

    throw "$ToolName was not found. Set GOWIN_HOME or add GOWIN EDA IDE\bin to PATH."
}

$GwSh = Find-GowinTool -ToolName "gw_sh.exe" -RelativePath "IDE\bin\gw_sh.exe"

Push-Location $RepoRoot
try {
    & $GwSh $BuildTcl
}
finally {
    Pop-Location
}
