#!/usr/bin/env bash
# Bygger index.html (til GitHub Pages, "branch: main, folder: /") fra report/*.md.
# Køres fra report/: ./build-html.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

pandoc 00-tilgang.md 01-vm-og-netvaerk.md 02-filsystem-og-adgangskontrol.md \
  03-brugere-og-grupper.md 04-firewall-og-netvaerkssikkerhed.md \
  05-overvaagning-og-logging.md 06-shell-og-bash-scripting.md \
  --standalone --toc --toc-depth=2 \
  --css=style.css \
  --syntax-highlighting=cyberpunk.theme \
  -o ../index.html

cp style.css ../style.css

python3 postprocess-html.py ../index.html

echo "Bygget: ../index.html (+ ../style.css)"
