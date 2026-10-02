#!/usr/bin/env bash
#
# Optager generationslisten live mod nixos-comparison: hver tidligere nixos-rebuild
# switch denne session har lavet, stadig intakt og nummereret. Kræver ikke sudo.
# SSH-login sker FØR Show kaldes, så selve login ikke optages.
# Noget der slet ikke har et Debian-modstykke, derfor ingen side-om-side video her.
# (Et ægte live generationsskifte blev forsøgt, men nixos-rebuild --rollback kræver
# den gamle kanal-baserede mekanisme, nix.conf-ændringer og en wildcard-sudoers-regel,
# der ville modsige projektets egen stramme, eksakt-match sudo-filosofi — for stor en
# pris for en enkelt demo, så listen alene bærer pointen.)
# Kræver: nix run nixpkgs#tmux, nixpkgs#asciinema, nixpkgs#asciinema-agg,
# nixpkgs#ffmpeg på PATH. VM'en skal være startet først.

source "$(dirname "${BASH_SOURCE[0]}")/s-vhs.sh"

SetOutput "$(dirname "${BASH_SOURCE[0]}")/../public/generations-demo.gif"
SetCols 130
SetRows 14
SetFontSize 16
SetTypingSpeed 0.035
SetLoop 'off'
SetLastFrameDuration 999

Start

Type 'ssh -i ~/.ssh/nixos_comparison_admin_ed25519 -p 2222 admin@192.168.122.10'
Enter
Sleep 2.5
Key C-l

Show

Type 'nixos-rebuild list-generations'
Enter
Sleep 4

Render
