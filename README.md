# Oedon PaaS

> **The Invisible PaaS Control Plane**

Oedon is a lightweight, terminal‑first, self‑hosted platform for deploying and managing containerized applications on modest hardware — a Raspberry Pi, a recycled PC, a cheap VPS.

It uses pure Nginx Alpine, Docker, and a custom CLI to deliver a secure, portable, and zero‑maintenance infrastructure stack. Everything runs from the terminal. No web dashboards, no configuration databases, no management layers that need updating.

The system follows the **KISS** principle: no code monoliths, only simple, optimized, and useful scripts and templates. The entire server state lives in one `.env` file and one `apps.list` — both plain text, both versionable.

> *The name Oedon comes from Bloodborne — a Great One that is formless and invisible, yet omnipresent. Oedon follows the same ideal: invisible in process lists, minimal resource consumption, maximum efficiency, and omnipresent protection for every deployed application.*

---

## Why Oedon Was Built

- **To replace heavy tools** like Nginx Proxy Manager and Netdata that require logins, add complexity, and hide errors behind GUIs.
- **To provide real infrastructure control** — you see exactly why a container failed by copying a log, not by clicking a "Health" button.
- **To eliminate hard‑coded values, monoliths, and unnecessary dependencies.**
- **To be portable** — clone the repository to any Linux server, run two commands, and have a fortified server with working HTTPS, SSH stealth, automatic backups, and self‑healing.
- **To keep the workflow inside the terminal**, where logs are grep-able, errors are copy-pasteable, and nothing needs a browser to fix.

---

## Architecture

### System overview

```mermaid
flowchart TB
 subgraph SecurityLayer["1. SECURITY LAYER - Stealth Mode"]
        Portero["Portero Digital<br>UDP 62201 - HMAC"]
        Firewall["UFW Firewall<br>Closed SSH Port"]
        SSH["Hardened SSH<br>Access Post-Knock"]
  end
 subgraph ManagementLayer["2. MANAGEMENT LAYER - Control Plane"]
        CLI["Oedon CLI<br>bin/oedon"]
        Watchdog["Watchdog Service<br>Status &amp; Telegram"]
        Fail2Ban["Fail2Ban<br>Log Analysis"]
  end
 subgraph ProxyLayer["3. PROXY LAYER - Universal Proxy"]
        Nginx["Oedon-Proxy<br>Nginx Alpine - HTTPS"]
  end
 subgraph AppLayer["4. APPLICATION LAYER - Workloads"]
    direction LR
        Wordpress["WordPress<br>+ MariaDB"]
        Static["Static Web<br>HTML/JS"]
        Python["Notary Service<br>Flask API"]
        Custom["Custom App<br>Oedon Add"]
  end
    Admin(["Administrator<br>SSH Terminal"]) -- "1. Knock UDP" --> Portero
    Portero -. "2. Open Port 60s" .-> Firewall
    Firewall -- "3. SSH Connect" --> SSH
    SSH -- "4. Commands" --> CLI
    CLI -- Generates Vhosts --> Nginx
    CLI -- Orchestrates --> AppLayer
    Internet(["Internet Users"]) -- HTTPS 443 --> Nginx
    Nginx -- Reverse Proxy --> Wordpress & Static & Python & Custom
    Watchdog -. Health Check .-> AppLayer
    Fail2Ban -. Jail Management .-> ProxyLayer

     Portero:::security
     Firewall:::security
     SSH:::security
     CLI:::core
     Watchdog:::monitor
     Fail2Ban:::monitor
     Nginx:::core
     Wordpress:::apps
     Static:::apps
     Python:::apps
     Custom:::apps
     Admin:::external
     Internet:::external
    classDef external fill:#f8f9fa,stroke:#333,stroke-width:2px,color:#000
    classDef security fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000
    classDef core fill:#fffde7,stroke:#fbc02d,stroke-width:2px,color:#000
    classDef apps fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#000
    classDef monitor fill:#f3e5f5,stroke:#7b1fa2,stroke-width:1px,color:#000,stroke-dasharray: 5 5
```

### Network topology

