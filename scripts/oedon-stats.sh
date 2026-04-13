#!/bin/bash
# oedon-stats.sh - Oedon Server Dashboard
# Author: Mohamed Kamil El Kouarti
export LC_NUMERIC=C
set -euo pipefail

# ── Colors ──────────────────────────────────────────────
R='\033[0;31m'   G='\033[0;32m'   Y='\033[1;33m'
B='\033[0;34m'   P='\033[0;35m'   C='\033[0;36m'
W='\033[1;37m'   DIM='\033[2m'    NC='\033[0m'

# ── Detect project root & load .env ─────────────────────
# Resolvemos la ruta real aunque estemos en un symlink (MOTD)
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"
DOMAIN="${DOMAIN:-oedon.test}"
SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"


# ── Helpers ─────────────────────────────────────────────
bar() {
    local pct=$1 width=30 fill empty color
    fill=$(printf "%.0f" "$(awk "BEGIN {printf \"%.0f\", $pct * $width / 100}")")
    empty=$((width - fill))
    if (( $(echo "$pct > 90" | bc -l) )); then color=$R
    elif (( $(echo "$pct > 70" | bc -l) )); then color=$Y
    else color=$G; fi
    printf "${color}%s${DIM}%s${NC} %5.1f%%" \
        "$(printf '█%.0s' $(seq 1 $fill 2>/dev/null) )" \
        "$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) )" \
        "$pct"
}

separator() {
    printf "${DIM}%.0s─${NC}" $(seq 1 60)
    echo
}

# ── System Info ─────────────────────────────────────────
. /etc/os-release 2>/dev/null || true
HOSTNAME=$(hostname)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //')
LOAD=$(awk '{print $1, $2, $3}' /proc/loadavg)
USERS=$(who 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ')
[ -z "$USERS" ] && USERS="(none)"

# ── CPU ─────────────────────────────────────────────────
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_CORES=$(nproc)
CPU_PCT=$(top -bn1 | awk '/%Cpu/ {for(i=1;i<=NF;i++) if($i~/id/) {gsub(",",".",$( i-1)); printf "%.1f", 100-$(i-1)}}')

# ── Memory ──────────────────────────────────────────────
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_USED=$(free -m  | awk 'NR==2{print $3}')
MEM_PCT=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/$MEM_TOTAL*100}")

# ── Swap ────────────────────────────────────────────────
SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
SWAP_USED=$(free -m  | awk 'NR==3{print $3}')
if [ "$SWAP_TOTAL" -gt 0 ] 2>/dev/null; then
    SWAP_PCT=$(awk "BEGIN {printf \"%.1f\", $SWAP_USED/$SWAP_TOTAL*100}")
else
    SWAP_PCT="0.0"
fi

# ── Disk ────────────────────────────────────────────────
DISK_TOTAL=$(LC_NUMERIC=C df -B1 / | awk 'NR==2{printf "%.1f", $2/1024/1024/1024}')
DISK_USED=$(LC_NUMERIC=C  df -B1 / | awk 'NR==2{printf "%.1f", $3/1024/1024/1024}')
DISK_FREE=$(LC_NUMERIC=C  df -B1 / | awk 'NR==2{printf "%.1f", $4/1024/1024/1024}')
DISK_PCT=$(df / | awk 'NR==2{gsub("%",""); print $5}')

# ── Network ─────────────────────────────────────────────
NET_IF=$(ip route | awk '/default/{print $5; exit}')
NET_IP=$(ip -4 addr show "$NET_IF" 2>/dev/null | awk '/inet /{print $2; exit}')
[ -z "$NET_IP" ] && NET_IP="N/A"

# ── Docker ──────────────────────────────────────────────
if command -v docker &>/dev/null && docker info &>/dev/null; then
    DOCKER_RUNNING=$(docker ps -q 2>/dev/null | wc -l)
    DOCKER_TOTAL=$(docker ps -aq 2>/dev/null | wc -l)
    DOCKER_PS=$(docker ps --format "  {{.Names}}|{{.Status}}|{{.Image}}" 2>/dev/null)
else
    DOCKER_RUNNING=0
    DOCKER_TOTAL=0
    DOCKER_PS=""
fi

# ── Failed Logins (auto-detect log) ────────────────────
FAILED_SSH="0"
for log in /var/log/auth.log /var/log/secure /var/log/messages; do
    if [ -f "$log" ]; then
        FAILED_SSH=$(grep -c "Failed password" "$log" 2>/dev/null || echo 0)
        break
    fi
done

# ── Top Processes ───────────────────────────────────────
TOP_CPU=$(ps aux --sort=-%cpu | awk 'NR>1 && NR<=4 {printf "  %-6s %5s%%  %s\n", $2, $3, $11}')
TOP_MEM=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=4 {printf "  %-6s %5s%%  %s\n", $2, $4, $11}')

# ── Output ──────────────────────────────────────────────
echo -e "${G}"
cat << 'LOGO'
  ██████╗ ███████╗██████╗  ██████╗ ███╗   ██╗
 ██╔═══██╗██╔════╝██╔══██╗██╔═══██╗████╗  ██║
 ██║   ██║█████╗  ██║  ██║██║   ██║██╔██╗ ██║
 ██║   ██║██╔══╝  ██║  ██║██║   ██║██║╚██╗██║
 ╚██████╔╝███████╗██████╔╝╚██████╔╝██║ ╚████║
  ╚═════╝ ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═══╝
LOGO
echo -e "${NC}"
echo -e "${DIM}   $(date '+%A %d %B %Y  %H:%M:%S')${NC}"
echo ""
echo -e "${W} HOST${NC}     ${HOSTNAME}  │  ${NAME:-?} ${VERSION_ID:-?}  │  ${KERNEL}"
echo -e "${W} UPTIME${NC}   ${UPTIME}  │  Load: ${LOAD}"
echo -e "${W} USERS${NC}    ${USERS} │  IP: ${NET_IP} (${NET_IF})"
separator
echo -e "${W} CPU${NC}      ${CPU_MODEL} (${CPU_CORES} cores)"
echo -e "          $(bar "$CPU_PCT")"
echo -e "${W} MEMORY${NC}   ${MEM_USED}/${MEM_TOTAL} MB"
echo -e "          $(bar "$MEM_PCT")"
echo -e "${W} SWAP${NC}     ${SWAP_USED}/${SWAP_TOTAL} MB"
echo -e "          $(bar "$SWAP_PCT")"
echo -e "${W} DISK${NC}     ${DISK_USED}/${DISK_TOTAL} GB (${DISK_FREE} GB free)"
echo -e "          $(bar "$DISK_PCT")"
separator
echo -e "${W} TOP CPU${NC}"
echo "$TOP_CPU"
echo ""
echo -e "${W} TOP MEM${NC}"
echo "$TOP_MEM"
separator
echo -e "${W} DOCKER${NC}   ${G}${DOCKER_RUNNING} running${NC} / ${DOCKER_TOTAL} total"

if [ -n "$DOCKER_PS" ]; then
    echo "$DOCKER_PS" | while IFS='|' read -r name status image; do
        if echo "$status" | grep -qi "up"; then
            echo -e "  ${G}●${NC} ${name}  ${DIM}${status}  ${image}${NC}"
        else
            echo -e "  ${R}●${NC} ${name}  ${DIM}${status}  ${image}${NC}"
        fi
    done
fi

separator
echo -e "${W} SSH${NC}      ${FAILED_SSH} failed login attempts (last 24h)"

APPS_FILE="${PROJECT_DIR}/apps.list"
if [ -f "$APPS_FILE" ]; then
    echo ""
    echo -e "${W} SITES${NC}"
    
    # Leemos el archivo línea por línea de forma nativa (sin tuberías)
    while IFS='|' read -r name port subdomain; do
        # 1. Limpiamos espacios usando tr
        name=$(echo "$name" | tr -d ' ' 2>/dev/null || true)
        subdomain=$(echo "$subdomain" | tr -d ' ' 2>/dev/null || true)
        
        # 2. Si la línea está vacía o es un comentario (#), pasamos a la siguiente
        if [[ -z "$name" ]] || [[ "$name" == \#* ]]; then
            continue
        fi
        
        # 3. Si hay subdominio, lo imprimimos
        if [[ -n "$subdomain" ]]; then
            echo -e "  ${G}🌐${NC} https://${subdomain}.${DOMAIN}"
        fi
    done < "$APPS_FILE"
fi


echo -e "
${DIM}  btop for interactive monitoring${NC}
"
