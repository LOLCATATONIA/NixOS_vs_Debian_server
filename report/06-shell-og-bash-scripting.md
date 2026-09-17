# Modul 6: Shell og Bash scripting

## Formål

At kunne automatisere opsætning, kontrol og rapportering, så konfigurationen er reproducerbar,
konsistent og ikke afhængig af manuelle, fejlbarlige trin.

## Sikkerhedsmæssig relevans

Automatisering reducerer menneskelige fejlkonfigurationer. Idempotente scripts er en forudsætning
for pålidelig, gentagelig systemhærdning.

## Hvad vil det sige at et script er idempotent?

Et idempotent script giver samme slutresultat, uanset om det køres én gang eller hundrede gange:

```bash
# Ikke idempotent: tilføjer en ny linje for hver kørsel
echo "hello" >> /etc/myapp.conf

# Idempotent: tilføjer kun linjen, hvis den ikke allerede findes
grep -qxF "hello" /etc/myapp.conf || echo "hello" >> /etc/myapp.conf
```

Det samme gælder for et kald som `useradd alice`: kørt to gange fejler det, fordi brugeren allerede
findes, mens `id alice &>/dev/null || useradd alice` kan gentages uden problemer. Princippet er
grundlaget for infrastructure-as-code-værktøjer som Ansible, Puppet og NixOS: i stedet for at udføre
en fast liste af kommandoer i rækkefølge, beregnes forskellen mellem den nuværende og den ønskede
tilstand, og kun de nødvendige ændringer udføres.

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
readonly DISK_SIZE_BYTES=5196742656  # ~4.84 GiB, matcher diskstørrelsen fra modul 1
readonly VCPUS=2
readonly MEMORY_MB=3072
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  echo "[setup.sh] $*"
}

ensure_nix_in_path() {
  # nix er ikke nødvendigvis i PATH i en non-interaktiv shell (fx cron eller en frisk login-shell)
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
    # "|| true": pool'en kan være blevet startet af andet end scriptet (fx libvirtds egen
    # autostart) i tidsrummet mellem tjekket og dette kald. Målet er en kørende pool, ikke
    # at scriptet selv skal have startet den, så "allerede aktiv" er ikke en reel fejl her.
    sudo virsh pool-start "$POOL_NAME" || true
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

  # --import: springer OS-installation over, da diskimagen allerede har NixOS installeret
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

**Hvorfor er scriptet idempotent?** Hver funktion tjekker den nuværende tilstand, før den handler,
i stedet for at antage at intet findes endnu: `ensure_storage_pool` opretter kun storage pool'en,
hvis den ikke allerede findes, og `remove_existing_vm` fjerner kun en eksisterende VM og dens
volume, hvis de rent faktisk findes. `build_image` og `import_vm` bygger og opretter derefter altid
VM'en på ny, men fordi en eventuel gammel version lige er ryddet væk, opstår der aldrig en fejl om
en ressource, der allerede findes. Mønstret er "riv ned, hvis det findes, byg derefter altid op
igen fra bunden": uanset om scriptet køres første eller femtende gang, konvergerer slutresultatet
til det samme, nemlig præcis én VM ved navn `linux101-srv`, bygget fra den `flake.nix`, der ligger
på tidspunktet for kørslen.

**Idempotens, bevist ved to kørsler i træk:**

```
$ ./scripts/setup.sh
[setup.sh] Bygger diskimage fra flake.nix (kan tage nogle minutter)...
[...]
[setup.sh] Opretter volume og importerer image i libvirt...
Vol linux101-srv.qcow2 created
[setup.sh] Færdig. 'linux101-srv' kører nu med den konfiguration, der er deklareret i flake.nix.

$ ./scripts/setup.sh
[setup.sh] Fjerner eksisterende VM 'linux101-srv' (for idempotent genopbygning)...
Vol linux101-srv.qcow2 deleted
[setup.sh] Bygger diskimage fra flake.nix (kan tage nogle minutter)...
[...]
[setup.sh] Opretter volume og importerer image i libvirt...
Vol linux101-srv.qcow2 created
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
  # $$ (scriptets PID) sikrer et unikt filnavn, hvis flere kørsler overlapper
  if sudo -n nft list ruleset &>/tmp/hc-nft.$$ 2>&1; then
    grep -E 'hook input|policy|accept|drop' /tmp/hc-nft.$$ | sed 's/^[[:space:]]*/  /'
  else
    echo "ADVARSEL: kunne ikke læse firewall-status (mangler sudo-adgang til 'nft list ruleset')"
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
    echo "ADVARSEL: diskforbrug overstiger tærskel på ${DISK_WARN_THRESHOLD}%"
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
  # felt 3 i /etc/passwd er UID; kun 'root' bør have UID 0
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
  # --raw undgår at output-stien bliver JSON-anført med citationstegn
  declared_path=$(nix --extra-experimental-features "nix-command flakes" \
    eval --raw "${FLAKE_DIR}#${FLAKE_ATTR}")
  current_path=$(readlink -f /run/current-system)

  echo "Kørende system:    ${current_path}"
  echo "Deklareret system: ${declared_path}"

  if [[ "$current_path" == "$declared_path" ]]; then
    echo "OK: systemet stemmer overens med den deklarerede konfiguration."
    exit 0
  else
    echo "ADVARSEL: systemet er drevet væk fra den deklarerede konfiguration."
    echo "Kør: sudo nixos-rebuild switch --flake ${FLAKE_DIR}"
    exit 1
  fi
}

main "$@"
```

**Bevis, begge grene testet:**

```
$ ./verify-deploy.sh
Kørende system:    /nix/store/r0vf...-nixos-system-linux101-srv-...
Deklareret system: /nix/store/r0vf...-nixos-system-linux101-srv-...
OK: systemet stemmer overens med den deklarerede konfiguration.
$ echo $?
0

$ sed -i 's/allowedTCPPorts = \[ \];/allowedTCPPorts = [ 9999 ];/' nixos/modules/firewall.nix
$ ./verify-deploy.sh
Kørende system:    /nix/store/r0vf...-nixos-system-linux101-srv-...
Deklareret system: /nix/store/agv1...-nixos-system-linux101-srv-...
ADVARSEL: systemet er drevet væk fra den deklarerede konfiguration.
$ echo $?
1
```
