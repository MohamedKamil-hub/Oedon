#!/bin/bash
# oedon-stats.sh - Oedon Server Dashboard
# Author: Mohamed Kamil El Kouarti
# Replaces: netdata container + 99-stats.sh

set -euo pipefail

# ── Colors ──────────────────────────────────────────────
R='\033[0;31m'   G='\033[0;32m'   Y='\033[1;33m'
B='\033[0;34m'   P='\033[0;35m'   C='\033[0;36m'
W='\033[1;37m'   DIM='\033[2m'    NC='\033[0m'

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

# ── Failed Logins ───────────────────────────────────────
FAILED_SSH=""
for log in /var/log/auth.log /var/log/secure; do
    [ -f "$log" ] && FAILED_SSH=$(grep -c "Failed password" "$log" 2>/dev/null || echo 0) && break
done
[ -z "$FAILED_SSH" ] && FAILED_SSH=$(journalctl -u sshd --since "24 hours ago" 2>/dev/null | grep -c "Failed password" || echo 0)

# ── Top Processes ───────────────────────────────────────
TOP_CPU=$(ps aux --sort=-%cpu | awk 'NR>1 && NR<=4 {printf "  %-6s %5s%%  %s\n", $2, $3, $11}')
TOP_MEM=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=4 {printf "  %-6s %5s%%  %s\n", $2, $4, $11}')

# ── Output ──────────────────────────────────────────────
echo -e "
${C}   ╔═══════════════════════════════════════════════════════╗${NC}
${C}   ║${W}           ⚙  OEDON SERVER DASHBOARD  ⚙              ${C}║${NC}
${C}   ╚═══════════════════════════════════════════════════════╝${NC}
${DIM}   $(date '+%A %d %B %Y  %H:%M:%S')${NC}

${W} HOST${NC}     ${HOSTNAME}  │  ${NAME:-?} ${VERSION_ID:-?}  │  ${KERNEL}
${W} UPTIME${NC}   ${UPTIME}  │  Load: ${LOAD}
${W} USERS${NC}    ${USERS} │  IP: ${NET_IP} (${NET_IF})
$(separator)
${W} CPU${NC}      ${CPU_MODEL} (${CPU_CORES} cores)
          $(bar "$CPU_PCT")
${W} MEMORY${NC}   ${MEM_USED}/${MEM_TOTAL} MB
          $(bar "$MEM_PCT")
${W} SWAP${NC}     ${SWAP_USED}/${SWAP_TOTAL} MB
          $(bar "$SWAP_PCT")
${W} DISK ${NC}    ${DISK_USED}/${DISK_TOTAL} GB (${DISK_FREE} GB free)
          $(bar "$DISK_PCT")
$(separator)
${W} TOP CPU${NC}
${TOP_CPU}

${W} TOP MEM${NC}
${TOP_MEM}
$(separator)
${W} DOCKER${NC}   ${G}${DOCKER_RUNNING} running${NC} / ${DOCKER_TOTAL} total"

if [ -n "$DOCKER_PS" ]; then
    echo "$DOCKER_PS" | while IFS='|' read -r name status image; do
        if echo "$status" | grep -qi "up"; then
            echo -e "  ${G}●${NC} ${name}  ${DIM}${status}  ${image}${NC}"
        else
            echo -e "  ${R}●${NC} ${name}  ${DIM}${status}  ${image}${NC}"
        fi
    done
fi

echo -e "$(separator)
${W} SSH${NC}      ${FAILED_SSH} failed login attempts (last 24h)
${DIM}          btop for interactive monitoring${NC}
"
