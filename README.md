# Tang Nano 9K ボタン押下カウンター UART 送信

Sipeed Tang Nano 9K の左ボタンを押すたびに、32bit カウンターを 1 加算し、UART 115200bps で Windows へ送信する FPGA 学習用プロジェクトです。

送信される文字列は次の形式です。末尾にはターミナルで読みやすいように CRLF を付けています。

```text
COUNT: 00000001
```

## 仕様

- ボード: Sipeed Tang Nano 9K
- クロック: 27MHz
- HDL: Verilog-2001
- 左ボタン: pin 3、Active Low
- LED0: pin 10、Active Low
- UART TX: pin 17、115200bps、8N1
- デバウンス: 20ms
- カウンター: 32bit、押下ごとに 1 加算
- 書き込み: SRAM のみ
- Flash 書き込みは禁止

## ファイル構成

- `src/top.v`: 各モジュールを接続するトップモジュールです。
- `src/button_debounce.v`: Active Low ボタンを同期し、20ms デバウンス後に押下パルスを出します。
- `src/press_counter.v`: 押下パルスごとに 32bit カウンターを加算します。
- `src/count_uart_sender.v`: `COUNT: XXXXXXXX` 形式の送信データを作ります。
- `src/uart_tx.v`: 115200bps の UART TX です。
- `constraints/tang_nano_9k.cst`: クロック、ボタン、LED0、UART TX のピン制約です。
- `constraints/tang_nano_9k.sdc`: 27MHz クロックのタイミング制約です。
- `scripts/build.tcl`: GOWIN EDA の `gw_sh.exe` で実行するビルド手順です。
- `scripts/build.ps1`: PowerShell からビルドを実行する補助スクリプトです。
- `scripts/program_sram.ps1`: 生成された `.fs` を SRAM にだけ書き込む補助スクリプトです。
- `scripts/scan.ps1`: GOWIN Programmer で接続デバイスを確認する補助スクリプトです。
- `build/`: GOWIN EDA のビルド成果物出力先です。

## 想定されるビルド手順

PowerShell を開き、このリポジトリのルートで次を実行します。

```powershell
.\scripts\build.ps1
```

`gw_sh.exe` が見つからない場合は、`GOWIN_HOME` を GOWIN EDA のインストール先に設定するか、GOWIN EDA の `IDE\bin` を `PATH` に追加してください。

ビルドが成功すると、SRAM 書き込みに使う `.fs` ファイルが次の場所に生成されます。

```text
build\button_uart_count\impl\pnr\button_uart_count.fs
```

## SRAM 書き込み手順

Tang Nano 9K を USB 接続し、必要に応じてデバイスを確認します。

```powershell
.\scripts\scan.ps1
```

ビルド後、次のコマンドで SRAM に書き込みます。

```powershell
.\scripts\program_sram.ps1
```

`program_sram.ps1` は GOWIN Programmer CLI の `--run 2` を使います。これは SRAM Program であり、Flash 書き込みではありません。

## Windows での UART 確認

Windows のデバイス マネージャーで Tang Nano 9K の USB-UART に対応する COM ポートを確認します。

任意のシリアルターミナルを開き、次の設定で接続します。

- Baud rate: 115200
- Data bits: 8
- Parity: none
- Stop bits: 1
- Flow control: none

左ボタンを押すたびに、次のようにカウント値が表示されます。

```text
COUNT: 00000001
COUNT: 00000002
COUNT: 00000003
```

FPGA への書き込み時は、シリアルターミナルで COM ポートを開いたままだと Programmer が使えない場合があります。その場合はターミナルを切断してから SRAM 書き込みを行ってください。

## 注意

- Flash 書き込みは行わないでください。
- 動作確認は SRAM 書き込みで行ってください。
- ピン番号は必要がない限り変更しないでください。
- UART TX は Tang Nano 9K のオンボード USB-UART で使われる pin 17 に割り当てています。
