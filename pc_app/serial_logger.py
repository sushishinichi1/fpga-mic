from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import serial
from serial import SerialException


COUNT_PATTERN = re.compile(r"^COUNT: ([0-9A-Fa-f]{8})$")
APP_DIR = Path(__file__).resolve().parent
DEFAULT_CSV_PATH = APP_DIR / "data" / "count_log.csv"


@dataclass(frozen=True)
class CountRecord:
    timestamp: str
    count_hex: str
    count_decimal: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Receive Tang Nano 9K COUNT lines from UART and append them to CSV."
    )
    parser.add_argument(
        "--port",
        default="COM4",
        help="Serial port name. Default: COM4",
    )
    parser.add_argument(
        "--baud",
        type=positive_int,
        default=115200,
        help="Serial baud rate. Default: 115200",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help=f"CSV output path. Default: {DEFAULT_CSV_PATH}",
    )
    return parser.parse_args()


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return parsed


def parse_count_line(line: str) -> CountRecord | None:
    match = COUNT_PATTERN.match(line)
    if match is None:
        return None

    count_hex = match.group(1).upper()
    return CountRecord(
        timestamp=datetime.now().isoformat(timespec="seconds"),
        count_hex=count_hex,
        count_decimal=int(count_hex, 16),
    )


def prepare_csv(csv_path: Path) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    if csv_path.exists() and csv_path.stat().st_size > 0:
        return

    with csv_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["timestamp", "count_hex", "count_decimal"])


def append_record(csv_path: Path, record: CountRecord) -> None:
    with csv_path.open("a", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow([record.timestamp, record.count_hex, record.count_decimal])


def run_logger(port: str, baud: int, csv_path: Path) -> None:
    prepare_csv(csv_path)
    print(f"Opening UART: port={port}, baud={baud}, format=8N1", flush=True)
    print(f"CSV output: {csv_path}", flush=True)
    print("Press Ctrl+C to stop.", flush=True)

    with serial.Serial(
        port=port,
        baudrate=baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1,
    ) as uart:
        print("UART connected. Waiting for COUNT lines...", flush=True)
        while True:
            raw_bytes = uart.readline()
            if not raw_bytes:
                continue

            line = raw_bytes.decode("ascii", errors="replace").strip()
            record = parse_count_line(line)
            if record is None:
                print(f"WARNING: ignored invalid line: {line!r}", flush=True)
                continue

            append_record(csv_path, record)
            print(
                f"{record.timestamp}  hex={record.count_hex}  "
                f"decimal={record.count_decimal}",
                flush=True,
            )


def main() -> int:
    args = parse_args()

    try:
        run_logger(args.port, args.baud, args.csv)
    except KeyboardInterrupt:
        print("\nStopped by Ctrl+C.", flush=True)
        return 0
    except SerialException as exc:
        print(f"ERROR: cannot open or read {args.port}: {exc}", flush=True)
        print(
            "Check the COM port number and close any UART terminal using the same port.",
            flush=True,
        )
        return 1
    except OSError as exc:
        print(f"ERROR: serial port error on {args.port}: {exc}", flush=True)
        print(
            "Check that the board is connected and the COM port is available.",
            flush=True,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
