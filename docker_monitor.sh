#!/bin/bash

# === LOAD CONFIG ===
# Make sure config.env is in the same folder as this script
CONFIG_FILE="$(dirname "$0")/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# === CONFIG ===
STATE_FILE="/var/tmp/docker_monitor_state.txt"
LOG_FILE="/var/tmp/docker_monitor.log"

# Thresholds
CPU_THRESHOLD=90
RAM_THRESHOLD=90
DISK_THRESHOLD=90
DISK_PARTITION="/dev/sda1"

echo "===== Running script at $(date) =====" >>"$LOG_FILE"

# --- FUNCTION TO SEND PLAIN TEXT MESSAGE ---
send_discord_message() {
    local message="$1"
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "$(jq -n --arg content "$message" '{content:$content}')" \
         "$DISCORD_WEBHOOK" >>"$LOG_FILE" 2>&1
}

# --- DAILY UPDATES ---
if [[ "$1" == "daily" ]]; then
    TOTAL_UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
    send_discord_message "📦 Daily Updates: $TOTAL_UPDATES updates available."
    echo "Daily check: $TOTAL_UPDATES updates found." >>"$LOG_FILE"
    exit 0
fi

# --- DOCKER MONITOR: per-container check ---
CHANGES_MESSAGE=""
declare -A OLD_MAP
declare -A NEW_MAP

# Read old state into array
if [[ -f "$STATE_FILE" ]]; then
    while read -r line; do
        NAME=$(echo "$line" | awk '{print $1}')
        STATUS=$(echo "$line" | awk '{print $2}')
        OLD_MAP["$NAME"]="$STATUS"
    done < "$STATE_FILE"
fi

# Read current state into array
while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $2}')
    NEW_MAP["$NAME"]="$STATUS"
done <<< "$(docker ps -a --format "{{.Names}} {{.State}}")"

# Compare old vs new
for NAME in "${!NEW_MAP[@]}"; do
    OLD_STATUS="${OLD_MAP[$NAME]}"
    NEW_STATUS="${NEW_MAP[$NAME]}"
    if [[ "$OLD_STATUS" != "$NEW_STATUS" ]]; then
        [[ -z "$CHANGES_MESSAGE" ]] && CHANGES_MESSAGE="🐳 Docker Monitor - Container status changed:"$'\n'
        ICON="❓"
        [[ "$NEW_STATUS" == running ]] && ICON="✅"
        [[ "$NEW_STATUS" == exited ]] && ICON="❌"
        [[ "$NEW_STATUS" == restarting ]] && ICON="⚠️"
        CHANGES_MESSAGE+="$ICON $NAME: $NEW_STATUS"$'\n'
    fi
done

# Update state file
docker ps -a --format "{{.Names}} {{.State}}" > "$STATE_FILE"

# --- SYSTEM MONITOR ---
SYSTEM_MESSAGE=""

# CPU usage %
CPU=$(grep -P '^cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%d\n", usage}')
if (( CPU >= CPU_THRESHOLD )); then
    SYSTEM_MESSAGE+="⚠️ High CPU usage: $CPU%"$'\n'
fi

# RAM usage %
RAM=$(free | awk '/Mem/ {printf("%d\n",$3/$2 * 100)}')
if (( RAM >= RAM_THRESHOLD )); then
    SYSTEM_MESSAGE+="⚠️ High RAM usage: $RAM%"$'\n'
fi

# Disk usage %
DISK=$(df -h | awk -v part="$DISK_PARTITION" '$1==part {gsub("%","",$5); print $5}')
if (( DISK >= DISK_THRESHOLD )); then
    SYSTEM_MESSAGE+="⚠️ High disk usage on $DISK_PARTITION: $DISK%"$'\n'
fi

# --- SEND DISCORD MESSAGE IF ANY ---
FULL_MESSAGE="$CHANGES_MESSAGE$SYSTEM_MESSAGE"
if [[ -n "$FULL_MESSAGE" ]]; then
    send_discord_message "$FULL_MESSAGE"
    echo "Notification sent to Discord." >>"$LOG_FILE"
else
    echo "No changes or alerts detected." >>"$LOG_FILE"
fi

