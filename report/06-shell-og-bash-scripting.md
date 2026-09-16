# Modul 6: Shell og Bash scripting

## Formål

At kunne automatisere opsætning, kontrol og rapportering, så konfigurationen er reproducerbar,
konsistent og ikke afhængig af manuelle, fejlbarlige trin.

## Sikkerhedsmæssig relevans

Automatisering reducerer menneskelige fejlkonfigurationer. Idempotente scripts er en forudsætning
for pålidelig, gentagelig systemhærdning.

## Sammenligning: traditionel tilgang vs. NixOS

| Opgave | Traditionel løsning | NixOS-løsning |
|---|---|---|
| Idempotent opsætningsscript | Bash-script med `useradd`/`chmod`/`ufw`-kald, skrevet så genkørsel er sikker | `nixos-rebuild switch` er i sig selv idempotent for hele systemets tilstand. `setup.sh` automatiserer i stedet selve *bootstrap-mekanismen* (bygning og import af VM'en) |
| Verifikation af systemtilstand | Ingen indbygget mekanisme, kræver eget script | `verify-deploy.sh`: sammenligner kørende system med den deklarerede konfiguration |

`healthcheck.sh` (opgave 3) har ingen NixOS-specifik vinkel. Det er et almindeligt, portabelt
statusscript.

## `scripts/setup.sh`

Automatiserer bygning og (gen)oprettelse af VM'en fra `flake.nix`. Køres på **værten**:
`./scripts/setup.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly VM_NAME="linux101-srv"
readonly POOL_NAME="default"
readonly POOL_PATH="/var/lib/libvirt/images"
readonly DISK_SIZE_BYTES=5196742656
readonly VCPUS=2
readonly MEMORY_MB=3072
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  echo "[setup.sh] $*"
}

ensure_nix_in_path() {
  if ! command -v nix &>/dev/null; then
    # shellcheck disable=SC1091
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh 2>/dev/null || true
  fi
  if ! command -v nix &>/dev/null; then
    echo "FEJL: 'nix' blev ikke fundet i PATH." >&2
    exit 1
  fi
}

ensure_storage_pool() {
  if ! sudo virsh pool-info "$POOL_NAME" &>/dev/null; then
    log "Opretter storage pool '${POOL_NAME}'..."
    sudo virsh pool-define-as "$POOL_NAME" dir --target "$POOL_PATH"
    sudo virsh pool-autostart "$POOL_NAME"
  fi
  if ! sudo virsh pool-info "$POOL_NAME" | grep -q "State: *running"; then
    log "Starter storage pool '${POOL_NAME}'..."
    sudo virsh pool-start "$POOL_NAME"
  fi
}

remove_existing_vm() {
  if sudo virsh dominfo "$VM_NAME" &>/dev/null; then
    log "Fjerner eksisterende VM '${VM_NAME}' (for idempotent genopbygning)..."
    sudo virsh destroy "$VM_NAME" &>/dev/null || true
    sudo virsh undefine "$VM_NAME" &>/dev/null || true
  fi
  if sudo virsh vol-info --pool "$POOL_NAME" "${VM_NAME}.qcow2" &>/dev/null; then
    sudo virsh vol-delete --pool "$POOL_NAME" "${VM_NAME}.qcow2"
  fi
}

build_image() {
  log "Bygger diskimage fra flake.nix (kan tage nogle minutter)..."
  (cd "$REPO_DIR" && nix build .#qcow -L)
}

import_vm() {
  log "Opretter volume og importerer image i libvirt..."
  sudo virsh vol-create-as "$POOL_NAME" "${VM_NAME}.qcow2" "$DISK_SIZE_BYTES" --format qcow2
  sudo virsh vol-upload --pool "$POOL_NAME" "${VM_NAME}.qcow2" "${REPO_DIR}/result/nixos.qcow2"

  sudo virt-install \
    --name "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --vcpus "$VCPUS" \
    --disk "vol=${POOL_NAME}/${VM_NAME}.qcow2,bus=virtio" \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --os-variant generic \
    --noautoconsole
}

main() {
  ensure_nix_in_path
  ensure_storage_pool
  remove_existing_vm
  build_image
  import_vm
  log "Færdig. '${VM_NAME}' kører nu med den konfiguration, der er deklareret i flake.nix."
}

main "$@"
```

**Idempotens, bevist ved to kørsler i træk:**

```
$ ./scripts/setup.sh
[setup.sh] Opretter volume og importerer image i libvirt...
[setup.sh] Færdig. 'linux101-srv' kører nu med den konfiguration, der er deklareret i flake.nix.

$ ./scripts/setup.sh
Vol linux101-srv.qcow2 deleted
[setup.sh] Færdig. 'linux101-srv' kører nu med den konfiguration, der er deklareret i flake.nix.
$ echo $?
0
```

## `scripts/healthcheck.sh` (opgave 3)

Køres på **serveren**: `~/linux101-config/scripts/healthcheck.sh`. Kræver den granulære sudo-regel
for `nft list ruleset` (modul 3/4).

```bash
#!/usr/bin/env bash
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
```

**Eksempeloutput fra det færdige system:**

```
[admin@linux101-srv:~]$ ~/linux101-config/scripts/healthcheck.sh
Healthcheck for linux101-srv -- 2026-09-14 12:34:43

== Firewall-status ==
  type filter hook prerouting priority mangle + 10; policy drop;
  type filter hook input priority filter; policy drop;
  ip saddr 192.168.122.1 tcp dport 2222 accept

== Diskplads ==
Rodfilsystem: 61% brugt, 1.7G ledig diskplads
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda3       4.5G  2.6G  1.7G  61% /

== Aktive/loggede ind brugere ==
admin    pts/0        2026-09-14 12:11 (192.168.122.1)

== Brugere med UID 0 (ud over root) ==
Ingen -- kun root har UID 0.
```

## `scripts/verify-deploy.sh`

Verificerer at den kørende konfiguration stemmer overens med den deklarerede (`flake.nix`), uden at
ændre noget selv. Køres på **serveren**: `./verify-deploy.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly FLAKE_DIR="${HOME}/linux101-config"
readonly FLAKE_ATTR="nixosConfigurations.linux101-srv.config.system.build.toplevel"

main() {
  if [[ ! -d "$FLAKE_DIR" ]]; then
    echo "FEJL: fandt ikke flake-kilde i ${FLAKE_DIR}" >&2
    exit 2
  fi

  echo "Evaluerer (uden at bygge) den deklarerede konfigurations output-sti..."
  local declared_path current_path
  declared_path=$(nix --extra-experimental-features "nix-command flakes" \
    eval --raw "${FLAKE_DIR}#${FLAKE_ATTR}")
  current_path=$(readlink -f /run/current-system)

  echo "Koerende system:   ${current_path}"
  echo "Deklareret system: ${declared_path}"

  if [[ "$current_path" == "$declared_path" ]]; then
    echo "OK: systemet stemmer overens med den deklarerede konfiguration."
    exit 0
  else
    echo "ADVARSEL: systemet er drevet vaek fra den deklarerede konfiguration."
    echo "Koer: sudo nixos-rebuild switch --flake ${FLAKE_DIR}"
    exit 1
  fi
}

main "$@"
```

**Bevis, begge grene testet:**

```
$ ./verify-deploy.sh
Koerende system:   /nix/store/r0vf...-nixos-system-linux101-srv-...
Deklareret system: /nix/store/r0vf...-nixos-system-linux101-srv-...
OK: systemet stemmer overens med den deklarerede konfiguration.
$ echo $?
0

$ sed -i 's/allowedTCPPorts = \[ \];/allowedTCPPorts = [ 9999 ];/' nixos/modules/firewall.nix
$ ./verify-deploy.sh
Koerende system:   /nix/store/r0vf...-nixos-system-linux101-srv-...
Deklareret system: /nix/store/agv1...-nixos-system-linux101-srv-...
ADVARSEL: systemet er drevet vaek fra den deklarerede konfiguration.
$ echo $?
1
```
