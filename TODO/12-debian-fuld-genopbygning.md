# Plan: Kan Debian nærme sig NixOS' ét-script fuld genopbygning?

**Status: åbent spørgsmål, ikke undersøgt endnu.** Opstået fra `guide.md`s "Hvis noget går grueligt
galt: fuld genopbygning"-afsnit, som pt. konkluderer at der "ikke er bygget et enkelt script" for
Debian-siden. Det var sandt, da det blev skrevet (`preseed`-installationen var stadig ustabil), men
er det stadig sandt nu, hvor selve rodårsagen (`ufw`, ikke QEMU/STP/NIC) er fundet og rettet?

## Spørgsmålet, præcist formuleret

Hvis man ønsker at nærme sig NixOS' `./scripts/setup.sh` (én kommando, riv ned og genskab fra
bunden, idempotent), kan man overhovedet opnå noget tilsvarende med Debian, og i så fald hvordan?
Ikke "er det lige så elegant" (det bliver det næppe), men konkret: kan det *lade sig gøre*, og hvad
kræver det?

## Hvorfor det er værd at undersøge nu, ikke tidligere

Vi har nu, efter `ufw`-fundet, faktisk alle byggestenene liggende adskilt:

1. En **fungerende** preseed-baseret installation (`~/debian-comparison/preseed.cfg`, med statisk
   IP, ikke DHCP, se `DONE/08-log-debian-vs-nixos-install.md`).
2. Et **testet, delvist idempotent** provisioneringsscript (`08-debian-provision.sh`), der dækker
   modul 1-5.

Spørgsmålet er, om disse to kan kædes sammen til ÉT script, der reelt efterligner `setup.sh`s
arbejdsgang: riv VM'en ned, genskab basen fra preseed, kør provisioneringen, verificér.

## Trin

1. **Skriv en samlende `rebuild-debian.sh`** (på værten), der:
   - Destroyer/undefiner den eksisterende `debian-comparison`-VM (som `setup.sh` gør for
     `linux101-srv`).
   - Genkører `virt-install --location` med `preseed.cfg` (nu med den rettede `ufw`-regel på
     værten som forudsætning, ikke noget scriptet selv kan løse, se punkt "Åbne spørgsmål").
   - Venter på at installationen er færdig og VM'en er tilgængelig via SSH (poll-loop, ikke en fast
     `sleep`).
   - Kopierer og kører `08-debian-provision.sh` (+ `monitor.sh`) via SSH/konsol.
2. **Test det reelt, mindst to gange i træk**, samme metode som `DONE/09-reproducerbarhedstest.md` og
   `08-debian-provision.sh`s egen idempotens-verifikation. Mål tiden, samme stil som
   `10-disaster-recovery-maaling.md`, så de to platformes RTO kan sættes direkte op mod hinanden.
3. **Dokumentér ærligt hvor det stadig halter**, uanset om det lykkes. Sandsynlige kandidater:
   - Selve installations-fasen er markant langsommere end NixOS' `nix build .#qcow` (pakker hentes
     over netværket for hver installation, ikke fra en lokal, indholdsadresseret cache).
   - Scriptet kan næppe være lige så robust over for delvise fejl midtvejs (en afbrudt `apt-get
     install` efterlader systemet i en ukendt tilstand, `nixos-rebuild` gør ikke).
   - Der er stadig et host-side-afhængighed (`ufw`-reglen på selve værten), som intet Debian-VM-side
     script kan rette selv, det ligger uden for VM'ens egen konfiguration. NixOS-siden har en
     tilsvarende host-afhængighed (libvirt/`virt-install` selv), men ikke en ekstra,
     opdaget-ved-et-tilfælde brandmursregel oveni.

## Estimeret indsats

Middel. De to byggesten findes allerede og er hver for sig testet, selve sammenkædningen og en ny
runde verificering er hovedarbejdet, ikke ny forskning fra bunden.

## Åbne spørgsmål

- Skal scriptet forudsætte at værtens `ufw`-regel allerede er sat (dokumenteret forudsætning,
  ligesom NixOS-siden har forudsætninger til værten), eller skal scriptet selv forsøge at sætte
  den (kræver værts-sudo, en anden slags afhængighed end noget NixOS-siden nogensinde har krævet)?
- Hvis rebuild-scriptet lykkes, ændrer det konklusionen i `guide.md`s "intet tilsvarende script
  findes"-afsnit, og bør formentlig erstatte den med et mere nuanceret svar, "det kan lade sig
  gøre, men er langsommere og mindre robust", i stedet for "findes ikke".
