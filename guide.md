---
title: "Driftsguide"
subtitle: "nixos-comparison (NixOS) og debian-comparison (Debian), side om side"
---

**Vigtigst at forstå:** Der er nu **tre** steder, en kommando kan køres: værten, NixOS-VM'en
(`nixos-comparison`), eller Debian-VM'en (`debian-comparison`). Hver kommando nedenfor er mærket
`[vært]`, `[nixos-vm]` eller `[debian-vm]`, aldrig blandet.

**Sådan tjekker du hvor du er:**

```bash
hostname
```

- `cachyos-x8664` → du er på **værten**.
- `nixos-comparison` → du er på **NixOS-VM'en**.
- `debian-comparison` → du er på **Debian-VM'en** (hed oprindeligt `debian-tmp`, det midlertidige
  navn fra preseed-installationen, blev aldrig rettet, før det blev opdaget og rettet manuelt,
  se `TODO/DONE/08-log-debian-vs-nixos-install.md`, et lille, ægte eksempel på konfigurationsafvigelse:
  den *tiltænkte* tilstand og den *faktiske* tilstand var et stykke tid ikke identiske).

**I tvivl om hvor mange niveauer du er "inde"?** Åbn et nyt terminalvindue. Det starter altid på
værten.

## SSH-adgang

::: {.compare}
::: {.compare-side}
#### Debian: `debian-comparison` (192.168.122.11)

```bash
ssh -i ~/.ssh/debian_comparison_admin_ed25519 -p 2222 admin@192.168.122.11
```

Andre roller:
```bash
ssh -i ~/.ssh/debian_comparison_developer_ed25519 -p 2222 developer@192.168.122.11
ssh -i ~/.ssh/debian_comparison_guest_ed25519 -p 2222 guest@192.168.122.11
```
:::
::: {.compare-side}
#### NixOS: `nixos-comparison` (192.168.122.10)

```bash
ssh -i ~/.ssh/nixos_comparison_admin_ed25519 -p 2222 admin@192.168.122.10
```

Andre roller:
```bash
ssh -i ~/.ssh/nixos_comparison_developer_ed25519 -p 2222 developer@192.168.122.10
ssh -i ~/.ssh/nixos_comparison_guest_ed25519 -p 2222 guest@192.168.122.10
```
:::
:::

Begge VM'er: ingen adgangskoder findes nogen steder (alle konti password-låste, `root` uden gyldig
hash), kun nøglebaseret login, kun fra `192.168.122.1` (værten selv), kun på port `2222`.

## VM-status og livscyklus

**[vært]**

```bash
sudo virsh list --all
sudo virsh start nixos-comparison        # eller: debian-comparison
sudo virsh shutdown nixos-comparison     # ordentlig nedlukning
```

