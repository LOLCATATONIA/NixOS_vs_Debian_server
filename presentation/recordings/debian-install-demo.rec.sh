#!/usr/bin/env bash
#
# Optager "apt install fastfetch" live mod den kørende debian-comparison VM.
# SSH-login sker FØR Show kaldes, så selve login ikke optages.
# Kræver: nix run nixpkgs#tmux, nixpkgs#asciinema, nixpkgs#asciinema-agg,
# nixpkgs#ffmpeg på PATH. VM'en skal være startet først.
# Kræver en midlertidig NOPASSWD-regel for /usr/bin/apt i sudoers (admin-kontoens
# kodeord er låst som en del af modul 3's hærdning).

source "$(dirname "${BASH_SOURCE[0]}")/s-vhs.sh"

SetOutput "$(dirname "${BASH_SOURCE[0]}")/../public/debian-install-demo.gif"
SetCols 100
SetRows 30
SetFontSize 20
SetTypingSpeed 0.035
SetPlaybackSpeed 0.5
SetLoop 'off'
SetLastFrameDuration 999

Start

Type 'ssh -i ~/.ssh/debian_comparison_admin_ed25519 -p 2222 admin@192.168.122.11'
Enter
Sleep 2.5
Key C-l

Show

Type 'sudo apt install -y fastfetch'
Enter
Wait 'Setting up fastfetch ' 60
Sleep 1.5
Key C-l

Type 'fastfetch'
Enter
Sleep 3

Render
