# Plan: Efterprøv reproducerbarhed konkret (byg to gange, diff hash)

## Mål

Bevis empirisk, at `nix build .#qcow` fra samme commit giver bit-for-bit identisk output, i stedet
for kun at påstå reproducerbarhed i rapporten.

## Hvorfor det er værd at gøre

Reproducerbarhed nævnes gentagne gange som en NixOS-fordel (modul 1, `00-tilgang.md`s
sammenligningstabel, `flake.lock`-argumentet), men er aldrig faktisk efterprøvet med et konkret
bevis. Det er den billigste post på hele listen at udføre, og den mest direkte anvendelse af
projektets egen etablerede metode: test påstanden, antag den ikke.

## Trin

1. Byg `.#qcow` fra den nuværende `flake.lock` (`nix build .#qcow -L`), notér output-stien i
   `/nix/store` og dens hash.
2. Slet `result`-symlinket, ryd eventuel lokal build-cache der kunne snyde resultatet, og byg igen
   fra samme commit.
3. Sammenlign de to output-stier direkte, de bør være identiske (samme hash i stinavnet), da
   NixOS' output-stier er indholdsadresserede.
4. Dokumentér resultatet med begge kommandoers fulde output som bevis, samme stil som resten af
   projektets "bevis, testet direkte"-afsnit.
5. (Stretch) Gentag på tværs af en lille tidsforskydning (byg i dag, byg igen om et par dage), for
   at vise at reproducerbarheden holder over tid, ikke kun i samme terminal-session.

## Den strukturelle kontrast (skal med, ikke kun NixOS' eget bevis isoleret)

Beviset er kun halvt så stærkt, hvis det står alene. Tilføj en kort, eksplicit forklaring af hvorfor
det samme ikke kan garanteres på Debian uden ekstra værktøj: `apt install <pakke>=<version>` pinner
kun pakkeVERSION, ikke de faktiske build-inputs eller den binære oprindelse. To installationer af
"samme" version, foretaget på forskellige tidspunkter eller fra forskellige spejle, er derfor ikke
garanteret at give identisk resultat. Nix' indholdsadresserede `/nix/store` og `flake.lock`
fastlåser derimod hele afhængighedstræet, ikke kun et versionsnummer. Denne kontrast, ikke kun
NixOS' eget positive resultat, er selve pointen med at inkludere testen i tesen. Se evt.
`08-debian-ab-sammenligning.md`s tilsvarende forsøg på Debian-siden for et konkret modstykke.

## Estimeret indsats

Lav. Kan sandsynligvis gennemføres på under en time, inklusiv dokumentation.

## Åbne spørgsmål

- Skal dette også testes på tværs af to forskellige maskiner (fx værten og en anden computer), for
  et endnu stærkere bevis? Kræver adgang til en anden maskine med Nix installeret.
