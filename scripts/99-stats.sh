#!/bin/bash
# server-stats.sh
# Author: Mohamed Kamil El Kouarti
# Last update: Thu Sep 25 2025

# Will call later in the os name and version part
. /etc/os-release

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# memory USED
used=$(free -m | awk 'NR==2 { print $3 }')

#memory total
total=$(free -m | awk 'NR==2 { print $2 }')

# memory (FREE) MB
free_mem=$(free -m | awk 'NR==2 {print $4}')

#DISK USAGE

#FREE
free_disk=$(LC_NUMERIC=C df -B1 / | awk 'NR==2 {printf "%.2f", $4/1024/1024/1024}')
used_disk=$(LC_NUMERIC=C df -B1 / | awk 'NR==2 {printf "%.2f", $3/1024/1024/1024}')
percentage=$(df -h / | awk 'NR==2 {print $5}')
total_disk=$(LC_NUMERIC=C df -B1 / | awk 'NR==2 {printf "%.2f", $2/1024/1024/1024}')

#TOTAL CPU USAGE 
total_cpu=$(top -b -n1 | awk '/%Cpu/ {for(i=1;i<=NF;i++) if($i=="id,") {printf "%.2f", 100 - $(i-1)}}')

top_5_cpu=$(ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {print $2, $3, $11}')

top_5_mem=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {print $2, $4, $11}')  

##os name and version
if [ -f /etc/os-release ]; then
    os_name="$NAME"
    os_version="$VERSION"
else
    os_name="Unknown"
    os_version="Unknown"
fi

uptime=$(uptime -p)

users=$(who | awk '{print $1}' | sort -u | tr '\n' ' ')  # Get unique users

load_average=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')  

log_files="/var/log/secure /var/log/auth.log /var/log/messages /var/log/syslog"

failed_logs_j=$(
for log in $log_files; do
    [ -f "$log" ] && grep -i "pam_unix.*fail" "$log" 2>/dev/null | head -5
done
)



memory_usage=$(awk "BEGIN {printf \"%.2f\", $used / $total * 100}")


#Docker 
docker=$(docker ps  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
dockerstats=$(docker stats --format table --no-stream)

echo -e "$(cat <<EOF
${CYAN}=== Server Performance Stats ===${NC}
${BLUE}Last update: $(date)${NC}

${YELLOW}=== CPU Usage ===${NC}
Total CPU Usage: $total_cpu %

${YELLOW}=== Memory Usage ===${NC}
Total Memory: $total MB
Used Memory: $used MB  
Free Memory: $free_mem MB
Memory Usage: $memory_usage %

${YELLOW}=== Disk Usage ===${NC}
Total Disk: $total_disk GB
Used Disk: $used_disk GB
Free Disk: $free_disk GB
Disk Usage: $percentage %

${YELLOW}=== Top 5 Processes by CPU Usage ===${NC}
$top_5_cpu

${YELLOW}=== Top 5 Processes by Memory Usage ===${NC}
$top_5_mem

${BLUE}=== Docker processes ===${NC}
$docker

${BLUE}=== Docker containers ===${NC}
$dockerstats

${YELLOW}=== Additional System Information ===${NC}
OS : $os_name $os_version
Uptime: $uptime
Load Average: $load_average
Logged-in Users: $users

${RED}=== Recent Failed Login Attempts ===${NC}
$failed_logs_j

${PURPLE}=== End of Report ===${NC}
EOF
)"
