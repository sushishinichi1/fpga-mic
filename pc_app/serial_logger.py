from __future__ import annotations

import argparse
import csv
import queue
import re
import threading
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import serial
from serial import SerialException


COUNT_PATTERN = re.compile(r"^COUNT: ([0-9A-Fa-f]{8})$")
APP_DIR = Path(__file__).resolve().parent
DEFAULT_CSV_PATH = APP_DIR / "data" / "count_log.csv"
RESET_REQUEST_DIR = APP_DIR / "data" / "reset_requests"
REGISTER_COMMAND_TIMEOUT_SECONDS = 2.0

_active_command_queue: queue.Queue["SerialCommand"] | None = None


@dataclass(frozen=True)
class CountRecord:
    timestamp: str
    count_hex: str
    count_decimal: int


@dataclass
class SerialCommand:
    command: bytes
    response_queue: queue.Queue[str | BaseException] | None = None
    deadline: float = 0.0


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


def format_register_read(address: int) -> bytes:
    return f"R {address & 0xff:02X}\n".encode("ascii")


def format_register_write(address: int, value: int) -> bytes:
    return f"W {address & 0xff:02X} {value & 0xffffffff:08X}\n".encode("ascii")


def read_register(address: int) -> int:
    response = send_register_command(format_register_read(address))
    match = re.fullmatch(r"OK ([0-9A-Fa-f]{8})", response)
    if match is None:
        raise RuntimeError(f"unexpected register read response: {response}")
    return int(match.group(1), 16)


def write_register(address: int, value: int) -> None:
    response = send_register_command(format_register_write(address, value))
    if response != "OK":
        raise RuntimeError(f"unexpected register write response: {response}")


def send_register_command(command: bytes) -> str:
    if _active_command_queue is None:
        raise RuntimeError("serial logger is not connected")

    response_queue: queue.Queue[str | BaseException] = queue.Queue(maxsize=1)
    _active_command_queue.put(
        SerialCommand(command=command, response_queue=response_queue)
    )

    try:
        response = response_queue.get(timeout=REGISTER_COMMAND_TIMEOUT_SECONDS)
    except queue.Empty as exc:
        raise TimeoutError("timed out waiting for serial logger command handling") from exc

    if isinstance(response, BaseException):
        raise response
    return response


def parse_request_command(command: str) -> bytes | None:
    normalized = command.strip()
    if normalized == "r":
        return format_register_write(0x04, 1)
    if re.fullmatch(r"R [0-9A-Fa-f]{2}", normalized):
        return f"{normalized}\n".encode("ascii")
    if re.fullmatch(r"W [0-9A-Fa-f]{2} [0-9A-Fa-f]{8}", normalized):
        return f"{normalized}\n".encode("ascii")
    return None


def enqueue_reset_request_files(command_queue: queue.Queue[SerialCommand]) -> None:
    RESET_REQUEST_DIR.mkdir(parents=True, exist_ok=True)

    for request_path in sorted(RESET_REQUEST_DIR.glob("*.reset")):
        try:
            command = request_path.read_text(encoding="utf-8").strip()
            request_path.unlink()
        except OSError as exc:
            print(f"WARNING: cannot read reset request {request_path}: {exc}", flush=True)
            continue

        parsed_command = parse_request_command(command)
        if parsed_command is not None:
            command_queue.put(SerialCommand(command=parsed_command))
        else:
            print(f"WARNING: ignored invalid reset request: {request_path}", flush=True)


def start_console_input_thread(command_queue: queue.Queue[SerialCommand]) -> threading.Thread:
    def read_console() -> None:
        while True:
            try:
                line = input()
            except EOFError:
                return

            if line == "r":
                command_queue.put(SerialCommand(command=format_register_write(0x04, 1)))

    thread = threading.Thread(target=read_console, daemon=True)
    thread.start()
    return thread


def start_next_command(
    uart: serial.Serial,
    command_queue: queue.Queue[SerialCommand],
    pending_command: SerialCommand | None,
) -> SerialCommand | None:
    if pending_command is not None:
        return pending_command

    try:
        command = command_queue.get_nowait()
    except queue.Empty:
        return None

    uart.write(command.command)
    uart.flush()
    command.deadline = datetime.now().timestamp() + REGISTER_COMMAND_TIMEOUT_SECONDS
    print(f"Sent UART command: {command.command.decode('ascii').strip()}", flush=True)
    return command


def complete_pending_command(
    pending_command: SerialCommand | None,
    response: str,
) -> SerialCommand | None:
    if pending_command is None:
        return None

    if response == "OK" or response == "ERR" or response.startswith("OK "):
        if pending_command.response_queue is not None:
            pending_command.response_queue.put(response)
        if response == "ERR":
            print("WARNING: FPGA rejected UART command: ERR", flush=True)
        return None

    return pending_command


def expire_pending_command(pending_command: SerialCommand | None) -> SerialCommand | None:
    if pending_command is None:
        return None

    if datetime.now().timestamp() <= pending_command.deadline:
        return pending_command

    timeout_error = TimeoutError("timed out waiting for FPGA register response")
    if pending_command.response_queue is not None:
        pending_command.response_queue.put(timeout_error)
    print(f"WARNING: {timeout_error}", flush=True)
    return None


def run_logger(port: str, baud: int, csv_path: Path) -> None:
    prepare_csv(csv_path)
    print(f"Opening UART: port={port}, baud={baud}, format=8N1", flush=True)
    print(f"CSV output: {csv_path}", flush=True)
    print("Type r then Enter to reset the FPGA counter. Press Ctrl+C to stop.", flush=True)

    global _active_command_queue
    command_queue: queue.Queue[SerialCommand] = queue.Queue()
    _active_command_queue = command_queue
    start_console_input_thread(command_queue)

    while True:
        try:
            run_connected_logger(port, baud, csv_path, command_queue)
        except SerialException as exc:
            print(f"WARNING: serial port unavailable on {port}: {exc}", flush=True)
        except OSError as exc:
            print(f"WARNING: serial port error on {port}: {exc}", flush=True)

        print("Retrying UART connection in 2 seconds...", flush=True)
        time.sleep(2)


def run_connected_logger(
    port: str,
    baud: int,
    csv_path: Path,
    command_queue: queue.Queue[SerialCommand],
) -> None:
    with serial.Serial(
        port=port,
        baudrate=baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1,
    ) as uart:
        pending_command: SerialCommand | None = None
        print("UART connected. Waiting for COUNT lines...", flush=True)
        while True:
            enqueue_reset_request_files(command_queue)
            pending_command = expire_pending_command(pending_command)
            pending_command = start_next_command(uart, command_queue, pending_command)

            raw_bytes = uart.readline()
            enqueue_reset_request_files(command_queue)
            pending_command = start_next_command(uart, command_queue, pending_command)

            if not raw_bytes:
                continue

            line = raw_bytes.decode("ascii", errors="replace").strip()
            completed_command = complete_pending_command(pending_command, line)
            if completed_command is None and pending_command is not None:
                pending_command = None
                continue
            pending_command = completed_command

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
        print(f"ERROR: cannot open, read, or write {args.port}: {exc}", flush=True)
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