```mermaid
flowchart TB
    classDef internet fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#0f172a,rx:8,ry:8
    classDef host fill:#f8fafc,stroke:#94a3b8,stroke-width:2px,stroke-dasharray: 5 5,color:#0f172a
    classDef security fill:#fee2e2,stroke:#ef4444,stroke-width:2px,color:#991b1b,rx:8,ry:8
    classDef edge fill:#dcfce7,stroke:#22c55e,stroke-width:2px,color:#166534,rx:8,ry:8
    classDef app fill:#f3e8ff,stroke:#a855f7,stroke-width:2px,color:#581c87,rx:8,ry:8
    classDef db fill:#cffafe,stroke:#06b6d4,stroke-width:2px,color:#155e75
    classDef admin fill:#fef3c7,stroke:#d97706,stroke-width:2px,color:#92400e,rx:8,ry:8
    classDef monitor fill:#f1f5f9,stroke:#64748b,stroke-width:2px,color:#334155,rx:8,ry:8

    subgraph Internet ["🌐 Internet"]
        direction LR
        U(["👤 Public User"]):::internet
        A(["👨‍💻 Administrator"]):::internet
    end

    subgraph Host ["💻 Host — Ubuntu 24.04 LTS"]
        direction TB
        UFW{{"🛡️ UFW<br/>(Default Deny)"}}:::security

        subgraph Edge ["🌍 Exposure Plane"]
            NGINX["🟢 Nginx Reverse Proxy<br/>(nginx:alpine)"]:::edge
        end

        subgraph Apps ["⚙️ Application Plane (oedon-network)"]
            direction LR
            WP["📝 WordPress<br/>(php8.2-fpm)"]:::app
            PY["🐍 Python App<br/>(Flask + Gunicorn)"]:::app
            ST["📄 Static Site<br/>(nginx:alpine)"]:::app
            DB[("🗄️ MariaDB")]:::db
        end

        subgraph Admin ["🔐 Administrative Access Plane"]
            direction LR
            PORT["🚪 Portero Digital<br/>(UDP 62201)"]:::admin
            SSH["💻 SSHd<br/>(Port 2222)"]:::admin
        end

        subgraph SecOps ["📊 Logs & Active Security"]
            direction LR
            LOG["📂 Centralised Logs<br/>(/var/log/oedon)"]:::monitor
            F2B["🚫 Fail2Ban"]:::security
        end
    end

    U -- "80/443 (HTTP/S)" --> UFW
    UFW -- "Web traffic" --> NGINX

    NGINX ==> WP
    NGINX ==> PY
    NGINX ==> ST
    WP -. "TCP 3306" .-> DB

    A -. "1. UDP Knock" .-> UFW
    UFW -. "Redirects" .-> PORT
    PORT -- "2. Opens port 60s" --> SSH
    A == "3. SSH session" ==> SSH

    NGINX -. "Access logs" .-> LOG
    LOG -. "Read" .-> F2B
    F2B -. "Apply IP ban" .-> UFW
```

### Internal Docker network

```mermaid
flowchart LR
    classDef internet fill:#ffffff,stroke:#4a5568,stroke-width:2px,color:#2d3748,stroke-dasharray: 5 5;
    classDef proxy fill:#2b6cb0,stroke:#ffffff,stroke-width:2px,color:#ffffff,rx:8,ry:8;
    classDef app fill:#3182ce,stroke:#ffffff,stroke-width:2px,color:#ffffff,rx:8,ry:8;
    classDef db fill:#38a169,stroke:#ffffff,stroke-width:2px,color:#ffffff;

    IN((🌐 Internet)):::internet

    subgraph Host ["🖥️ Host Server"]
        N{{"🔀 Nginx (Reverse Proxy)<br/>Ports: 80 / 443"}}:::proxy
    end

    subgraph Net ["🐳 oedon-network (Internal Docker Bridge)"]
        direction TB

        subgraph Apps ["Application Services"]
            direction TB
            WP["🟦 WordPress<br/>Port: 9000"]:::app
            PY["🐍 Python App<br/>Port: 8000"]:::app
            ST["📄 oedon-static<br/>Port: 80"]:::app
        end

        DB[("🗄️ MariaDB<br/>Port: 3306")]:::db
    end

    IN ==>|External traffic| N

    N -->|FastCGI| WP
    N -->|HTTP| PY
    N -->|HTTP| ST

    WP -.->|TCP queries| DB

    style Host fill:#f7fafc,stroke:#cbd5e0,stroke-width:2px,rx:10,ry:10
    style Net fill:#ebf8ff,stroke:#63b3ed,stroke-width:2px,stroke-dasharray: 6 6,rx:10,ry:10
    style Apps fill:none,stroke:none
```

