#!/usr/bin/env bash
#
# Optager en FULD genopbygning af nixos-comparison VM'en fra bunden: ./scripts/setup.sh
# river VM'en ned (hvis den findes), bygger et nyt diskimage fra flake.nix, og starter
# en frisk VM. Noget der slet ikke har et Debian-modstykke, derfor ingen side-om-side
# video her. Køres PÅ VÆRTEN, ikke via SSH. ~79 sekunder i virkeligheden, fremskyndet i
# selve optagelsen.
# Kræver: nix run nixpkgs#tmux, nixpkgs#asciinema, nixpkgs#asciinema-agg,
# nixpkgs#ffmpeg på PATH.

source "$(dirname "${BASH_SOURCE[0]}")/s-vhs.sh"

SetOutput "$(dirname "${BASH_SOURCE[0]}")/../public/full-rebuild-demo.gif"
SetCols 100
SetRows 22
SetFontSize 20
SetTypingSpeed 0.035
SetPlaybackSpeed 0.5
SetLoop 'off'
SetLastFrameDuration 999

Start
Show

Type 'cd ~/Desktop/projekter/Linux_101 && ./scripts/setup.sh'
Enter
Wait 'Færdig\.' 180
Sleep 2.5

Render
