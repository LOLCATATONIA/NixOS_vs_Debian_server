#!/usr/bin/env bash
# Modul 6: healthcheck.sh - selvstændig statusrapport for serveren.
#
# Køres PÅ SERVEREN (fx: ssh admin@<vm-ip> -p 2222 'bash -s' < scripts/healthcheck.sh,
# eller kopieret ind og kørt lokalt: ./healthcheck.sh). Kræver ingen argumenter.
# Kræver den granulære sudo-regel for `nft list ruleset` fra modul 3/4 for at kunne
# rapportere firewall-status uden fuld root-adgang.
set -euo pipefail

readonly DISK_WARN_THRESHOLD=85

section() {
  echo
  echo "== $1 =="
}

check_firewall() {
  section "Firewall-status"
  if sudo -n nft list ruleset &>/tmp/hc-nft.$$ 2>&1; then
    grep -E 'hook input|policy|accept|drop' /tmp/hc-nft.$$ | sed 's/^[[:space:]]*/  /'
  else
    echo "ADVARSEL: kunne ikke laese firewall-status (mangler sudo-adgang til 'nft list ruleset')"
  fi
  rm -f /tmp/hc-nft.$$
}

check_disk() {
  section "Diskplads"
  local usage avail
  usage=$(df --output=pcent / | tail -1 | tr -dc '0-9')
  avail=$(df -h --output=avail / | tail -1 | tr -d '[:space:]')
  echo "Rodfilsystem: ${usage}% brugt, ${avail} ledig diskplads"
  if (( usage > DISK_WARN_THRESHOLD )); then
    echo "ADVARSEL: diskforbrug overstiger taerskel paa ${DISK_WARN_THRESHOLD}%"
  fi
  df -h /
}

check_users() {
  section "Aktive/loggede ind brugere"
  who
}

check_uid_zero() {
  section "Brugere med UID 0 (ud over root)"
  local extra
  extra=$(awk -F: '$3 == 0 && $1 != "root" { print $1 }' /etc/passwd || true)
  if [[ -n "$extra" ]]; then
    echo "ADVARSEL: fandt uventede UID 0-brugere:"
    echo "$extra"
  else
    echo "Ingen -- kun root har UID 0."
  fi
}

main() {
  echo "Healthcheck for $(hostname) -- $(date '+%Y-%m-%d %H:%M:%S')"
  check_firewall
  check_disk
  check_users
  check_uid_zero
}

main "$@"
