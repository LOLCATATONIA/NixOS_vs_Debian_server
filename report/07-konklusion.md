# Konklusion

Rapporten har sammenlignet en traditionel, imperativ Debian-server med en deklarativ
NixOS-server, opsat til de samme seks opgaver på to virtuelle maskiner.

## Fordele

::: {.compare}
::: {.compare-side}
#### Debian

- **Nødspor:** `root` kan nås via konsollen, hvis en `sudo`-regel er forkert (modul 3).
- **Direkte redigering:** en ny regel er én linje i `sudoers.d` eller ét `ufw`-kald
  (modul 3, 4).
:::
::: {.compare-side}
#### NixOS

- **Verificerbar tilstand:** `verify-deploy.sh` kan afgøre, om det kørende system svarer
  til det erklærede. Debian har intet tilsvarende (modul 6).
- **Afvisning ved build:** en ugyldig `sudoers`-regel afvises, før den aktiveres (modul 3).
- **Indbygget idempotens:** `nixos-rebuild switch` kræver ingen selvskrevne tjek, og der er
  ingen installationsfase (modul 6, 1).
- **Kompakt firewall:** samme politik i 33 linjer og 4 chains mod ufw's 386 og 69 (modul 4).
:::
:::

## Ulemper

::: {.compare}
::: {.compare-side}
#### Debian

- **Spredt tilstand:** mindst otte filer og kommandotyper, og ingen facitliste at holde
  serveren op imod (se
  [Samlet billede](#samlet-billede-spredte-konfigurationsfiler-vs.-én-configuration.nix),
  modul 6).
- **Manuel validering:** `provision.sh` manglede `visudo -c` efter de senere
  sudoers-tilføjelser (modul 6).
- **Ad hoc-vækst:** `sudo`-regler uden argumentbegrænsning er bredere end tilsigtet, og
  `admin` endte i `projekt`-gruppen (modul 3).
- **Faldgruber under opsætning:** `useradd -G` mod `-g`, og en værts-`ufw`-regel, der
  blokerede DHCP under installationen (modul 3, 1).
:::
::: {.compare-side}
#### NixOS

- **Ekstra fejlfindingslag:** `sudo -l` så korrekt ud, men deploy fejlede. `#` i en
  flake-reference afkorter sudoers-linjen. `openFirewall` åbnede SSH for alle kilder trods
  kilde-IP-regel, og `rpfilter` blokerede DNS-svar. Ingen af dem viste sig ved at læse
  konfigurationen alene (modul 3, 4).
- **Stift `sudo` uden nødspor:** hverken adgangskode eller root-fallback (modul 3).
- **Reproducerbarhed med grænse:** gælder systemkonfigurationen, ikke diskimaget (se
  [Flake-arkitektur og reproducerbarhed](#flake-arkitektur-og-reproducerbarhed)).
:::
:::

**Ingen forskel:** ACL og filrettigheder (modul 2) og selve `sudoers`-mekanikken (modul 3).

NixOS gør det muligt at verificere kørende tilstand og afviser fejl ved build, til prisen af
et ekstra lag at fejlsøge og et stift `sudo`-regelsæt uden nødspor. Debian beholder nødsporet
og direkte redigering, til prisen af spredt, uverificerbar tilstand og manuelle tjek.
