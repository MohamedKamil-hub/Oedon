









use mkcert or a manual Internal CA.
Implementing the "Automatic Rollback" if nginx configuration fails to load. because right now everything depends on the .env and a``s.list



















# Oedon

Oedon is a lightweight, terminal-first, self-hosted platform for deploying and managing containerized applications. It uses pure Nginx (Alpine), Docker, and a custom CLI to deliver a secure, portable, and zero-maintenance infrastructure.

Everything runs from the terminal. There are no web dashboards, no databases for configuration, and no heavy management layers. The system follows the **KISS** principle: Keep It Simple, Stupid. No code monoliths. Only simple, optimized, and useful scripts and templates.
  

Oedon follows the same ideal:  
- Invisible in process lists (`top`, `htop`)  
- Minimal resource consumption  
- Maximum efficiency with pure Nginx  
- Omnipresent protection for every deployed application  

This is not another web-based PaaS. It was built by a systems administrator who does not like graphical interfaces, does not want to leave the terminal, and values insight over convenience. The terminal gives full visibility; web panels hide what is really happening.

## Why Oedon Was Built

- To replace heavy tools (Nginx Proxy Manager, Netdata) that require logins and add complexity.  
- To provide kernel-level hardening and Zero Trust security that cloud platforms like Heroku cannot guarantee.  
- To eliminate hard-coded values, monoliths, and unnecessary dependencies.  
- To create a complete folder that can be copied to any VPS, run `docker compose up`, and become a fortified server.  
- To keep the entire workflow inside the terminal where AI assistance is most effective.

## Core Features

- **CLI `oedon`** – Single command to manage everything  
- **Template-based Nginx** – Configurations generated with `envsubst` (no hard-coded domains or ports)  
- **Automated deployment** – From a `docker-compose.yml` template and Nginx config  
- **Local app registry** – `apps.json` tracks only your applications (`oedon list`, `oedon stats`)  
- **App scaffolding** – `oedon create` generates a new application following project conventions  
- **Real certificates** – Lightweight Certbot container for Let’s Encrypt  
- **Security hardening**  
  - Default-deny firewall  
  - Kernel parameters via sysctl (ICMP redirects, broadcast protection, etc.)  
  - SSH port changed and hidden  
  - Nginx version hidden (`server_tokens off;`)  
  - Single Packet Authorization (SPA) with fwknop (cryptographic, replay-proof replacement for simple port knocking)  
  - Fail2Ban with WordPress-specific jails  
- **Monitoring and alerting**  
  - `oedon-stats.sh` and `btop` (terminal-only)  
  - Custom MOTD showing container status, RAM, and blocked attacks  
  - `oedon-watchdog.sh` that checks disk usage, vital services, and security every few minutes  
- **Backups** – `99-backup.sh` creates tar.gz archives and sends them to Telegram via curl (free, phone-accessible)  
- **Telegram alerts** – Watchdog sends messages to a bot when problems are detected  
- **Integrity verification** – Integration with the included notary service (`/verify` and `/sign` endpoints)  
- **Centralized logs** – Simple terminal alias `oedon logs -f <app>` with Docker log rotation  

## Security Model

Oedon moves the firewall from a “development” state to a “fortress” state:

- Default deny policy  
- Only ports 80/tcp and 443/tcp are publicly open (plus 10443/tcp if required)  
- Management ports (Netdata, proxy panels) are closed or restricted to localhost/SSH tunnel  
- Docker containers run on an isolated `oedon-network`  
- Kernel hardening applied automatically  
- Fail2Ban updates firewall rules in real time  
- SPA (fwknop) makes SSH invisible until a cryptographically signed single packet is received  

| Feature                  | Traditional Port Knocking | fwknop (SPA) – Oedon Way          |
|--------------------------|---------------------------|------------------------------------|
| Security principle       | Obscurity                 | Cryptographic authentication       |
| Replay attack protection | None                      | AES + nonces + timestamps          |
| Log visibility           | Noisy                     | Complete silence                   |
| Professional grade       | Hobbyist                  | Zero Trust best practice           |

## Project Structure

```
.
├── apps/                  # Your applications (python-app, static-web, wordpress-app examples)
├── config/                # Nginx templates, firewall, Fail2Ban, SSH
├── data/                  # Persistent volumes (certbot, etc.)
├── docs/                  # Documentation and technical notes
├── examples/              # Ready-to-use examples
├── scripts/               # Numbered setup scripts and tools
├── .gitignore             # Excludes secrets, logs, data, and generated files
├── docker-compose.yml     # Main stack
├── install.sh             # One-command bootstrap
├── Taskfile.yaml          # Task runner (optional)
├── knock.py               # Legacy port knocking (fwknop is preferred)
└── oedon-*                # CLI and helper scripts
```

The `.gitignore` file is deliberately strict: it excludes all secrets, logs, persistent data, WordPress uploads, and generated Nginx configurations. The repository remains clean and safe to commit.

## Quick Start

1. Clone the repository  
2. Review and edit `.env` (never commit it)  
3. Run `./install.sh`  
4. Execute the numbered scripts in `scripts/` in order  
5. Use the `oedon` CLI to create and deploy applications  

Example deployment:
```bash
oedon deploy --name miapp --port 3000 --git https://github.com/user/repo
```

All configuration is portable. Copy the entire folder to a new VPS and the system works identically.

## CLI Commands

```bash
oedon apps:create <name> --domain example.com --image myimage
oedon apps:list
oedon logs <app>
oedon restart <app>
oedon stats
oedon deploy ...
```

## Monitoring and Maintenance

- `oedon stats` – Terminal dashboard  
- `btop` – Visually rich resource monitor  
- MOTD – Shows container status and security events on every SSH login  
- Watchdog + Telegram – Automatic alerts for disk, services, and security issues  
- Backups – Sent directly to your Telegram chat  

No web interfaces to update. No management databases that can corrupt. Once configured, the system runs with zero maintenance.

## License

This project is licensed under the terms included in the `LICENSE` file.

---

Oedon is designed for systems administrators who want full control, maximum security, and a workflow that stays inside the terminal. Simple, optimized, and useful — exactly as intended.

