$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$simDir = Join-Path $repoRoot "build\sim"

function Require-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $tool = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $tool) {
        Write-Error "$Name was not found. Install Icarus Verilog and add $Name to PATH, then run this script again."
        exit 1
    }
}

function Run-Testbench {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Sources
    )

    $outputPath = Join-Path $simDir "$Name.vvp"
    Write-Host "Compiling $Name..."
    & iverilog -g2012 -o $outputPath @Sources
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to compile $Name."
        exit $LASTEXITCODE
    }

    Write-Host "Running $Name..."
    & vvp $outputPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$Name failed."
        exit $LASTEXITCODE
    }
}

Require-Tool "iverilog"
Require-Tool "vvp"

New-Item -ItemType Directory -Force -Path $simDir | Out-Null
Remove-Item -LiteralPath (Join-Path $simDir "sync_fifo_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "dot_product_accel_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "sync_fifo_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "dot_product_accel_tb.vcd") -ErrorAction SilentlyContinue

Push-Location $repoRoot
try {
    Run-Testbench `
        -Name "sync_fifo_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\sync_fifo.v"),
            (Join-Path $repoRoot "tb\sync_fifo_tb.v")
        )
    Write-Host "[PASS] sync_fifo_tb"

    Run-Testbench `
        -Name "dot_product_accel_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\sync_fifo.v"),
            (Join-Path $repoRoot "src\dot_product_accel.v"),
            (Join-Path $repoRoot "tb\dot_product_accel_tb.v")
        )
    Write-Host "[PASS] dot_product_accel_tb"
} finally {
    Pop-Location
}

Write-Host "[PASS] All RTL simulations completed"
