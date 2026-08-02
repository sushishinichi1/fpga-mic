
# Tang Nano 9K Button Counter UART Monitor

Sipeed Tang Nano 9K を使った FPGA 学習用プロジェクトです。
左ボタンを押すたびに FPGA 内部の 32bit カウンタを加算し、UART で `COUNT: XXXXXXXX` を PC へ送信します。
PC 側では Python ロガーが UART を受信して CSV に保存し、Node.js の Web 画面で最新値を確認できます。

## 主な機能

- 27MHz クロック
- 左ボタン入力のデバウンス
- 32bit ボタンカウンタ
- UART による `COUNT: XXXXXXXX` 自動送信
- UART ASCII レジスタ読み書き
- Web からのカウンタ Reset
- Web からの LED ON/OFF
- Web スライダーによる LED PWM 明るさ調整
- UART レジスタ経由の SPI マスター
- Python ロガーによる CSV 保存
- Node.js Web ダッシュボード
- SRAM 書き込みのみ使用

## 現在のピン設定

現在の `constraints/tang_nano_9k.cst` から読み取れる有効な割り当ては次のとおりです。

| 信号 | FPGA pin | 備考 |
| --- | ---: | --- |
| `clk` | 52 | 27MHz clock |
| `button` | 3 | Left button, Active Low |
| `led0` | 10 | LED0, Active Low |
| `uart_tx` | 17 | Onboard USB-UART bridge |
| `uart_rx` | 18 | Onboard USB-UART bridge |
| `spi_cs_n` | 25 | Bank 2, LVCMOS33 |
| `spi_mosi` | 26 | Bank 2, LVCMOS33 |
| `spi_miso` | 27 | Bank 2, LVCMOS33 |
| `spi_sclk` | 28 | Bank 2, LVCMOS33 |

SPI ピンは `constraints/tang_nano_9k.cst` で明示的に固定しています。
既存の clock、button、LED、UART のピン設定は変更しないでください。

## UART レジスタマップ

ASCII コマンドでレジスタを読み書きします。

```text
R 00
W 08 00000001
```

| Address | Name | Access | 内容 |
| ---: | --- | --- | --- |
| `0x00` | `COUNTER` | read | 現在の 32bit カウンタ値 |
| `0x04` | `CONTROL` | write | bit0 に 1 を書くとカウンタを 1 クロックリセット |
| `0x08` | `LED` | read/write | bit0: LED enable |
| `0x0C` | `LED_PWM` | read/write | bit7:0: LED PWM duty |
| `0x10` | `SPI_TX` | read/write | bit7:0: 次に SPI 送信する値 |
| `0x14` | `SPI_RX` | read | bit7:0: 最後に SPI 受信した値 |
| `0x18` | `SPI_CONTROL` | write | bit0 に 1 を書くと SPI 転送開始 |
| `0x1C` | `SPI_STATUS` | read | bit0 BUSY, bit1 DONE, bit2 ERROR |
| `0x20` | `FIFO_WRITE` | write | 32bit ワードを入力FIFOへpush |
| `0x24` | `FIFO_READ` | read | 入力FIFOの先頭ワードをreadしてpop |
| `0x28` | `FIFO_STATUS` | read | bit0 EMPTY, bit1 FULL, bit2 OVERFLOW, bit3 UNDERFLOW, bit12:8 COUNT |
| `0x2C` | `FIFO_CONTROL` | write | bit0 CLEAR |
| `0x30` | `ACCEL_CONTROL` | write | bit0 START, bit1 CLEAR |
| `0x34` | `ACCEL_STATUS` | read | bit0 BUSY, bit1 DONE, bit2 ERROR |
| `0x38` | `VECTOR_LENGTH` | read/write | bit15:0 要素数、現在は 1〜16 |
| `0x3C` | `ACCEL_RESULT` | read | signed 32bit 積和結果 |
| `0x40` | `ACCEL_CYCLES` | read | FPGA内部の演算クロック数 |

読み出し成功時:

```text
OK 000000A5
```

書き込み成功時:

```text
OK
```

不正コマンドや不正アドレス:

```text
ERR
```

## LED と PWM

Tang Nano 9K の LED0 は Active Low です。
FPGA 内部では `LED` レジスタの bit0 を LED enable として扱い、`pwm_led.v` で Active Low の LED ピンに変換しています。

- `W 08 00000000`: LED を強制消灯
- `W 08 00000001`: LED を有効化
- `W 0C 00000000`: duty 0、消灯
- `W 0C 00000080`: duty 128、およそ半分の明るさ
- `W 0C 000000FF`: duty 255、ほぼ最大輝度

