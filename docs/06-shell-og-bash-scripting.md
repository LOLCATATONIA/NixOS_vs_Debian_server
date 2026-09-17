# Modul 6: Shell og Bash scripting

*Se [`00-tilgang.md`](00-tilgang.md) for den overordnede begrundelse for valg af NixOS.*

## Formål

At kunne automatisere opsætning, kontrol og rapportering, så konfigurationen er reproducerbar,
konsistent og ikke afhængig af manuelle, fejlbarlige trin.

## Sikkerhedsmæssig relevans

Automatisering reducerer menneskelige fejlkonfigurationer. Idempotente scripts er en forudsætning
for pålidelig, gentagelig systemhærdning. I incident response er evnen til hurtigt at skrive et
lille script, der undersøger et system, afgørende.

## NixOS-argumentet: hvad "idempotent automatisering" betyder her

Opgaven beder om `setup.sh`-scripts, der "automatiserer så meget af modul 1-5 som muligt", og som
er idempotente. Under en traditionel, imperativ arbejdsgang betyder det: bash-kald til
`useradd`/`chmod`/`ufw`/`sed -i sshd_config` osv., skrevet så de tåler at blive kørt igen uden at
fejle eller duplikere.

Under NixOS er den situation allerede løst — af selve platformen, ikke af os. `nixos-rebuild
switch` er i sig selv en idempotent automatisering af *hele* modul 1-5's konfiguration: at køre den
to gange giver per definition ingen afvigelse og ingen duplikering, fordi hele systemtilstanden er en ren
funktion af `configuration.nix`. At genopfinde det i bash (fx et script, der selv kalder `useradd`
og `chmod` for at nå samme mål) ville være at bygge en svagere, mindre pålidelig kopi af noget
platformen allerede garanterer bedre.

Vi løser derfor opgaven i to dele, som hver adresserer en reel, forskellig del af "bash scripting
i en sikkerhedskontekst":

