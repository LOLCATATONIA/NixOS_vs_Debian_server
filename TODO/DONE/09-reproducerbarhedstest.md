# Plan: Efterprøv reproducerbarhed konkret (byg to gange, diff hash)

**Status: gennemført og testet (2026-09-17). Resultat i bunden af filen.**

## Mål

Bevis empirisk, at NixOS' reproducerbarhedspåstand holder, i stedet for kun at påstå den i
rapporten.

**Vigtig præcisering, fundet under selve testen:** påstanden skal rettes mod *system-
konfigurationens* output-sti (det `nixos-rebuild switch`/`verify-deploy.sh` reelt sammenligner),
ikke mod det færdige `.#qcow`-diskimage som artefakt. De to opfører sig forskelligt, se resultatet.

## Hvorfor det er værd at gøre

Reproducerbarhed nævnes gentagne gange som en NixOS-fordel (modul 1, `00-tilgang.md`s
sammenligningstabel, `flake.lock`-argumentet), men er aldrig faktisk efterprøvet med et konkret
bevis. Det er den billigste post på hele listen at udføre, og den mest direkte anvendelse af
projektets egen etablerede metode: test påstanden, antag den ikke.

## Trin (som faktisk udført)

1. Byg `.#qcow` fra den nuværende `flake.lock` (`nix build .#qcow -L`), notér output-stien.
2. Slet `result`, byg igen. Output-stien var identisk, men det beviser reelt intet alene, Nix
   genkendte blot at outputtet allerede fandtes i `/nix/store` og genbyggede ikke fra bunden.
3. Brug i stedet Nix' indbyggede `--rebuild`-flag (`nix build .#qcow --rebuild -L`), som tvinger en
   ægte ny bygning og selv sammenligner den mod den eksisterende output-hash. Dette afslørede at
   `.#qcow` **ikke** er deterministisk, se resultat nedenfor.
4. Gentag samme `--rebuild`-test målrettet system-konfigurationen i stedet for diskimaget:
   `nix build ".#nixosConfigurations.linux101-srv.config.system.build.toplevel" --rebuild -L`.
5. Dokumentér begge resultater med fuld terminal-output som bevis, inklusiv det negative resultat
   for `.#qcow`, ikke kun det positive for konfigurationen.

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

## Resultat (testet 2026-09-17)

**`.#qcow` (diskimage): IKKE reproducerbart.**

```
$ nix build .#qcow --rebuild -L
...
error: derivation '/nix/store/b75md1fp132fx9sy5lq5z5vl2lmd9i4r-nixos-disk-image.drv' may not be
deterministic: output "/nix/store/4mk1dakmiskv3dmqhf759q1bkgn808lh-nixos-disk-image" differs
```

Årsag: `mkfs.ext4` genererer et nyt, tilfældigt filsystem-UUID for hver build af selve
diskimaget, allerede noteret som en kendt begrænsning i `docs/01-vm-og-netvaerk.md`. Det er ikke
konfigurationen, der afviger, det er en iboende egenskab ved diskimage-værktøjet.

**System-konfigurationen (det `verify-deploy.sh` reelt sammenligner): reproducerbar, verificeret.**

```
$ nix eval --raw ".#nixosConfigurations.linux101-srv.config.system.build.toplevel"
/nix/store/x38lab3zq77b9mxsn8br266df4m23vxd-nixos-system-linux101-srv-26.11.20260911.eaad089

$ nix eval --raw ".#nixosConfigurations.linux101-srv.config.system.build.toplevel"
/nix/store/x38lab3zq77b9mxsn8br266df4m23vxd-nixos-system-linux101-srv-26.11.20260911.eaad089

$ nix build ".#nixosConfigurations.linux101-srv.config.system.build.toplevel" --rebuild -L
checking outputs of '/nix/store/s5m1i4ff5six5w482jwli7b6sraj944n-...-nixos-system-...drv'...
```

Ingen "may not be deterministic"-fejl denne gang, samme output-sti begge gange, og Nix' eget
hash-tjek under tvunget genbygning bekræfter det.

**Konklusion, til brug i syntesen (`07`):** Reproducerbarheds-påstanden holder præcist for det, der
faktisk betyder noget i praksis, den deklarerede systemtilstand, som `nixos-rebuild`/
`verify-deploy.sh` bruger til at opdage afvigelse. Den holder ikke for et afledt build-artefakt
(diskimaget) med en iboende tilfældig komponent. Dette er en mere præcis og mere troværdig
konklusion end en ukvalificeret "NixOS er reproducerbart", fordi den viser at påstanden er testet,
ikke kun antaget, og at dens grænser er kendte.
