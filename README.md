# Tang Nano 9K LED点滅プロジェクト

Sipeed Tang Nano 9K の最初の FPGA 学習用プロジェクトです。
27MHz クロックを使って、基板上の LED0 だけを点滅させます。

## 対象環境

- Windows 11
- GOWIN EDA 1.9.12.03
- GOWIN Programmer
- FPGA: GW1NR-9C
- HDL: Verilog HDL

## ファイル構成

- `src/top.v`: LED点滅回路の Verilog HDL ソースです。
- `constraints/tang_nano_9k.cst`: Tang Nano 9K のクロックと LED0 のピン制約です。
- `scripts/build.tcl`: GOWIN EDA の `gw_sh.exe` で実行するビルド手順です。
- `scripts/build.ps1`: Windows PowerShell からビルドを実行する補助スクリプトです。
- `scripts/scan.ps1`: GOWIN Programmer で接続デバイスを確認するスクリプトです。
- `scripts/program_sram.ps1`: 生成した `.fs` を SRAM に書き込むスクリプトです。
- `build/`: ビルド成果物の出力先です。

## LED点滅の内容

- 入力クロックは Tang Nano 9K 基板上の 27MHz クロックです。
- LEDは Active Low なので、出力が `0` のときに点灯します。
- LED0 だけを使い、約1秒周期で点滅します。

## ビルド方法

GOWIN EDA をインストールしたあと、PowerShell で次を実行します。

```powershell
.\scripts\build.ps1
```

`gw_sh.exe` が見つからない場合は、`GOWIN_HOME` を GOWIN のインストール先に設定するか、
GOWIN EDA の `IDE\bin` を `PATH` に追加してください。

ビルドが成功すると、SRAM書き込みに使う `.fs` ファイルが次の場所に生成されます。

```text
build\impl\pnr\led_blink.fs
```

## 接続確認

Tang Nano 9K を USB で接続してから、PowerShell で次を実行します。

```powershell
.\scripts\scan.ps1
```

## SRAM書き込み方法

ビルド後、PowerShell で次を実行します。

```powershell
.\scripts\program_sram.ps1
```

このスクリプトは GOWIN Programmer CLI の `--run 2` を使います。
これは SRAM Program であり、Flash 書き込みではありません。

## 注意

- Flash 書き込みは禁止です。
- 動作確認は SRAM 書き込みで行ってください。
- ピン番号は勝手に変更しないでください。
- ピン制約を変える前に、必ず既存の `constraints/tang_nano_9k.cst` を確認してください。
