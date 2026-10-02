#!/usr/bin/env bash
#
# Optager en FAIR demo mod den kørende nixos-comparison VM: åbner configuration.nix
# i nano, tilføjer "fastfetch" til systemPackages, gemmer, og kører en rigtig
# nixos-rebuild switch der installerer den for første gang, parallelt med
# debian-install-demo.rec.sh's ægte "apt install fastfetch".
# SSH-login sker FØR Show kaldes, så selve login ikke optages.
# Kræver: nix run nixpkgs#tmux, nixpkgs#asciinema, nixpkgs#asciinema-agg,
# nixpkgs#ffmpeg på PATH. VM'en skal være startet først.

source "$(dirname "${BASH_SOURCE[0]}")/s-vhs.sh"

SetOutput "$(dirname "${BASH_SOURCE[0]}")/../public/nixos-rebuild-demo.gif"
SetCols 100
SetRows 30
SetFontSize 20
SetTypingSpeed 0.035
SetPlaybackSpeed 0.5
SetLoop 'off'
SetLastFrameDuration 999

Start

Type 'ssh -i ~/.ssh/nixos_comparison_admin_ed25519 -p 2222 admin@192.168.122.10'
Enter
Sleep 2.5
Key C-l

Show

Type 'nano ~/nixos-comparison-config/nixos/configuration.nix'
Enter
Sleep 1

Key C-w
Type 'tealdeer'
Enter
Key End
Enter
Type '    fastfetch'
Sleep 0.5

Key C-o
Enter
Sleep 0.5
Key C-x
Sleep 1

Type 'sudo nixos-rebuild switch --flake /home/admin/nixos-comparison-config'
Enter
Wait 'Done\.' 60
Sleep 1.5
Key C-l

Type 'fastfetch'
Enter
Sleep 3

Render
