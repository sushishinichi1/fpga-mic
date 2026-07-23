param(
    [string]$FsFile,
    [int]$CableIndex = 1
)

$ErrorActionPreference = "Stop"

# Program the FPGA SRAM only.
# Flash programming is forbidden in this project.
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if (-not $FsFile) {
    $FsFile = Join-Path $RepoRoot "build\led_blink\impl\pnr\led_blink.fs"
}

if (-not (Test-Path $FsFile)) {
    throw ".fs file was not found. Run scripts\build.ps1 first: $FsFile"
}

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

# --run 2 is SRAM Program in GOWIN Programmer. This is not Flash programming.
& $ProgrammerCli --device GW1NR-9C --run 2 --fsFile $FsFile --cable-index $CableIndex
