#!/usr/bin/env bash
# DNS guard: verify the LAN resolver (Technitium on 'friday') serves critical
# hostnames; auto-repair the github.com zone if api.github.com goes NXDOMAIN.
# Designed to run from launchd/cron hourly. macOS, user-level (no sudo).
set -u

DNS_HOST="${DNS_HOST:-friday}"            # Technitium server (resolvable via Tailscale MagicDNS)
TOKEN_FILE="${TOKEN_FILE:-$HOME/.hermes/.dns-guard-token}"
LOG="${LOG:-$HOME/.hermes/logs/dns-guard.log}"
HOSTS="${HOSTS:-api.github.com github.com codeload.github.com objects.githubusercontent.com}"
FALLBACK_RESOLVER="${FALLBACK_RESOLVER:-192.168.0.1}"   # LAN router, used to learn fresh IPs
TTL=300
DRY_RUN="${DRY_RUN:-0}"

log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

token(){ [ -r "$TOKEN_FILE" ] && cat "$TOKEN_FILE" || return 1; }

# learn current IP for a host from a working upstream resolver
fresh_ip(){
  nslookup "$1" "$FALLBACK_RESOLVER" 2>/dev/null \
    | awk '/^Address[0-9 ]*:/{print $NF}' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

# does the guard's own resolver answer with an A record?
resolves(){
  dig "@$DNS_HOST" "$1" A +short +time=3 +tries=1 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

add_record(){ # host ip
  local t; t="$(token)" || { log "ERROR: no token file $TOKEN_FILE"; return 1; }
  if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN would add $1 -> $2"; return 0; fi
  curl -fsS -m 10 -X POST "http://$DNS_HOST:5380/api/zones/records/add" \
    -d "token=$t" -d "domain=$1" -d "type=A" -d "ipAddress=$2" -d "ttl=$TTL" >/dev/null 2>&1 \
    && log "added $1 -> $2" || { log "ERROR adding $1"; return 1; }
}

# If the missing host's parent zone doesn't exist on Technitium at all, we can't
# add records (the NXDOMAIN root cause is different); report it.
zone_exists(){
  local t; t="$(token)" || return 1
  curl -fsS -m 10 "http://$DNS_HOST:5380/api/zones/records/get?token=$t&domain=$1&listZone=true" 2>/dev/null \
    | grep -q '"status":"ok"'
}

repaired=0
for h in $HOSTS; do
  resolves "$h" && continue
  ip="$(fresh_ip "$h")"
  if [ -z "$ip" ]; then
    log "WARN: $h unresolvable and no fresh IP from $FALLBACK_RESOLVER (upstream down?)"
    continue
  fi
  parent="${h#*.}"
  if ! zone_exists "$parent"; then
    log "ERROR: $h NXDOMAIN and zone $parent absent on $DNS_HOST — needs manual zone check"
    continue
  fi
  log "FIX: $h NXDOMAIN via $DNS_HOST, adding A $ip (parent zone $parent)"
  add_record "$h" "$ip" && repaired=$((repaired+1))
done

# summary line every run (cheap heartbeat)
log "check complete: repaired=$repaired"
exit 0