---

## Core Features

| Area | Feature | Implementation |
|------|---------|----------------|
| **CLI** | Single command to manage everything | `oedon` — installed globally in `/usr/local/bin` |
| **Registry** | Declarative app list | `apps.list` (`name \| port \| subdomain`) |
| **Nginx** | Template‑based, no hardcoded domains | `envsubst` + templates in `config/nginx/templates/` |
| **Deployment** | Automatic proxy config & container start | `oedon deploy` reads `apps.list`, generates configs, starts containers |
| **Rollback** | If `nginx -t` fails, previous config is restored | Implemented in `sync_apps.sh` |
| **SSL** | Local: `mkcert` — Production: Certbot container | `oedon deploy` detects `APP_ENV` and handles both |
| **Port Knocking** | Custom UDP HMAC‑SHA256 knock server | `internal/portero/portero.py` + systemd service |
| **Firewall** | UFW default deny — open: 80/tcp, 443/tcp, 62201/udp | `05-setup-firewall.sh` |
| **Fail2Ban** | Nginx jails for auth failures, bot scanning, bad agents | `06-setup-fail2ban.sh` |
| **Monitoring** | Terminal dashboard + MOTD on SSH login | `oedon-stats.sh`, `btop` |
| **Watchdog** | Disk, memory, container checks every 5 min + Telegram alerts | `oedon-watchdog.sh` + cron |
| **Backups** | Database dump + infrastructure archive → Telegram | `99-backup.sh` |
| **Notary** | Integrity verification and signing for deployments | Python‑Flask container with persistent JSON registry |
| **Logs** | Centralised real‑time streaming | `oedon monitor` |

---

## Security Model

| Layer | Mechanism |
|-------|-----------|
| **Firewall** | Default deny. Only HTTP(S) and Portero UDP are open to the public. |
| **SSH** | Port completely closed. Opened for 60 seconds only after a valid UDP knock. |
| **Port Knocking** | `portero.py` listens on UDP 62201. HMAC‑SHA256 signed timestamp — replay attacks impossible. |
| **Fail2Ban** | Bans IPs scanning for `.env`, `.git`, wp‑login, or using malicious user agents. |
| **Nginx** | `server_tokens off` — version hidden from headers. |
| **Docker** | All containers isolated on a user‑defined bridge (`oedon-network`). No container exposes ports to the host except the proxy. |
| **Secrets** | Auto‑generated with `generate-secrets.sh` — never committed. `.gitignore` excludes `.env`, SSL keys, and data. |

> **Why not fwknop?**
> Oedon implements its own lightweight SPA (Single Packet Authorization) using HMAC + timestamps. It's replay‑proof, leaves no log noise, requires no compilation, and runs as a plain Python systemd service with zero external dependencies.

### Portero Digital — knock sequence

