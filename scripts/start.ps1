Start-Process powershell -ArgumentList '-NoExit', '-Command', 'py pc_app\serial_logger.py'

Start-Sleep -Seconds 1

node scripts\count_log_server.mjs