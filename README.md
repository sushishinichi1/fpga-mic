# Tang Nano 9K INMP441 Web Serial Monitor

Sipeed Tang Nano 9K で INMP441 の I2S マイク入力を受け取り、UART 115200bps で PC に送信する FPGA 学習用プロジェクトです。
現在の動作版では、ブラウザの Web Serial API を使ってリアルタイムに音量を確認できます。

Flash 書き込みは禁止です。動作確認では SRAM Program のみを使います。

## 現在できること

- INMP441 からの I2S 入力
- signed 24bit PCM の RAW サンプル取得
- 約100msごとの PEAK 計算
- PEAK を 0〜255 程度へ変換した VOL 表示
- UART 115200bps でのテキスト送信
- Web Serial によるブラウザ接続
- ブラウザ上でのリアルタイム音量バーと履歴グラフ表示

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `src/` | Verilog HDL ソース |
| `constraints/` | Tang Nano 9K のピン制約とタイミング制約 |
| `scripts/` | GOWIN EDA のビルドや SRAM 書き込み用スクリプト |
| `web/` | Web Serial 用のブラウザ画面 |
| `build/` | GOWIN EDA の生成物。Git 管理対象外 |

## ピン設定

現在の `constraints/tang_nano_9k.cst` で使っている主なピンは次のとおりです。

| 信号 | FPGA pin | 接続先 |
| --- | ---: | --- |
| `clk` | 52 | Tang Nano 9K 27MHz clock |
| `led0` | 10 | Tang Nano 9K LED0、Active Low |
| `uart_tx` | 17 | オンボード USB-UART bridge |
| `mic_sd` | 25 | INMP441 SD |
| `mic_ws` | 26 | INMP441 WS |
| `mic_sck` | 27 | INMP441 SCK |
| `mic_lr` | 28 | INMP441 L/R。FPGA から Low 出力 |

INMP441 の VDD は 3.3V、GND は GND へ接続します。
`mic_lr` を Low にしているため、INMP441 は左チャンネルとして動作します。

## UART 出力

FPGA は約100msごとに次の形式で1行送信します。

```text
RAW:-12345 PEAK:25750 VOL:6
```

| 項目 | 内容 |
| --- | --- |
| `RAW` | 最後に取得した signed 24bit PCM サンプル |
| `PEAK` | 直近約100ms区間の絶対値ピーク |
| `VOL` | Web 表示しやすいよう 0〜255 程度にスケールした値 |

## ビルド

PowerShell でリポジトリルートから実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1
```

`gw_sh.exe` が見つからない場合は、`GOWIN_HOME` を GOWIN EDA のインストール先に設定するか、GOWIN EDA の `IDE\bin` を `PATH` に追加してください。

ビルド生成物は `build/` に出力されます。

## SRAM 書き込み

Flash 書き込みは禁止です。実機確認は SRAM Program のみを使います。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\scan.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\program_sram.ps1
```

`program_sram.ps1` は SRAM Program 用です。自動では実行しません。

## Web Serial での確認

Chrome または Edge で次のファイルを開きます。

```text
web/index.html
```

画面の「接続」ボタンから Tang Nano 9K の COM ポートを選びます。
UART は 115200bps です。

ブラウザ画面では、現在の音量、RAW、PEAK、VOL、UART状態、Lines/sec、Last line を確認できます。

## 実機確認ポイント

- マイクに音を入れると LED0 が短く点灯すること
- Web 画面の VOL と履歴グラフが音量に合わせて動くこと
- Last line に `RAW:... PEAK:... VOL:...` 形式の行が表示されること
- Lines/sec が約10前後になること

## 注意

- `build/`、GOWIN生成ログ、CSV、一時ファイルは Git 管理対象にしません。
- ピン番号は推測で変更しないでください。
- 実機への書き込みは SRAM Program のみを使用してください。