```mermaid
%%{init: {'theme': 'neutral', 'sequence': {'showSequenceNumbers': true}}}%%
sequenceDiagram
    actor Cli as Client CLI<br/>(knock_client.py)

    box rgb(244, 246, 249) Oedon Server
        participant FW as Firewall<br/>(UFW)
        participant Por as Portero Digital<br/>(Daemon UDP:62201)
        participant SSH as SSH Service<br/>(sshd TCP:2222)
    end

    Note over Cli, Por: Phase 1: Knock transmission
    Cli->>+FW: UDP packet [ timestamp : HMAC ]
    FW->>+Por: Route traffic to UDP/62201

    Note over Por: Phase 2: Cryptographic validation
    Por->>Por: Validate time window (ts ± 30s)
    Por->>Por: Verify signature (hmac.compare_digest)

    alt Valid and authorised knock
        Note over Por, SSH: Phase 3: Dynamic opening and connection
        Por->>FW: ufw insert allow from <IP_Cli> to 2222/tcp
        Por-->>Cli: (Silent operation / No ACK)

        Cli->>+SSH: Connect: ssh -p 2222 user@host
        SSH-->>-Cli: SSH session established

        Note over Por: Window timer (60s)
        Por->>FW: ufw delete allow from <IP_Cli>
        Note over FW, SSH: Rule deleted. Port 2222 closed to new connections.<br/>Active sessions remain alive.

    else Invalid knock (replay attack or wrong signature)
        Por->>Por: Log event (WARN) and discard packet
        Note over Cli, FW: Port 2222 stays in DROP mode
        Cli-xFW: SSH connection attempt (blocked)
    end

    deactivate Por
    deactivate FW
```

---

## Quick Start

### 1 — Clone and install

```bash
git clone --depth=1 https://github.com/MohamedKamil-hub/Oedon
cd Oedon
sudo bash install.sh
```

`install.sh` does the following automatically:

- Creates `.env` from `.env.example`
- Installs Docker Engine, Fail2Ban, UFW, `mkcert`
- Registers the `oedon` CLI globally in `/usr/local/bin`
- Sets up the watchdog cron job (every 5 minutes)
- Configures Portero Digital as a systemd service
- Prepares log directories under `/var/log/oedon`

### 2 — Deploy

```bash
sudo oedon deploy
```

On first run, the preflight validator checks `.env` for any `CHANGE_ME` values and interactively asks for the ones that need human input (domain, email). Everything else is auto‑generated.

```
sudo bash install.sh     # creates .env template, installs deps
sudo oedon deploy         # preflight finds CHANGE_ME →
                          #   asks "Configure now? (Y/n)" →
                          #   DOMAIN: prompts user
                          #   secrets: auto-generated
                          #   defaults: applied silently
                          #   → deploys
```

After a successful deploy, your sites are live at:

```
https://static.<your-domain>
https://wordpress.<your-domain>
https://python.<your-domain>
```

### Deploy flow

```mermaid
flowchart TD
    classDef cmd fill:#1e1e1e,stroke:#4caf50,stroke-width:2px,color:#4caf50,font-family:monospace;
    classDef script fill:#1e3a8a,stroke:#3b82f6,stroke-width:2px,color:#ffffff,rx:5px,ry:5px;
    classDef decision fill:#9a3412,stroke:#f97316,stroke-width:2px,color:#ffffff;
    classDef success fill:#14532d,stroke:#22c55e,stroke-width:2px,color:#ffffff,rx:10px,ry:10px;
    classDef error fill:#7f1d1d,stroke:#ef4444,stroke-width:2px,color:#ffffff,rx:10px,ry:10px;
    classDef network fill:#374151,stroke:#9ca3af,stroke-width:2px,color:#ffffff,rx:5px,ry:5px;

    Start(["💻 sudo oedon deploy"]):::cmd --> Preflight

    subgraph Fase1 [Phase 1: Initialisation & Secrets]
        direction TB
        Preflight["⚙️ Preflight: Validate environment"]:::script
        Preflight --> HasPending{"Any CHANGE_ME values?"}:::decision

        HasPending -->|Yes| Provision["🔑 Auto-generate secrets"]:::script
        Provision --> Preflight2["🔄 Re-validate variables"]:::script
        Preflight2 --> EnvOK

        HasPending -->|No| EnvOK["✅ Environment validated"]:::success
    end

    EnvOK --> SSLCheck

    subgraph Fase2 [Phase 2: SSL Certificate Management]
        direction TB
        SSLCheck{"What environment type?"}:::decision
        SSLCheck -->|Local| MkCert["🔐 Generate local certs (mkcert)"]:::script
        SSLCheck -->|Production| Certbot["🌐 Obtain Let's Encrypt (Certbot)"]:::script
    end

    MkCert --> Network
    Certbot --> Network

    subgraph Fase3 [Phase 3: Base Infrastructure]
        direction TB
        Network["🕸️ Create internal Docker network (oedon-network)"]:::network
        Network --> CoreStack["🐳 Deploy base services (Proxy, DB, Static)"]:::script
    end

    CoreStack --> SyncApps

    subgraph Fase4 [Phase 4: App Orchestration]
        direction TB
        SyncApps["📋 Read apps.list"]:::script
        SyncApps --> ForEach("🔁 Loop: process each app"):::network

        ForEach --> GenConfig["📝 Generate Nginx vhost from template"]:::script
        GenConfig --> NginxTest{"nginx -t valid?"}:::decision

        NginxTest -->|Yes| StartApp["🚀 Deploy app (docker compose up -d)"]:::script
        StartApp -. Next app .-> ForEach

        NginxTest -->|No| Rollback["⏪ Restore previous config (rollback)"]:::error
    end

    Rollback --> Error(["❌ [ERROR] Deploy aborted"]):::error

    ForEach -->|All apps processed| NginxReload["🔄 Reload proxy"]:::script
    NginxReload --> Success(["🎉 [OK] Deploy complete"]):::success
```

