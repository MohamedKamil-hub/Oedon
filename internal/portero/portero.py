#!/usr/bin/env python3
"""
Oedon Portero Digital - UDP Port Knock Server
Listens on UDP, validates HMAC-SHA256 + timestamp.
If valid, opens SSH port for the source IP for N seconds.

Config via env vars or .env file:
  PORTERO_SECRET        (required) HMAC shared key
  PORTERO_UDP_PORT      (default: 62201)
  SSH_PORT              (default: 2222)
  PORTERO_WINDOW        (default: 60)
  PORTERO_TOLERANCE     (default: 30)
"""

import socket
import hmac
import hashlib
import time
import subprocess
import threading
import logging
import sys
import os
from pathlib import Path


def _load_dotenv():
    """Source .env into os.environ (only keys not already set)."""
    for candidate in [
        Path("/opt/oedon-portero/.env"),
        Path(__file__).resolve().parent / ".env",
        Path.home() / "Oedon" / ".env",
    ]:
        if candidate.is_file():
            with open(candidate) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            return

_load_dotenv()


def _require_env(key: str) -> str:
    val = os.environ.get(key)
    if not val:
        print(f"[FATAL] {key} not set in environment or .env", file=sys.stderr)
        sys.exit(1)
    return val


SECRET_KEY      = _require_env("PORTERO_SECRET").encode()
LISTEN_PORT     = int(os.environ.get("PORTERO_UDP_PORT", "62201"))
SSH_PORT        = int(os.environ.get("SSH_PORT", "2222"))
WINDOW_SECONDS  = int(os.environ.get("PORTERO_WINDOW", "60"))
TIMESTAMP_TOLERANCE = int(os.environ.get("PORTERO_TOLERANCE", "30"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [PORTERO] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)


def verify_knock(data: bytes) -> bool:
    try:
        parts = data.decode().strip().split(":")
        if len(parts) != 2:
            return False
        ts_str, received_mac = parts
        ts = int(ts_str)
        if abs(time.time() - ts) > TIMESTAMP_TOLERANCE:
            logging.warning("Timestamp out of range: %d", ts)
            return False
        expected_mac = hmac.new(SECRET_KEY, ts_str.encode(), hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected_mac, received_mac)
    except Exception as e:
        logging.warning("Error verifying knock: %s", e)
        return False


def open_port(ip: str):
    try:
        cmd_open = ["ufw", "insert", "1", "allow", "from", ip, "to", "any", "port", str(SSH_PORT), "proto", "tcp"]
        subprocess.run(cmd_open, check=True, capture_output=True)
        logging.info("OPENED port %d for %s (%ds)", SSH_PORT, ip, WINDOW_SECONDS)

        time.sleep(WINDOW_SECONDS)

        cmd_close = ["ufw", "delete", "allow", "from", ip, "to", "any", "port", str(SSH_PORT), "proto", "tcp"]
        subprocess.run(cmd_close, check=True, capture_output=True)
        logging.info("CLOSED port %d for %s", SSH_PORT, ip)
    except subprocess.CalledProcessError as e:
        logging.error("UFW Error: %s", e.stderr.decode().strip())


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", LISTEN_PORT))
    logging.info("Portero listening on UDP %d", LISTEN_PORT)
    logging.info("SSH port: %d | Window: %ds | Tolerance: %ds", SSH_PORT, WINDOW_SECONDS, TIMESTAMP_TOLERANCE)

    active_ips = set()

    while True:
        data, addr = sock.recvfrom(256)
        ip = addr[0]
        logging.info("Knock received from %s", ip)

        if verify_knock(data):
            if ip not in active_ips:
                active_ips.add(ip)
                def handle(client_ip):
                    open_port(client_ip)
                    active_ips.discard(client_ip)
                threading.Thread(target=handle, args=(ip,), daemon=True).start()
            else:
                logging.info("IP %s already has open port, ignoring", ip)
        else:
            logging.warning("INVALID knock from %s", ip)


if __name__ == "__main__":
    main()
