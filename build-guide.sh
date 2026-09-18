#!/usr/bin/env bash
# Bygger guide.html fra guide.md, genbruger rapportens stil og efterbehandling.
# Driftsguide til at demonstrere begge VM'er, ikke en del af selve afleveringen.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

pandoc guide.md \
  --standalone --toc --toc-depth=2 \
  --css=style.css \
  --syntax-highlighting=report/cyberpunk.theme \
  -o guide.html

python3 report/postprocess-html.py guide.html
# postprocess-html.py retter billedstier til "report/screenshots/", irrelevant her (guide.md har
# ingen billeder), så ingen efterbehandling nødvendig udover selve sammenligningsblok-undtagelsen.

echo "Bygget: guide.html"