---

## CLI Reference

### App management

```mermaid
flowchart LR
    classDef admin fill:#2c3e50,stroke:#ecf0f1,stroke-width:2px,color:#fff
    classDef cli fill:#2980b9,stroke:#3498db,stroke-width:2px,color:#fff,rx:10,ry:10
    classDef data fill:#d35400,stroke:#e67e22,stroke-width:2px,color:#fff
    classDef infra fill:#27ae60,stroke:#2ecc71,stroke-width:2px,color:#fff

    Admin(("Administrator")):::admin

    subgraph OedonCLI [Oedon CLI]
        UC1["Register app<br/>(add)"]:::cli
        UC2["Deploy stack<br/>(deploy)"]:::cli
        UC3["Remove app<br/>(remove)"]:::cli
        UC4["List apps<br/>(list)"]:::cli
        UC5["Health check<br/>(health)"]:::cli
    end

    subgraph Core [System & Configuration]
        AppsFile[("apps.list")]:::data
        NginxTemplates{{"Nginx Templates"}}:::data
        NginxConfig["Nginx Config"]:::infra
        DockerStack{{"Docker Compose"}}:::infra
    end

    Admin --> UC1
    Admin --> UC2
    Admin --> UC3
    Admin --> UC4
    Admin --> UC5

    UC1 -- registers --> AppsFile

    UC2 -- reads --> AppsFile
    UC2 -- processes --> NginxTemplates
    NginxTemplates -- generates --> NginxConfig
    UC2 -- starts --> DockerStack

    UC3 -- removes --> AppsFile
    UC3 -- deletes --> NginxConfig
    UC3 -- stops --> DockerStack

    UC4 -- queries --> AppsFile
    UC5 -- queries --> AppsFile
    UC5 -- verifies --> DockerStack
```

### Full command table

| Command | Description |
|---------|-------------|
| `oedon deploy` | Full deployment — sync registry, generate configs, start all apps |
| `oedon add <name> <port> <subdomain>` | Register a new app (`oedon add moodle 8080 lms`) |
| `oedon remove <name>` | Unregister, stop container, remove Nginx config |
| `oedon list` | Show all apps registered in `apps.list` |
| `oedon sync` | Regenerate Nginx configs from `apps.list` and reload (with rollback) |
| `oedon health` | HTTP health check for each registered app |
| `oedon status` | Docker container status via `docker compose ps` |
| `oedon logs <container>` | Follow logs of a specific container |
| `oedon monitor` | Stream all container logs + Nginx simultaneously |
| `oedon stats` | Terminal dashboard (CPU, RAM, disk, Docker, SSH failures, sites) |
| `oedon up / down / restart` | Control the core infrastructure stack |
| `oedon lockdown` | Enable stealth mode — close SSH port, start Portero, generate `knock_client.py` |
| `oedon secure` | Apply UFW firewall and Fail2Ban hardening |
| `oedon backup` | Dump database + compress infra → send to Telegram |
| `oedon watchdog-test` | Manually trigger the self‑healing watchdog check |
| `oedon janitor` | Clean Docker build cache, dangling images, and system logs |
| `oedon reset` | Stop all containers, remove generated configs, optionally wipe `.env` |
| `oedon rotate` | Interactive secret rotation wizard |
| `oedon certs` | SSL certificate management (mkcert local / Certbot production) |

