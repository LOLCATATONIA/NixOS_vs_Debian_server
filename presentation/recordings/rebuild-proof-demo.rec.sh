#!/usr/bin/env bash
#
# Optager det ægte determinisme-bevis: nix path-info FØR og EFTER en tvungen,
# uafhængig genopbygning (--rebuild) af selve NixOS-systemlukningen. Samme store-sti
# begge gange = byte for byte identisk, synligt på skærmen i stedet for i en statisk
# kodeblok. Køres PÅ VÆRTEN, i selve repoet.
# NIX_SENTRY_ENDPOINT/NIX_CONFIG sættes FØR Show, så de to kendte, harmløse støjlinjer
# (se scripts/setup.sh) aldrig optages.
# Kræver: nix run nixpkgs#tmux, nixpkgs#asciinema, nixpkgs#asciinema-agg,
# nixpkgs#ffmpeg på PATH.

source "$(dirname "${BASH_SOURCE[0]}")/s-vhs.sh"

SetOutput "$(dirname "${BASH_SOURCE[0]}")/../public/rebuild-proof-demo.gif"
SetCols 100
SetRows 14
SetFontSize 20
SetTypingSpeed 0.035
SetLoop 'off'
SetLastFrameDuration 999

Start

Type 'cd ~/Desktop/projekter/Linux_101 && export NIX_SENTRY_ENDPOINT="" NIX_CONFIG="warn-dirty = false"'
Enter
Sleep 0.5
Key C-l

Show

Type 'nix path-info .#nixosConfigurations.nixos-comparison.config.system.build.toplevel'
Enter
Sleep 1.5

Type 'nix build .#nixosConfigurations.nixos-comparison.config.system.build.toplevel --rebuild'
Enter
Sleep 2

Type 'nix path-info .#nixosConfigurations.nixos-comparison.config.system.build.toplevel'
Enter
Sleep 2.5

Render