## SPI マスター

SPI は `src/spi_master.v` に実装しています。

- SPI Mode 0
- CPOL = 0
- CPHA = 0
- 8bit
- MSB first
- Chip Select は Active Low
- SCLK は約 500kHz

27MHz クロックを `CLK_DIV=27` で分周し、SCLK はおよそ `27MHz / (2 * 27) = 500kHz` です。

### SPI ループバック

ジャンパ線で `spi_mosi` と `spi_miso` を接続すると、送信値と受信値が一致することを確認できます。

配線時の注意:

- 必ず USB を抜いた状態で配線してください。
- `spi_mosi` と `spi_miso` だけを接続してください。
- 3.3V、5V、GND には接続しないでください。
- SPI ピンは FPGA pin 25〜28 の Bank 2 / LVCMOS33 に固定されています。

手動確認例:

```text
W 10 000000A5
W 18 00000001
R 1C
R 14
```

ループバック配線が正しければ、最後の読み出しで次のように返ります。

```text
OK 000000A5
```

Web 画面の `SPI Loopback Test` では、単発転送と自動テストを実行できます。
自動テストは `00`, `01`, `55`, `AA`, `A5`, `FF` を順番に転送し、TX と RX が一致した場合に `PASS` と表示します。

## FIFO と signed int8 MAC

`src/sync_fifo.v` は 32bit 幅、16ワード深さの単一クロック同期FIFOです。
`FIFO_WRITE` でpushし、`FIFO_READ` で先頭ワードを返してpopします。
`FIFO_STATUS` では empty/full、overflow/underflow、現在のcountを確認できます。

FIFOの1ワードには、signed int8 の入力値と重みを入れます。

```text
bit7:0    input_value  signed int8
bit15:8   weight_value signed int8
bit31:16  reserved, write 0
```

pack例:

```text
input = 1, weight = 5  -> 0x00000501
input = -1, weight = 2 -> 0x000002FF
```

`src/dot_product_accel.v` は1レーンの signed int8 積和アクセラレータです。
FIFOから1ワードずつ読み、以下を計算します。

```text
accumulator += signed(input_value) * signed(weight_value)
```

積は signed 16bit、累積は signed 32bit です。
`VECTOR_LENGTH` に要素数を書き、FIFOへ同じ数のワードを書いた後、`ACCEL_CONTROL` の START を1にします。
完了すると `ACCEL_STATUS` の DONE が立ち、`ACCEL_RESULT` から signed 32bit 結果を読み出せます。
`ACCEL_CYCLES` は FPGA 内部の演算クロック数で、UART転送時間やNode.js処理時間は含みません。

Python側の `run_dot_product(inputs, weights)` は同じ計算をPythonでも行い、FPGA結果と比較します。
Web画面の `AI Dot Product Accelerator` では、カンマ区切りで入力できます。

例:

```text
inputs  = 1, 2, 3, 4
weights = 5, 6, 7, 8
result  = 70
```

負数を含む例:

```text
inputs  = -1, 2, -3, 4
weights = 5, -6, 7, -8
result  = -70
```

現在は1レーンMACです。将来は複数レーン化して、同じ演算を並列に進める予定です。

## ビルド

PowerShell でリポジトリルートから実行します。

```powershell
.\scripts\build.ps1
```

`gw_sh.exe` が見つからない場合は、`GOWIN_HOME` を GOWIN EDA のインストール先に設定するか、GOWIN EDA の `IDE\bin` を `PATH` に追加してください。

## SRAM 書き込み

Flash 書き込みは禁止です。動作確認は SRAM Program のみを使います。

```powershell
.\scripts\scan.ps1
.\scripts\program_sram.ps1
```

`program_sram.ps1` は SRAM Program 用の手順です。Flash 書き込みではありません。

## PC アプリと Web 画面

Python ロガーと Node.js Web サーバーを起動します。

```powershell
.\scripts\start.ps1
```

個別に起動する場合:

```powershell
py pc_app\serial_logger.py --port COM4 --baud 115200
node scripts\count_log_server.mjs
```

COM ポート番号は環境に合わせて変更してください。
UART は Python ロガーだけが開き、Web サーバーは要求ファイル経由で Python ロガーへ操作を渡します。

## CSV 保存

受信した `COUNT: XXXXXXXX` は次の CSV に追記されます。

```text
pc_app/data/count_log.csv
```

CSV や一時要求ファイル、Python キャッシュは Git 管理対象にしません。