---

## Adding a Custom App

Oedon can proxy any application that runs in Docker. The only requirements are that the container is attached to `oedon-network` and that its `container_name` matches the name you register.

### Example: Moodle

**Step 1 — Create the app directory**

```bash
mkdir -p apps/moodle
```

**Step 2 — Write a `docker-compose.yml`**

```yaml
# apps/moodle-app/docker-compose.yml
services:
  moodle-db:
    image: mariadb:10.11
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    environment:
      MYSQL_DATABASE: moodle
      MYSQL_USER: moodleuser
      MYSQL_PASSWORD: moodlepass
      MYSQL_ROOT_PASSWORD: rootpass
    networks:
      - oedon-network

  moodle:
    image: public.ecr.aws/bitnami/moodle:latest
    container_name: moodle          # Must match the name in `oedon add`
    depends_on:
      - moodle-db
    environment:
      MOODLE_DATABASE_HOST: moodle-db
      MOODLE_DATABASE_USER: moodleuser
      MOODLE_DATABASE_PASSWORD: moodlepass
      MOODLE_DATABASE_NAME: moodle
      MOODLE_REVERSE_PROXY: "yes"
    networks:
      - oedon-network

networks:
  oedon-network:
    external: true
```

**Step 3 — Register the app**

```bash
sudo oedon add moodle 8080 lms
# Adds: moodle | 8080 | lms  →  to apps.list
```

**Step 4 — Deploy**

```bash
sudo oedon deploy
# Generates: config/nginx/sites-enabled/moodle.conf
# Starts:    apps/moodle-app via docker compose up -d
# Reloads:   oedon-proxy
```

Your Moodle is now at `https://lms.<your-domain>`.

---

## Stealth SSH Access (Portero Digital)

Portero is Oedon's built‑in UDP port knocking daemon. It keeps your SSH port invisible to public scanners until a valid HMAC‑SHA256 signed packet is received.

### Activate

```bash
sudo oedon lockdown
```

This will:
- Start `oedon-portero.service` via systemd
- Open UDP port `62201` in UFW
- **Close** the SSH TCP port
- Generate a pre-configured `knock_client.py` with your secret embedded

### Connect

Copy `knock_client.py` to your local machine, then:

```bash
# Open the SSH port for your IP (60-second window)
python3 knock_client.py <server_ip>

# Connect normally
ssh -p 2222 user@<server_ip>
```

The knock payload is `timestamp:HMAC-SHA256(secret, timestamp)`. Any packet older than 30 seconds is rejected, making replay attacks impossible regardless of traffic interception.

---

## Monitoring & Maintenance

**On every SSH login**, your MOTD shows the live state of the server:

```
 HOST     myserver  │  Ubuntu 24.04  │  6.8.0-107-generic
 UPTIME   10 hours, 55 minutes  │  Load: 0.00 0.00 0.00
────────────────────────────────────────────────────────────
 CPU      Intel Core i7 (2 cores)
          ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░   5.3%
 MEMORY   721/3866 MB
          ██████░░░░░░░░░░░░░░░░░░░░░░░░  18.6%
────────────────────────────────────────────────────────────
 DOCKER   5 running / 5 total
 SSH      0 failed login attempts (last 24h)
 SITES
  🌐 https://static.myserver.local
  🌐 https://wordpress.myserver.local
  🌐 https://python.myserver.local
```

| Tool | What it does |
|------|-------------|
| `oedon stats` | Terminal dashboard: CPU, RAM, disk, Docker state, SSH failures, registered sites |
| `oedon monitor` | Real‑time multiplexed log stream from all containers + Nginx |
| `btop` | Interactive resource monitor (installed automatically) |
| **Watchdog** | Cron every 5 min — checks disk >85%, memory >90%, container state. Auto-restarts downed containers. Sends Telegram alert with 30‑min cooldown. |
| `oedon backup` | Dumps MariaDB, compresses the project (excluding logs/data), sends both to Telegram via `sendDocument`. |

