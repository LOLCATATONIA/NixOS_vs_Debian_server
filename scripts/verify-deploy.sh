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
