#!/usr/bin/env python3
"""
Oedon Knock Client - Sends UDP knock to Portero.
Usage: python3 knock.py <server_ip> --secret <your_secret>
"""

import socket
import hmac
import hashlib
import time
import sys
import os
import argparse
from pathlib import Path


def _load_dotenv():
    for candidate in [Path.cwd() / ".env", Path(__file__).resolve().parent / ".env"]:
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


def knock(server_ip: str, port: int, secret: str):
    ts = str(int(time.time()))
    mac = hmac.new(secret.encode(), ts.encode(), hashlib.sha256).hexdigest()
    payload = f"{ts}:{mac}".encode()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(payload, (server_ip, port))
    sock.close()
    print(f"[OK] Knock sent to {server_ip}:{port}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Oedon Knock Client")
    parser.add_argument("ip", help="Server IP address")
    parser.add_argument("--secret", help="Oedon Portero Secret (Overrides .env)", default=os.environ.get("PORTERO_SECRET"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORTERO_UDP_PORT", "62201")), help="UDP Port")
    
    args = parser.parse_args()

    if not args.secret:
        print("[!] PORTERO_SECRET not provided. Use --secret or set it in .env")
        sys.exit(1)

    knock(args.ip, args.port, args.secret)
