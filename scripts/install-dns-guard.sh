#!/usr/bin/env bash
# Install a LaunchAgent that runs dns-guard.sh hourly.
set -euo pipefail
PLIST=~/Library/LaunchAgents/ie.preston.dns-guard.plist
SCRIPT="$(cd "$(dirname "$0")" && pwd)/dns-guard.sh"
TOKEN_FILE="${HOME}/.hermes/.dns-guard-token"

if [ ! -r "$TOKEN_FILE" ]; then
  printf "Technitium API token (input hidden): "; read -rs T; echo
  umask 077; printf '%s' "$T" > "$TOKEN_FILE"
  echo "token saved to $TOKEN_FILE"
fi

mkdir -p "$(dirname "$PLIST")" "$HOME/.hermes/logs"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>ie.preston.dns-guard</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$SCRIPT</string>
  </array>
  <key>StartCalendarInterval</key><dict>
    <key>Minute</key><integer>7</integer>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>StandardErrorPath</key><string>$HOME/.hermes/logs/dns-guard.err</string>
</dict></plist>
EOF
launchctl bootout gui/$(id -u)/ie.preston.dns-guard 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"
echo "installed + loaded: $PLIST (runs hourly at :07 and at login)"
launchctl print gui/$(id -u)/ie.preston.dns-guard | grep -E 'state|program' | head -3