> No web dashboards. Everything is in the terminal — errors are copy‑pasteable, logs are grep‑able, and there is nothing to update or reboot in the management layer.

---

## Integrity Verification (Notary Service)

The `python-app` container runs a small Flask service that acts as a deployment notary.

```
GET  /verify?app=<name>&hash=<hash>   →  VERIFIED | COMPROMISED | NOT_FOUND
POST /sign  (X-Oedon-Key: <key>)      →  registers a new hash for an app
```

Use it to verify that code running on the server hasn't been tampered with since the last authorised deployment. If a file was modified outside of a signed deploy, the next verification returns `COMPROMISED`.

---

## Declarative Configuration

All state is in plain text. These two files are the source of truth for your server:

**`.env`** — all variables, never committed:
```bash
DOMAIN=myserver.com
APP_ENV=production          # local | production
PORTERO_SECRET=<generated>
PORTERO_UDP_PORT=62201
PORTERO_WINDOW=60
PORTERO_TOLERANCE=30
MYSQL_ROOT_PASSWORD=<generated>
MYSQL_PASSWORD=<generated>
WATCHDOG_DISK_THRESHOLD=85
WATCHDOG_MEM_THRESHOLD=90
TELEGRAM_TOKEN=             # optional
TELEGRAM_CHAT_ID=           # optional
```

**`apps.list`** — your application registry:
```
# name             | internal port | subdomain
oedon-static       | 80            | static
wordpress          | 9000          | wordpress
python-app         | 5000          | python

# Uncomment to deploy:
# moodle           | 8080          | lms
# gitea            | 3000          | git
```

---

## Development Timeline

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#EAF2F8',
    'primaryTextColor': '#1B2631',
    'primaryBorderColor': '#5DADE2',
    'lineColor': '#D5D8DC',
    'taskBkgColor': '#2E86C1',
    'taskBorderColor': '#21618C',
    'taskTextColor': '#FFFFFF',
    'activeTaskBkgColor': '#D35400',
    'activeTaskBorderColor': '#A04000',
    'doneTaskBkgColor': '#1E8449',
    'doneTaskBorderColor': '#145A32',
    'fontFamily': 'sans-serif'
  },
  'gantt': {
    'titleTopMargin': 25,
    'barHeight': 24,
    'barGap': 6,
    'topPadding': 50,
    'leftPadding': 260,
    'gridLineStartPadding': 20,
    'fontSize': 13,
    'axisFormat': '%d/%m'
  }
}}%%
gantt
    title Development Plan — Oedon PaaS
    dateFormat  YYYY-MM-DD
    tickInterval 1week
    todayMarker stroke-width:3px,stroke:#E74C3C,opacity:0.8

    section 1. Anteproyecto
    Prototipo inicial y scripts        :done, t1, 2026-01-15, 2026-02-15
    Arquitectura del repositorio       :done, t2, 2026-02-16, 2026-02-21
    🎯 ENTREGA ANTEPROYECTO            :milestone, done, m1, 2026-02-22, 0d

    section 2. Parcial 50%
    CLI base & sync_apps               :done, t3, 2026-02-23, 2026-03-04
    UFW + Fail2Ban + jails Nginx       :done, t4, 2026-03-05, 2026-03-14
    🎯 ENTREGA PARCIAL 50%             :milestone, done, m2, 2026-03-15, 0d

    section 3. Parcial 85%
    Portero Digital (HMAC + systemd)   :done, t5, 2026-03-16, 2026-03-27
    generate-secrets & oedon rotate    :done, t6, 2026-03-28, 2026-04-04
    🎯 ENTREGA PARCIAL 85%             :milestone, done, m3, 2026-04-05, 0d

    section 4. Final 100%
    oedon-stats & MOTD dinámico        :done, t7, 2026-04-06, 2026-04-12
    Watchdog & alertas Telegram        :active, t8, 2026-04-10, 2026-04-18
    Backups & Notary Service           :t9, 2026-04-18, 2026-04-26
    CI/CD & Validación entorno         :t10, 2026-04-24, 2026-04-30
    Redacción de Memoria Final         :active, t11, 2026-04-01, 2026-05-02
    🚀 DEPÓSITO FINAL 100%             :milestone, m4, 2026-05-03, 0d