**Direkte konsol-adgang** (eneste vej ind som `root`, siden `root` ikke kan SSH'e på nogen af
VM'erne):

```bash
sudo virsh console nixos-comparison      # eller: debian-comparison
```
Kommandoen ovenfor beder om login. På **Debian**-VM'en: brugernavn `root`, adgangskode
`comparison-temp-pw` (sat under selve installationen). På **NixOS**-VM'en findes der slet ingen
adgangskode at logge ind med, `root` er helt låst (`hashedPassword = "!"`), heller ikke via
konsollen, kun `admin`/`developer`/`guest` kan tilgås, og kun via SSH-nøgle.

## Fejlfinding

**"Identity file ... not accessible" / "Permission denied (publickey)" med det samme:** Kør
`hostname`, kommandoen blev sandsynligvis kørt fra en VM i stedet for fra værten.

**"No route to host":** VM'en er sandsynligvis slukket.
```bash
# [vært]
sudo virsh list --all
sudo virsh start nixos-comparison        # eller: debian-comparison
```

**SSH hænger, eller kan slet ikke forbinde, men VM'en kører:** Forældet `known_hosts`-indgang
(sker efter genopbygning af en VM fra bunden):
```bash
# [vært]
ssh-keygen -R '[192.168.122.10]:2222'    # NixOS
ssh-keygen -R '[192.168.122.11]:2222'    # Debian
```

Fjerner den gemte, forældede værtsnøgle for den pågældende IP+port fra `~/.ssh/known_hosts`. En
genopbygget eller geninstalleret VM får altid en ny værtsnøgle, men din lokale `known_hosts`-fil
husker stadig den gamle, hvilket får SSH til at nægte forbindelse med en alvorlig sikkerheds-
advarsel, indtil den forældede indgang fjernes. Sket i praksis for begge VM'er under selve
projektet, ikke kun en teoretisk mulighed.

## Når du er logget ind

::: {.compare}
::: {.compare-side}
#### Debian

```bash
sudo -l                          # hvad admin må som root
sudo ufw status verbose          # firewall-status
sudo nft list ruleset            # samme kommando virker også (ufw's backend)
bash /tmp/healthcheck.sh         # samme, uændrede script som NixOS-siden
```
:::
::: {.compare-side}
#### NixOS

```bash
sudo -l                          # hvad admin må som root
sudo nft list ruleset            # firewall-status
~/nixos-comparison-config/scripts/healthcheck.sh
~/nixos-comparison-config/scripts/verify-deploy.sh
```
:::
:::

`healthcheck.sh` er bevidst identisk på begge platforme, det er selve pointen med rapportens
påstand om at scriptet er almindelig, portabel bash. Der findes intet Debian-modstykke til
`verify-deploy.sh`, fordi der ikke findes noget at sammenligne en "kørende tilstand" med, en
traditionel server har ingen deklareret, evaluerbar facitliste at holde op imod.

## Deploy en konfigurationsændring

::: {.compare}
::: {.compare-side}
#### Debian: ingen tilsvarende, generel vej

`admin`s sudo-rettigheder er granulære og opremsede (se `sudo -l`), ikke ét universelt
"anvend hele den ønskede tilstand"-kald. En helt ny slags ændring kræver enten:

1. Direkte konsol-adgang som `root` (se ovenfor), eller
2. En ny, eksplicit linje i `/etc/sudoers.d/admin` for netop den kommando, hvilket i sig selv
   kræver adgang som `root` at tilføje.

```bash
# [vært], kopiér opdateret script over
scp -i ~/.ssh/debian_comparison_admin_ed25519 -P 2222 \
  debian-comparison/provision.sh scripts/monitor.sh \
  admin@192.168.122.11:/tmp/
```
```bash
# [debian-vm], via konsol som root, IKKE via SSH som admin
bash /tmp/provision.sh
```
:::
::: {.compare-side}
#### NixOS: én kommando, uanset ændringens omfang

```bash
# [vært]
scp -i ~/.ssh/nixos_comparison_admin_ed25519 -P 2222 -r flake.nix flake.lock nixos scripts \
  admin@192.168.122.10:~/nixos-comparison-config/
```
```bash
# [nixos-vm]
sudo nixos-rebuild switch --flake ~/nixos-comparison-config
```
Dette er den eneste `nixos-rebuild`-kommando, `admin` må køre, men den kan udtrykke *enhver*
ændring, der er beskrevet i `configuration.nix`.
:::
:::

**Dette er ikke et mindre praktisk problem, det er en strukturel forskel:** NixOS' granulære sudo
kan alligevel udtrykke vilkårlige ændringer, fordi den ene tilladte kommando (`nixos-rebuild
switch`) selv læser en fuldstændig, deklareret tilstand. Debians granulære sudo er *reelt*
begrænset til den opremsede kommandoliste, en helt ny opgave kræver altid en administrativ
udvidelse af listen først. Se `TODO/07-syntese-nixos-fremtidens-valg.md`.

## Hvis noget går grueligt galt: fuld genopbygning

::: {.compare}
::: {.compare-side}
#### Debian: intet tilsvarende script findes

Der er ikke bygget et enkelt "riv ned og genskab helt fra bunden"-script for Debian-VM'en, fordi
selve installationsprocessen (preseed + `virt-install --location`) er den skrøbelige, tidskrævende
del af hele forsøget (se `TODO/DONE/08-log-debian-vs-nixos-install.md`). Fuld genopbygning betyder i
praksis at gentage hele installationsforløbet forfra, ikke køre én kommando.
:::
::: {.compare-side}
#### NixOS: ét, idempotent script

```bash
# [vært]
./scripts/setup.sh
```
Sletter og genskaber VM'en fra `flake.nix`. Al imperativ tilstand (fx testfiler fra modul 2)
forsvinder og skal genskabes manuelt bagefter.
:::
:::
