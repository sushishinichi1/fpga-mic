# Windows 用 UART 受信ロガー

Tang Nano 9K から UART で送られる `COUNT: XXXXXXXX` の行を Python で受信し、受信時刻とカウント値を画面に表示しながら CSV へ追記します。

FPGA 側のコード、ピン設定、ビルドスクリプトは変更しません。Flash 書き込み処理も含みません。

## 受信仕様

- COM ポート: `COM4`
- baud rate: `115200`
- data bits: `8`
- parity: `none`
- stop bits: `1`
- 受信形式: `COUNT: 00000001`
- 数値部分: 8桁の16進数

## 依存関係のインストール

リポジトリのルートで PowerShell を開き、次を実行します。

```powershell
py -m pip install -r pc_app/requirements.txt
```

この環境で `py` ランチャーが使えない場合は、次のように `python` を使います。

```powershell
python -m pip install -r pc_app/requirements.txt
```

## 起動方法

初期設定の COM4 / 115200bps で起動する場合:

```powershell
py pc_app/serial_logger.py --port COM4 --baud 115200
```

COM ポートが違う場合:

```powershell
py pc_app/serial_logger.py --port COM5 --baud 115200
```

## CSV の保存場所

受信結果は次のファイルへ追記されます。

```text
pc_app/data/count_log.csv
```

Next.js のWebアプリは `data/count_log.csv` を読み込みます。Webで見たい場合は、PythonロガーのCSVを `data/count_log.csv` にコピーするか、ロガーの `--csv` オプションで保存先を指定してください。

```powershell
py pc_app/serial_logger.py --port COM4 --baud 115200 --csv data/count_log.csv
```

CSV のヘッダーは次の3列です。

```text
timestamp,count_hex,count_decimal
```

## 画面表示

正常に受信すると、PowerShell に次のように表示されます。

```text
2026-07-26T11:30:00  hex=00000001  decimal=1
```

`COUNT: XXXXXXXX` に合わない行は CSV に保存せず、警告だけを表示して受信を続けます。

## 注意

UART ターミナルなど別のアプリが COM4 を開いていると、このプログラムは同じ COM ポートを開けません。その場合は UART ターミナルを閉じてから再実行してください。

終了するときは PowerShell で `Ctrl+C` を押します。
