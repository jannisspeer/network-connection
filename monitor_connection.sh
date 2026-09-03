#!/usr/bin/env bash
# Internet connection stability monitor.
# Appends one CSV row per monitored host per run to data/connection_log.csv:
#   timestamp,host,label,sent,received,loss_pct,min_ms,avg_ms,max_ms
# Targets: local gateway (resolved via default route), 1.1.1.1, 8.8.8.8.
#
# Install as a cronjob (every minute):
#   * * * * * /home/jannis/Desktop/Repos/network-connection/monitor_connection.sh

set -u

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/data/connection_log.csv}"
PING_COUNT="${PING_COUNT:-3}"
PING_TIMEOUT="${PING_TIMEOUT:-1}"

mkdir -p "$(dirname "$LOG_FILE")"

exec 9>"${LOG_FILE}.lock"
flock -n 9 || exit 0

GATEWAY="$(ip route show default 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "via") {print $(i+1); exit}}')"
TARGETS=("${GATEWAY:-unknown}|gateway" "1.1.1.1|cloudflare" "8.8.8.8|google")

TIMESTAMP="$(date +'%Y-%m-%dT%H:%M:%S%:z')"

if [ ! -s "$LOG_FILE" ]; then
    printf 'timestamp,host,label,sent,received,loss_pct,min_ms,avg_ms,max_ms\n' >>"$LOG_FILE"
fi

for target in "${TARGETS[@]}"; do
    host="${target%%|*}"
    label="${target#*|}"

    out="$(ping -c "$PING_COUNT" -W "$PING_TIMEOUT" -q "$host" 2>&1)"

    received="$(awk -F'[ ,]+' '/packets transmitted/ {print $4; exit}' <<<"$out")"
    loss="$(awk '/packet loss/ {for (i = 1; i <= NF; i++) if ($i ~ /%$/) {gsub(/%/, "", $i); print $i; exit}}' <<<"$out")"

    min="" ; avg="" ; max=""
    rtt="$(awk '/^rtt/ {print $4; exit}' <<<"$out")"
    if [ -n "$rtt" ]; then
        IFS='/' read -r min avg max _ <<<"$rtt"
    fi

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$TIMESTAMP" "$host" "$label" \
        "$PING_COUNT" "${received:-0}" "${loss:-100}" \
        "$min" "$avg" "$max" >>"$LOG_FILE"
done
