# Nebula Self-Hosted PaaS 🌌

**Self-hosted platform for deploying web applications on modest hardware**  
[![Status](https://img.shields.io/badge/Status-Stable-success)](https://github.com/MohamedKamil-hub/nebula-selfhosted-paas)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/MohamedKamil-hub/nebula-selfhosted-paas)

> A lightweight alternative to Heroku, Render, or Vercel — built for small teams, developers, and homelabs who want **full control** without recurring SaaS costs.

Nebula integrates a reverse proxy with automatic SSL, real‑time monitoring, and hardened security into a single Docker Compose stack. It runs smoothly on **2 vCPU / 4 GB RAM** and includes ready‑to‑deploy examples.

---

## Quick Start

### Prerequisites
- **Ubuntu 24.04 LTS** (fresh installation recommended)
- **Root or sudo access**
- **Minimum 20 GB disk**, **2 GB RAM** (4 GB+ recommended)
- **Ports 80/443 free** (run `02-check-ports.sh` to verify)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/MohamedKamil-hub/nebula-selfhosted-paas.git
cd nebula-selfhosted-paas

# 2. Make all scripts executable
chmod +x scripts/*

# 3. Install Docker and Docker Compose
./scripts/01-install-docker.sh

#IMPORTANT: Log out and log back in (or reboot) for Docker group changes.
#    After logging in again, verify with: docker ps

# 4. Check that ports 80 and 443 are free (optional but recommended)
./scripts/02-check-ports.sh

# 5. Create Docker network and copy SSL certificates (if you have them)
#    → Choose option 3 when prompted
./scripts/03-setup-nebula.sh

# 6. Start the core stack (Nginx Proxy Manager, Netdata, static demo)
./scripts/04-start-stack.sh

# 7. Configure the firewall (opens ports 2222,80,443,81,19999,10443)
./scripts/05-setup-firewall.sh

# 8. Enable Fail2Ban to protect SSH (port 2222) and Nginx
./scripts/06-setup-fail2ban.sh
```

Your Nebula platform is now **running**.  

Access the services using your **server's IP address** (from a browser on the same network):

| Service | URL | Default credentials |
|---------|-----|---------------------|
| Nginx Proxy Manager | `http://<YOUR_SERVER_IP>:81` | `admin@example.com` / `changeme` |
| Netdata Monitoring | `http://<YOUR_SERVER_IP>:19999` | (no login) |
| Static demo site | (configure via NPM) | – |

---

## Deploy Example Applications

### Static Web (already running internally)
- Container: `nebula-static`
- Internal endpoint: `http://nebula-static:80`
- **To expose it:** Add a Proxy Host in Nginx Proxy Manager pointing to `nebula-static:80`.

### Python App
```bash
cd apps/python-app
docker compose up -d
```
- Container: `python-app`
- Internal port: `5000`
- **To expose it:** Add a Proxy Host pointing to `python-app:5000`.

### WordPress
```bash
cd apps/wordpress-app
docker compose up -d
```
- This compose file includes **MySQL** and **WordPress**.
- Database credentials are defined in the compose file (override via `.env`).
- **To expose it:** Add a Proxy Host pointing to `wordpress:80`.

---

## SSL for Custom Domains (Example)

To test SSL with a local domain like `app.nebula.test`:

1. **Generate a self‑signed certificate** (on your Nebula server):
   ```bash
   mkdir -p ~/certs && cd ~/certs
   openssl req -x509 -newkey rsa:2048 -keyout app.nebula.test.key \
     -out app.nebula.test.crt -days 365 -nodes \
     -subj "/C=ES/ST=Madrid/L=Madrid/O=Nebula/CN=app.nebula.test" \
     -addext "subjectAltName=DNS:app.nebula.test"
   ```

2. **Upload the certificate to Nginx Proxy Manager**:
   - Open `http://<YOUR_SERVER_IP>:81`
   - Go to **SSL Certificates** → **Add SSL Certificate** → **Custom**
   - Name: `app.nebula.test`
   - Certificate: paste content of `app.nebula.test.crt`
   - Private Key: paste content of `app.nebula.test.key`
   - Save.

3. **Create a Proxy Host**:
   - **Domain Names**: `app.nebula.test`
   - **Scheme**: `http`
   - **Forward Hostname / Port**: e.g. `nebula-static` / `80`
   - **SSL** tab: select your certificate, enable **Force SSL**.

4. **On your client machine**, add this line to `C:\Windows\System32\drivers\etc\hosts` (Windows) or `/etc/hosts` (Linux/macOS):
   ```
   <YOUR_SERVER_IP> app.nebula.test
   ```
5. Visit `https://app.nebula.test` (accept the self‑signed warning).

---

##Task Automation

If you have [Task](https://taskfile.dev) installed, you can use the included `Taskfile.yaml`:

```bash
# List all available tasks
task

# Start/stop the stack
task up
task down

# View logs or container status
task logs
task status

# Backup your data
task backup

# Update from Git and redeploy
task update

# Quick security audit
task security-check

# Remove unused Docker data
task clean
```

---

## Project Structure

```
nebula-selfhosted-paas/
├── apps/                    # Example applications
│   ├── python-app/         # Flask app with Dockerfile
│   ├── static-web/         # Static HTML site (nginx:alpine)
│   └── wordpress-app/      # WordPress + MySQL compose
├── config/                 # Configuration templates
│   ├── fail2ban/
│   ├── netdata/
│   ├── nginx/
│   └── ssh/
├── docs/                   # Diagrams and documentation
├── scripts/               # Numbered installation scripts
│   ├── 01-install-docker.sh
│   ├── 02-check-ports.sh
│   ├── 03-setup-nebula.sh
│   ├── 04-start-stack.sh
│   ├── 05-setup-firewall.sh
│   ├── 06-setup-fail2ban.sh
│   ├── 99-backup.sh
│   └── 99-stats.sh
├── .env.example           # Environment variables template
├── docker-compose.yml     # Main stack (NPM, Netdata, static-web)
├── Taskfile.yaml          # Task automation
└── README.md              # This file
```

**Note:** Runtime data (`certs/`, `data/`, `logs/`, `apps/wordpress-app/mysql/`, `uploads/`, etc.) is **never committed** – your `.gitignore` keeps the repository clean.

---

## Service Endpoints

| Service          | Internal (Docker network) | Published host port |
|------------------|---------------------------|---------------------|
| Nginx Proxy Mgr  | `nebula-proxy:81`         | **81** (admin)      |
| Netdata          | `nebula-monitor:19999`    | **19999**           |
| Static Web       | `nebula-static:80`        | (internal only)     |
| Python App       | `python-app:5000`         | (internal only)     |
| WordPress        | `wordpress:80`            | (internal only)     |
| HTTPS (standard) | –                         | **443**             |
| HTTPS (alt)      | –                         | **10443**           |

All published ports are opened in the **UFW firewall** by `05-setup-firewall.sh`.  
SSH is available on port **2222** with rate limiting.

---

## Security Features

- **SSH** moved to port **2222** with **rate limiting** (UFW limit)
- **UFW** default deny, only essential ports open
- **Fail2Ban** active on SSH (2222) and Nginx
- Docker containers run with **least privilege** (read‑only root FS where possible)
- Automatic **Let's Encrypt** certificates via Nginx Proxy Manager (when using real domains)

---

## Monitoring with Netdata

Access the real‑time dashboard:

```
http://<YOUR_SERVER_IP>:19999
```

To connect your Nebula instance to Netdata Cloud (optional):

```bash
docker exec nebula-monitor cat /var/lib/netdata/netdata_random_session_id
```

Then follow the claim instructions in the [Netdata Cloud UI](https://app.netdata.cloud).

---

## Troubleshooting

### 1. Firefox cannot connect to `http://localhost:81`
**Cause:** Firefox snap sandboxing or IPv6.  
**Fix:**  
- Use `http://127.0.0.1:81` instead.  
- Or install Firefox from Mozilla PPA:  
  ```bash
  sudo snap remove firefox
  sudo add-apt-repository ppa:mozillateam/ppa
  sudo apt update && sudo apt install firefox
  ```

### 2. Docker permission denied
You forgot to log out after running `01-install-docker.sh`.  
**Fix:** Log out and back in, then verify with `docker ps`.

### 3. Port 80/443 already in use
Run `sudo ss -tlnp | grep ':80\|:443'` to find the conflicting service and stop it (e.g. `sudo systemctl stop apache2`).

### 4. Nebula proxy container exits immediately
Check logs: `docker compose logs nebula-proxy`.  
Common cause: port conflict or missing `nebula-network`.  
**Fix:** `docker network create nebula-network` and `docker compose up -d --force-recreate nebula-proxy`.

### 5. WordPress database connection error
Wait 30–60 seconds for MySQL to fully initialize, then restart WordPress:
```bash
docker compose restart wordpress
```

### 6. Low disk space
Your VM needs at least 20 GB. Clean up:
```bash
docker system prune -a -f --volumes
sudo journalctl --vacuum-size=200M
```

---

## License & Author

**MIT License** – see [LICENSE](LICENSE).  

**Author:** Mohamed Kamil El Kouarti Mechhidan  
*Student, 2º SMR PROMETEO by thePower*  
Project Tutor: Raúl  
 [GitHub Profile](https://github.com/MohamedKamil-hub)

---

- **Netdata** for lightweight, real-time monitoring
- **Docker** for containerization simplicity
- **Nginx Proxy Manager** for making SSL management painless
- **Let's Encrypt** for free SSL certificates
- The open‑source community for making self‑hosting accessible

---

<div align="center">
 **If Nebula helps you, please star the repository!**  
</div>