1. **`scripts/setup.sh`** — automatiserer selve *bootstrap-mekanismen* fra modul 1 (bygning af
   VM'en fra flake, se [`01-vm-og-netvaerk.md`](01-vm-og-netvaerk.md)) som ét idempotent script,
   kørt på **værten**. Det er ikke en bash-reimplementering af modul 2-5's indhold — det er
   automatiseringen af selve leveringsmekanismen, som reelt er det, en systemadministrator ville
   skulle scripte i en NixOS-baseret arbejdsgang.
2. **`scripts/verify-deploy.sh`** — udfylder den rolle, bash rent faktisk spiller under en
   deklarativ model: ikke at *ændre* systemet, men at *verificere* at det ikke er drevet væk fra
   det, der er godkendt. Det er en ægte, selvstændig anvendelse af bash-scripting, som ikke findes
   "gratis" i NixOS' egne værktøjer.

`scripts/healthcheck.sh` (opgave 3) har ingen NixOS-specifik vinkel overhovedet — det er et
almindeligt, portabelt statusscript, der virker uændret på ethvert Linux-system.

## `scripts/setup.sh`

```bash
#!/usr/bin/env bash
# Modul 6: setup.sh - idempotent bootstrap/genopbygning af linux101-srv-VM'en.
#
# Køres på VÆRTEN (ikke på VM'en). Automatiserer modul 1's VM-oprettelse — og dermed
# indirekte modul 1-5's fulde konfiguration, som allerede er bagt ind i det byggede
# diskimage via flake.nix. Se docs/06-shell-og-bash-scripting.md for begrundelsen for,
# hvorfor dette (og ikke fx chmod/useradd-kald) er den rigtige automatisering under NixOS.
#
# Idempotens: en eksisterende VM/volume med samme navn slettes først, hvis den findes,
# så scriptet altid konvergerer til præcis den tilstand, flake.nix beskriver — uanset
# hvor mange gange det køres, og uden fejl eller duplikerede ressourcer.
#
# Brug: ./scripts/setup.sh   (fra repo-roden; kræver at værten allerede har Nix,
#                              libvirt/QEMU og de sudo-rettigheder, docs/00-tilgang.md
#                              beskriver)
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
    echo "FEJL: 'nix' blev ikke fundet i PATH. Se docs/01-vm-og-netvaerk.md." >&2
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

**Hvordan det køres:** `./scripts/setup.sh` fra repo-roden, på **værten** (kræver Nix,
libvirt/QEMU og sudo-rettighederne fra [`00-tilgang.md`](00-tilgang.md)).

**Idempotens-argument:** Scriptet fjerner altid en eksisterende VM/volume med samme navn først, før
det genopbygger. Det er *ikke* et rent no-op ved gentagne kørsler — men det er idempotent i den
forstand, som Terraform/Ansible bruger ordet: uanset hvor mange gange scriptet køres, konvergerer
resultatet til nøjagtig den tilstand, `flake.nix` beskriver, uden fejl og uden duplikerede
ressourcer (to VM'er med samme navn, forældreløse volumes osv.).

**Bevis (kørt to gange i træk):**

```
$ ./scripts/setup.sh
[setup.sh] Opretter volume og importerer image i libvirt...
...
[setup.sh] Færdig. 'linux101-srv' kører nu med den konfiguration, der er deklareret i flake.nix.

$ ./scripts/setup.sh
Vol linux101-srv.qcow2 deleted
[setup.sh] Bygger diskimage fra flake.nix (kan tage nogle minutter)...
[setup.sh] Opretter volume og importerer image i libvirt...
...
[setup.sh] Færdig. 'linux101-srv' kører nu med den konfiguration, der er deklareret i flake.nix.
$ echo $?
0
```

Anden kørsel opdager og fjerner den eksisterende VM/volume korrekt og genopbygger uden fejl.

## `scripts/healthcheck.sh` (opgave 3)

```bash
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

**Hvordan det køres:** Kopieres til/kaldes på serveren, fx
`ssh admin@<vm-ip> -p 2222 '~/linux101-config/scripts/healthcheck.sh'`. Kræver den granulære
sudo-regel for `nft list ruleset` (modul 3/4) for at kunne rapportere firewall-status.

**Eksempeloutput fra det færdige system** (kørt interaktivt, så `who` viser den aktive session):

```
[admin@linux101-srv:~]$ ~/linux101-config/scripts/healthcheck.sh
Healthcheck for linux101-srv -- 2026-09-14 12:34:43

== Firewall-status ==
  type filter hook prerouting priority mangle + 10; policy drop;
  meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept comment "DHCPv4 client/server"
  fib saddr . mark check exists accept
  type filter hook input priority filter; policy drop;
  iifname "lo" accept comment "trusted interfaces"
  icmpv6 type echo-reply accept
  ct state vmap { invalid : drop, established : accept, related : accept, new : jump input-allow, untracked : jump input-allow }
  meta l4proto . th dport @temp-ports accept
  icmp type echo-request accept comment "allow ping"
  icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 messages except redirects and node information queries (type 139).  See RFC 4890, section 4.4."
  ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
  ip saddr 192.168.122.1 tcp dport 2222 accept
  udp sport 53 accept

== Diskplads ==
Rodfilsystem: 61% brugt, 1.7G ledig diskplads
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda3       4.5G  2.6G  1.7G  61% /

== Aktive/loggede ind brugere ==
admin    pts/0        2026-09-14 12:11 (192.168.122.1)

== Brugere med UID 0 (ud over root) ==
Ingen -- kun root har UID 0.
```

*Bemærk:* Et non-interaktivt kald (`ssh host 'kommando'` uden pty) giver et tomt resultat for
"Aktive/loggede ind brugere", fordi `who` udelukkende viser sessioner registreret i `utmp` — hvilket
kræver en reel, interaktiv pty-baseret login. Det er korrekt scriptadfærd (ingen fejl, blot et
sandfærdigt "ingen interaktive sessioner"), men ovenstående eksempel er bevidst kørt interaktivt for
at vise et udfyldt eksempel.

## `scripts/verify-deploy.sh`

```bash
#!/usr/bin/env bash
# Modul 6: verify-deploy.sh - verificerer at den KØRENDE konfiguration stemmer
# overens med den DEKLAREREDE konfiguration (flake.nix), uden at ændre noget selv.
#
# Køres PÅ SERVEREN, hvor flake-kilden ligger i ~/linux101-config (se
# docs/00-tilgang.md, Fase 2). Kræver ikke sudo.
#
# NixOS-argument (se docs/06-shell-og-bash-scripting.md): selve den "idempotente
# automatisering", modul 6 efterspørger, er under NixOS langt overvejende
# `nixos-rebuild switch` selv — ikke noget der skal genopfindes i bash. Dette script
# udfylder i stedet den rolle, bash-scripting reelt spiller under en deklarativ
# model: at VERIFICERE at systemet ikke er drevet væk fra det, der er godkendt,
# fremfor selv at ændre det.
#
# Designvalg: scriptet EVALUERER blot den deklarerede konfigurations output-sti
# (`nix eval`) i stedet for at BYGGE den (`nixos-rebuild build`). Nix' output-stier
# er indholdsadresserede og kan beregnes ud fra inputs alene, uden at realisere
# (bygge) derivationen. Første version af scriptet brugte `nixos-rebuild build`,
# hvilket ramte samme begrænsning som modul 4/5's DNS-problem: selv en triviel
# konfigurationsændring udløste et forsøg på at bygge nye, ikke-cachede
# build-tidsafhængigheder, som VM'en (uden udgående internetadgang) ikke kunne
# hente. `nix eval` undgår problemet helt, fordi det aldrig bygger noget.
#
# Brug: ./verify-deploy.sh
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

**Hvordan det køres:** `./verify-deploy.sh` på **serveren**, hvor flake-kilden er kopieret til
`~/linux101-config`. Kræver ikke sudo.

### To reelle fejl fundet under udvikling af dette script

1. **Bash-faldgrube: `local`-variabel ubunden i en `EXIT`-trap.** Første version brugte
   `local workdir` inde i `main()`, sat via `mktemp -d`, med en `trap 'rm -rf "$workdir"' EXIT`. Ved
   en fejlende kørsel fejlede selve trap'en med *"workdir: unbound variable"* — en kendt,
   dokumenteret bash-finurlighed: en funktions lokale scope kan være afviklet, før en
   proces-global `EXIT`-trap rent faktisk fyrer, især når `set -e` afbryder scriptet midt i et
   funktionskald. Løsning: `workdir` er nu en scriptglobal variabel, sat til `""` før `trap` er
   registreret, med et eksplicit tomheds-tjek i cleanup-funktionen.
2. **`nixos-rebuild build` ramte samme DNS-begrænsning som modul 4/5.** Første version byggede
   den deklarerede konfiguration lokalt for at sammenligne den med `/run/current-system`. Selv en
   triviel, rent data-mæssig ændring (fx tilføjelse af et portnummer til en liste) udløste et
   forsøg på at bygge nye build-tidsafhængigheder, som ikke var cachet lokalt på VM'en — og som
   VM'en (uden udgående internetadgang, se modul 4's addendum) ikke kunne hente. Løsning: scriptet
   bruger nu `nix eval` i stedet for `nixos-rebuild build`. Nix' output-stier er
   indholdsadresserede og kan beregnes ud fra inputs alene, *uden* at bygge/realisere
   derivationen — hvilket gør sammenligningen både hurtigere (~6 sekunder mod flere minutter) og
   helt uafhængig af netværksadgang. (DNS-begrænsningen selv blev senere identificeret og rettet,
   se modul 4's Addendum 2 — men `nix eval` er stadig det bedre valg her, uafhængigt af det.)

### Bevis: begge grene af scriptet testet

**Uændret konfiguration (skal matche):**

```
$ ./verify-deploy.sh
Evaluerer (uden at bygge) den deklarerede konfigurations output-sti...
Koerende system:   /nix/store/r0vf7781z1kwr4igrpfnjy3yv5r4373y-nixos-system-linux101-srv-26.11.20260911.eaad089
Deklareret system: /nix/store/r0vf7781z1kwr4igrpfnjy3yv5r4373y-nixos-system-linux101-srv-26.11.20260911.eaad089
OK: systemet stemmer overens med den deklarerede konfiguration.
$ echo $?
0
```

**Ændret (men ikke-deployet) konfiguration** — en testændring i den lokale flake-kopi, uden at køre
`nixos-rebuild switch`, for at bevise at scriptet reelt opdager afvigelser og ikke bare altid siger "OK":

```
$ sed -i 's/allowedTCPPorts = \[ \];/allowedTCPPorts = [ 9999 ];/' nixos/modules/firewall.nix
$ ./verify-deploy.sh
Evaluerer (uden at bygge) den deklarerede konfigurations output-sti...
Koerende system:   /nix/store/r0vf7781z1kwr4igrpfnjy3yv5r4373y-nixos-system-linux101-srv-26.11.20260911.eaad089
Deklareret system: /nix/store/agv1wbbxyfiar4ny4k2qqx1qzpsvr512-nixos-system-linux101-srv-26.11.20260911.eaad089
ADVARSEL: systemet er drevet vaek fra den deklarerede konfiguration.
Koer: sudo nixos-rebuild switch --flake /home/admin/linux101-config
$ echo $?
1
```

(Begge transskripter ovenfor er ægte captures fra dengang scriptets tekststrenge stadig var
ASCII-translittereret. De er bevidst ikke rettet i efterspilstid, ligesom kildekoden ovenfor nu er
opdateret. Se addendummet nedenfor for selve beslutningen om at gå væk fra ASCII.)

### Addendum: fra ASCII-translitteration til rigtig UTF-8 i logget output

De to scripts ovenfor, samt `monitor.sh`, brugte oprindeligt en bevidst ASCII-transskription i alle
strenge, der rent faktisk bliver skrevet til stdout/logfil (`taerskel`, `paa`, `Koerende`, `vaek`),
mens kommentarer i de samme filer frit brugte æøå. Begrundelsen på daværende tidspunkt: `monitor.sh`
køres af `cron`, som traditionelt kører med et minimalt miljø, uden garanti for en sat
UTF-8-locale, og ASCII blev derfor valgt som en defensiv vane for alt logget output, ikke kun det
faktisk cron-afhængige.

Testet direkte mod VM'en, med et fuldstændigt tomt miljø (strengere end en typisk cron-kørsel):

```
$ env -i /bin/sh -c 'echo Overvaagning: kørende ædruelig test'
Overvaagning: kM-CM-8rende M-CM-&druelig test
```

(`cat -A`-visning af samme output bekræfter at bytene for `ø`/`æ` er de korrekte, uskadte
UTF-8-sekvenser.) Konklusion: `echo` sender blot de bytes, scriptfilen allerede indeholder, locale
påvirker ikke selve gennemløbet, kun hvordan en visning *fortolker* dem bagefter, hvilket er et
klient-side-anliggende. NixOS sætter desuden `en_US.UTF-8` som standard-locale. Der var derfor ingen
reel risiko at beskytte sig imod på dette system, og strengene er efterfølgende rettet til korrekt
`æøå` alle tre steder.

## Opgave 4: funktioner, variable, betingelser, fejlhåndtering

Alle tre scripts bruger `set -euo pipefail`, er opdelt i navngivne funktioner med lokale variable
hvor muligt, bruger betingelser (`if`/`[[ ]]`) til beslutninger, og håndterer forventede fejltilstande
eksplicit (manglende flake-kilde, manglende sudo-adgang til firewall-status, manglende
storage-pool). Se de enkelte filer for detaljer.

## Dokumentationskrav for modulet — opsummering

- Alle scripts, kommenterede, med kørselsvejledning: se ovenstående afsnit samt
  [`scripts/`](../scripts/).
- Eksempeloutput fra `healthcheck.sh`: se ovenfor.
