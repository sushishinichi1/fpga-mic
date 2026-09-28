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
Remove-Item -LiteralPath (Join-Path $simDir "uart_heartbeat_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_uart_path_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "top_audio_uart_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_band_analyzer_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_fft_analyzer_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "fft_spectrum_bands_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "spectrum_uart_path_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "beat_detector_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_beat_integration_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "bpm_divider_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "bpm_detector_tb.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "sync_fifo_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "dot_product_accel_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "uart_heartbeat_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_uart_path_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "top_audio_uart_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_band_analyzer_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_fft_analyzer_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "fft_spectrum_bands_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "spectrum_uart_path_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "beat_detector_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "audio_beat_integration_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "bpm_divider_tb.vcd") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "bpm_detector_tb.vcd") -ErrorAction SilentlyContinue

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

    Run-Testbench `
        -Name "uart_heartbeat_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\uart_tx.v"),
            (Join-Path $repoRoot "src\uart_heartbeat.v"),
            (Join-Path $repoRoot "tb\uart_heartbeat_tb.v")
        )
    Write-Host "[PASS] uart_heartbeat_tb"

    Run-Testbench `
        -Name "audio_uart_path_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\uart_tx.v"),
            (Join-Path $repoRoot "src\audio_uart_sender.v"),
            (Join-Path $repoRoot "tb\audio_uart_path_tb.v")
        )
    Write-Host "[PASS] audio_uart_path_tb"

    Run-Testbench `
        -Name "top_audio_uart_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\uart_tx.v"),
            (Join-Path $repoRoot "src\inmp441_i2s_rx.v"),
            (Join-Path $repoRoot "src\audio_band_analyzer.v"),
            (Join-Path $repoRoot "src\fft_hann_window.v"),
            (Join-Path $repoRoot "src\fft_data_ram.v"),
            (Join-Path $repoRoot "src\fft_twiddle_rom.v"),
            (Join-Path $repoRoot "src\fft_butterfly.v"),
            (Join-Path $repoRoot "src\fft_magnitude.v"),
            (Join-Path $repoRoot "src\fft_core_iterative.v"),
            (Join-Path $repoRoot "src\audio_fft_analyzer.v"),
            (Join-Path $repoRoot "src\beat_detector.v"),
            (Join-Path $repoRoot "src\bpm_divider.v"),
            (Join-Path $repoRoot "src\bpm_detector.v"),
            (Join-Path $repoRoot "src\audio_uart_sender.v"),
            (Join-Path $repoRoot "src\spectrum_uart_sender.v"),
            (Join-Path $repoRoot "src\top.v"),
            (Join-Path $repoRoot "tb\top_audio_uart_tb.v")
        )
    Write-Host "[PASS] top_audio_uart_tb"

    Run-Testbench `
        -Name "audio_band_analyzer_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\audio_band_analyzer.v"),
            (Join-Path $repoRoot "tb\audio_band_analyzer_tb.v")
        )
    Write-Host "[PASS] audio_band_analyzer_tb"

    Run-Testbench `
        -Name "audio_fft_analyzer_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\fft_hann_window.v"),
            (Join-Path $repoRoot "src\fft_data_ram.v"),
            (Join-Path $repoRoot "src\fft_twiddle_rom.v"),
            (Join-Path $repoRoot "src\fft_butterfly.v"),
            (Join-Path $repoRoot "src\fft_magnitude.v"),
            (Join-Path $repoRoot "src\fft_core_iterative.v"),
            (Join-Path $repoRoot "src\audio_fft_analyzer.v"),
            (Join-Path $repoRoot "tb\audio_fft_analyzer_tb.v")
        )
    Write-Host "[PASS] audio_fft_analyzer_tb"

    Run-Testbench `
        -Name "fft_spectrum_bands_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\fft_hann_window.v"),
            (Join-Path $repoRoot "src\fft_data_ram.v"),
            (Join-Path $repoRoot "src\fft_twiddle_rom.v"),
            (Join-Path $repoRoot "src\fft_butterfly.v"),
            (Join-Path $repoRoot "src\fft_magnitude.v"),
            (Join-Path $repoRoot "src\fft_core_iterative.v"),
            (Join-Path $repoRoot "src\audio_fft_analyzer.v"),
            (Join-Path $repoRoot "tb\fft_spectrum_bands_tb.v")
        )
    Write-Host "[PASS] fft_spectrum_bands_tb"

    Run-Testbench `
        -Name "spectrum_uart_path_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\uart_tx.v"),
            (Join-Path $repoRoot "src\spectrum_uart_sender.v"),
            (Join-Path $repoRoot "tb\spectrum_uart_path_tb.v")
        )
    Write-Host "[PASS] spectrum_uart_path_tb"

    Run-Testbench `
        -Name "beat_detector_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\beat_detector.v"),
            (Join-Path $repoRoot "tb\beat_detector_tb.v")
        )
    Write-Host "[PASS] beat_detector_tb"

    Run-Testbench `
        -Name "audio_beat_integration_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\fft_hann_window.v"),
            (Join-Path $repoRoot "src\fft_data_ram.v"),
            (Join-Path $repoRoot "src\fft_twiddle_rom.v"),
            (Join-Path $repoRoot "src\fft_butterfly.v"),
            (Join-Path $repoRoot "src\fft_magnitude.v"),
            (Join-Path $repoRoot "src\fft_core_iterative.v"),
            (Join-Path $repoRoot "src\audio_fft_analyzer.v"),
            (Join-Path $repoRoot "src\beat_detector.v"),
            (Join-Path $repoRoot "tb\audio_beat_integration_tb.v")
        )
    Write-Host "[PASS] audio_beat_integration_tb"

    Run-Testbench `
        -Name "bpm_divider_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\bpm_divider.v"),
            (Join-Path $repoRoot "tb\bpm_divider_tb.v")
        )
    Write-Host "[PASS] bpm_divider_tb"

    Run-Testbench `
        -Name "bpm_detector_tb" `
        -Sources @(
            (Join-Path $repoRoot "src\bpm_divider.v"),
            (Join-Path $repoRoot "src\bpm_detector.v"),
            (Join-Path $repoRoot "tb\bpm_detector_tb.v")
        )
    Write-Host "[PASS] bpm_detector_tb"
} finally {
    Pop-Location
}

Write-Host "[PASS] All RTL simulations completed"