```

---

## Roadmap

```mermaid
flowchart TD
    classDef phase fill:#2C3E50,color:#ECF0F1,stroke:#34495E,stroke-width:2px,rx:5,ry:5,font-weight:bold,font-size:16px
    classDef task fill:#F8F9FA,color:#2C3E50,stroke:#BDC3C7,stroke-width:2px,rx:8,ry:8,text-align:left
    classDef title fill:#005B96,color:#FFFFFF,stroke:#03396C,stroke-width:2px,rx:10,ry:10,font-weight:bold,font-size:18px

    T{{"🚀 OEDON — EVOLUTION ROADMAP"}}:::title

    P1["Phase 1: Short Term (1 - 3 months)"]:::phase
    P2["Phase 2: Medium Term (3 - 9 months)"]:::phase
    P3["Phase 3: Long Term (9+ months)"]:::phase

    T1_1["<b>Automatic Certbot renewal</b><br/><i>Weekly cron + Telegram notification</i>"]:::task
    T1_2["<b>Kernel hardening (sysctl)</b><br/><i>oedon secure extended with kernel parameters</i>"]:::task
    T1_3["<b>Advanced log filtering</b><br/><i>oedon logs --tail N --grep PATTERN --all</i>"]:::task

    T2_1["<b>SSH Honeypot (Cowrie)</b><br/><i>Port 22 as decoy, Fail2Ban integration</i>"]:::task
    T2_2["<b>Stack auto-update</b><br/><i>oedon update to refresh Docker images safely</i>"]:::task
    T2_3["<b>Structured logs</b><br/><i>JSON logging + configurable retention</i>"]:::task

    T3_1["<b>Multi-node architecture</b><br/><i>Distributed roles: Gateway / Worker / Data</i>"]:::task
    T3_2["<b>Remote deployment</b><br/><i>oedon deploy --node &lt;name&gt;</i>"]:::task
    T3_3["<b>Optional TUI interface</b><br/><i>ncurses dashboard — no web dependencies</i>"]:::task

    T --> P1
    P1 --- T1_1 --- T1_2 --- T1_3

    T1_3 --> P2
    P2 --- T2_1 --- T2_2 --- T2_3

    T2_3 --> P3
    P3 --- T3_1 --- T3_2 --- T3_3
```

---

## Repository Structure

```
Oedon/
├── apps/                    # One directory per deployed application
│   ├── python-app/          # Notary service (Flask)
│   ├── static-web/          # Default static site
│   └── wordpress/           # WordPress + MariaDB
├── bin/
│   └── oedon                # Main CLI dispatcher
├── config/
│   ├── nginx/
│   │   ├── nginx.conf       # Base Nginx config
│   │   ├── sites-enabled/   # Generated vhosts (gitignored)
│   │   ├── ssl/             # SSL certificates (gitignored)
│   │   └── templates/       # envsubst templates per app type
│   ├── fail2ban/            # Custom jails and filters
│   └── ssh/                 # Hardened sshd_config + server key
├── internal/
│   └── portero/             # Portero Digital daemon + systemd service
├── scripts/                 # One script per responsibility
│   ├── deploy.sh
│   ├── sync_apps.sh         # Generates Nginx configs with rollback
│   ├── oedon-watchdog.sh    # Self-healing + Telegram alerts
│   ├── oedon-stats.sh       # Terminal dashboard
│   ├── generate-secrets.sh  # Secret provisioning and rotation
│   └── ...
├── tools/
│   └── knock/               # Knock client for local machines
├── apps.list                # Declarative application registry
├── docker-compose.yml       # Core infrastructure stack
├── .env.example             # Configuration template
└── install.sh               # Bootstrap installer
```

---

## License

MIT — © 2026 Mohamed Kamil.

Free to use, modify, and distribute. See `LICENSE` for details.

---

**Oedon is designed for systems administrators who want full control, maximum security, and a workflow that stays inside the terminal.**
Simple, optimized, and useful — exactly as intended.
