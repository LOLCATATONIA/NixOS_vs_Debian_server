#!/usr/bin/env bash
# Modul 6: setup.sh - idempotent bootstrap/genopbygning af nixos-comparison-VM'en.
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

readonly VM_NAME="nixos-comparison"
# Diskvolumen beholder sit oprindelige navn fra dengang VM'en hed "linux101-srv" —
# at omdøbe selve filen ville kræve at redigere domænets disk-XML-definition for en
# rent kosmetisk gevinst, ingen læser nogensinde ser filnavnet. Se 00-tilgang.md.
readonly DISK_VOLUME="linux101-srv.qcow2"
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
  if sudo virsh vol-info --pool "$POOL_NAME" "$DISK_VOLUME" &>/dev/null; then
    sudo virsh vol-delete --pool "$POOL_NAME" "$DISK_VOLUME"
  fi
}

build_image() {
  log "Bygger diskimage fra flake.nix (kan tage nogle minutter)..."
  (cd "$REPO_DIR" && nix build .#qcow -L)
}

import_vm() {
  log "Opretter volume og importerer image i libvirt..."
  sudo virsh vol-create-as "$POOL_NAME" "$DISK_VOLUME" "$DISK_SIZE_BYTES" --format qcow2
  sudo virsh vol-upload --pool "$POOL_NAME" "$DISK_VOLUME" "${REPO_DIR}/result/nixos.qcow2"

  # --import: springer OS-installation over, da diskimagen allerede har NixOS installeret
  sudo virt-install \
    --name "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --vcpus "$VCPUS" \
    --disk "vol=${POOL_NAME}/${DISK_VOLUME},bus=virtio" \
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
