# DNS guard (Technitium on friday)

## Root cause (2026-10-09)

`api.github.com` NXDOMAIN on every client using friday's Technitium
(100.114.9.59 / `friday` via MagicDNS). The Technitium **Primary zone
`github.com`** answers api.github.com authoritatively; the zone only pinned
`github.com` (140.82.121.3) and `codeload.github.com`, so `api.github.com`
had no record → NXDOMAIN, and no fallback to upstream.

Fix: `POST /api/zones/records/add` with `domain=api.github.com type=A
ipAddress=<fresh-ip> ttl=300` (ip learned from 192.168.0.1). Verified with
`dig @100.100.100.100 api.github.com +short`.

Gotchas hit:
- `nslookup` output parsing: take the LAST `Address:` field and regex-validate
  IPv4 — `Address: 192.168.0.1#53` lines (server echo) will poison the value.
- After fixing server-side, macOS clients may still serve a cached negative
  answer from mDNSResponder until TTL/flush; `sudo killall -HUP mDNSResponder`
  on each client.
- Friday's SSH (port 22) is closed; Technitium dashboard API on :5380 is the
  management path. Token in `~/.hermes/.dns-guard-token` (0600).

## dns-guard.sh

Hourly (LaunchAgent `ie.preston.dns-guard`, install with
`install-dns-guard.sh`): for each critical host, if `dig @friday A` fails,
learn a fresh IP from 192.168.0.1 and re-add the record to the parent zone.
Idempotent, logs to `~/.hermes/logs/dns-guard.log`, `DRY_RUN=1` supported.

Extend by editing `HOSTS` in dns-guard.sh (default: api.github.com
github.com codeload.github.com objects.githubusercontent.com).
