---
title: "Linux 101"
subtitle: "Design, hærdning og overvågning af en Linux-server:  \nNixOS sammenlignet med Debian"
author: "Alexander Mangaard"
date: "17. september 2026"
---

# Overordnet tilgang og metodevalg

## Valg af virtualiseringsplatform: QEMU/KVM (libvirt) frem for VirtualBox/VMware

Før valget af gæste-styresystem skulle en hypervisor til værten (CachyOS) vælges. VirtualBox og
VMware Workstation er de mest udbredte alternativer, men QEMU/KVM (libvirt) er valgt for dets tætte
integration med Linux-værten og NixOS' eget værktøjsøkosystem.

| Aspekt | VirtualBox/VMware | QEMU/KVM (libvirt) |
|---|---|---|
| Arkitektur og ydeevne | Kører som et separat program oven på værtens OS og emulerer hardware i brugerrum, hvilket typisk giver mere overhead | KVM er indbygget i Linux-kernen og udnytter CPU'ens VT-x/AMD-V-udvidelser (Intel/AMDs hardware-understøttelse for virtualisering) direkte, tættere på native ydeevne |
| Scriptbarhed | CLI findes (`VBoxManage`), men værktøjet er primært bygget til den grafiske brugerflade | `virt-install`/`virsh` er fuldt scriptbare kommandolinjeværktøjer, uden en grafisk brugerflade som primær arbejdsgang |
| Licens/åbenhed | VirtualBox's kerne er GPL, men Extension Pack (USB 2/3, RDP) er proprietær. VMware Workstation er kommerciel | QEMU, KVM og libvirt er fuldt open source i alle dele, ingen separate proprietære tilføjelser |
| Brugervenlighed | Modent, grafisk værktøj med lav indlæringskurve, især med forudgående VirtualBox-erfaring | Kræver CLI-fortrolighed. `virt-manager` findes som GUI, men projektets daglige arbejdsgang er CLI-baseret |

**Delkonklusion:** QEMU/KVM via libvirt er valgt, primært fordi NixOS' eget værktøjsøkosystem
(`nixos-generators`, `nixos-rebuild build-vm`) er bygget direkte til QEMU — at vælge VirtualBox eller
VMware ville betyde at opgive den ubrudte "flake til kørende server"-arbejdsgang, som modul 1's
reproducerbarhedsargument bygger på, til fordel for en manuel eksport/import-proces. Dertil kommer en
fuldt åben værktøjskæde uden proprietære komponenter, i modsætning til VirtualBox' Extension Pack og
VMwares kommercielle licens (se tabellen ovenfor). Oplevelsesmæssigt er forskellen tydelig: uden
VirtualBox' grafiske feedback tager det længere at komme i gang, og de første `virsh`/`virt-install`-
kommandoer kræver at man selv slår ting op, som en GUI ellers ville have vist direkte. Den
omkostning betales dog kun én gang, til gengæld fås en ubrudt, scriptbar vej fra flake til kørende
server, som betaler sig igen og igen gennem resten af projektet.

## Deklarativ vs. imperativ, kort forklaret

En imperativ tilgang (af latin *imperare*, "at befale") beskriver de *handlinger*, systemet skal
udføre for at nå et resultat, fx `apt install vim git acl tealdeer`. En deklarativ tilgang (af
latin *declarare*, "at erklære") beskriver i stedet den *ønskede tilstand*, fx
`environment.systemPackages = with pkgs; [ vim git acl tealdeer ];`, den præcise linje fra dette
projekts egen `configuration.nix` (se "Samlet billede" nedenfor), og overlader det til systemet
selv at afgøre, hvilke handlinger der fører dertil. Forskellen er ikke antallet af trin, men hvad
der beskrives, handlingen eller tilstanden, og det er netop den forskel, der gennemgås modul for
modul i resten af rapporten.

## Valg af styresystem: NixOS frem for Debian/Ubuntu

Opgavebeskrivelsen foreslår Debian eller Ubuntu Server. Jeg har af læringsmæssige grunde valgt at
benytte **NixOS** og vil for hvert modul argumentere både fordele og ulemper ved den deklarative
tilgang sammenlignet med den traditionelle, imperative arbejdsgang, som opgaven er skrevet ud fra.

| Aspekt | Traditionel (Debian/Ubuntu) | NixOS |
|---|---|---|
| Konfiguration | Frit redigerbare filer i `/etc`, ingen indbygget versionsstyring, kan derfor afvige uden at nogen opdager det | Deklareret i `configuration.nix`, genereret ved hver rebuild, naturligt versionsstyrbar i git |
| Opgraderinger | Kan fejle midtvejs og efterlade systemet i en inkonsistent tilstand | Bygget som en samlet, fuldt evalueret generation før aktivering; en fejlkonfiguration kan rulles tilbage til en tidligere generation ved reboot |
| Reproducerbarhed | Kræver ekstra værktøj (fx Packer/Ansible) for at være pålideligt reproducerbar | Indbygget via `flake.lock`, som fastlåser præcise versioner af alle pakker |
| Pakke-integritet | Muterbart filsystem for installerede pakker | Skrivebeskyttet, indholdsadresseret `/nix/store` |
| Hærdningsøkosystem (CIS/STIG) | Officielle CIS Benchmarks og OpenSCAP-profiler findes direkte til Debian, klar til brug | Ingen officielle CIS/STIG-benchmarks for NixOS; tilsvarende hærdning skal udtrykkes manuelt i `configuration.nix`, modul for modul |

**CIS Benchmarks** er branchestandard-tjeklister for sikker konfiguration af et givet system;
**OpenSCAP** er et værktøj, der automatisk kan afprøve en maskine mod sådanne tjeklister; **STIG**
(Security Technical Implementation Guide) er den amerikanske forsvarsstandards udgave af det samme.

**Delkonklusion:** NixOS er valgt, fordi de arkitektoniske fordele, reproducerbarhed, rollback til en
tidligere, fuldt bygget generation, og umuliggørelse af konfigurationsafvigelse, er direkte relevante
sikkerhedsegenskaber, opnået ved at automatisere hele systemtilstanden i stedet for at stole på
manuelle, gentagne trin. En **generation** er her et komplet, navngivet øjebliksbillede af systemets
tilstand, valgbart som en boot-menu-post, ikke blot en logisk betegnelse. I praksis er forskellen
dog ikke entydigt en fordel: NixOS kræver et
reelt paradigmeskifte, fra at tænke i en *sekvens af kommandoer* til at tænke i en *deklareret
sluttilstand*, og en fejl i konfigurationen viser sig ofte som en kryptisk Nix-evalueringsfejl, hvor
den traditionelle tilgangs fejlmeddelelser (fra `useradd`, `systemctl`, `ufw`) typisk er mere
umiddelbart genkendelige. Hvor NixOS' arbejdsgang adskiller sig væsentligt fra Debians, dokumenteres
eksplicit hvad forskellen konkret er, og hvorfor den deklarative løsning vurderes som ligeværdig
eller stærkere, side om side i hvert modul.

### Konkret: selve installationsprocessen side om side

Før den strukturelle pointe nedenfor, et konkret eksempel på hvad forskellen betyder i praksis, den
faktiske kommando, der starter installationen på hver platform:

::: {.compare}
::: {.compare-side}
#### Traditionel: en interaktiv installer, forhåndsudfyldt

```bash
$ virt-install --location debian-13.7.0-amd64-netinst.iso \
    --initrd-inject=preseed.cfg \
    --extra-args "auto=true priority=critical console=ttyS0" \
    --disk size=8,format=qcow2,bus=virtio \
    --network network=default,model=virtio \
    --graphics none --console pty,target_type=serial \
    --os-variant generic
```
:::
::: {.compare-side}
#### NixOS: intet installationstrin

```bash
$ nix build .#qcow -L
$ virt-install --name nixos-comparison --memory 3072 --vcpus 2 \
    --disk vol=default/nixos-comparison.qcow2,bus=virtio \
    --network network=default,model=virtio \
    --graphics none --console pty,target_type=serial \
    --import --os-variant generic --noautoconsole
```
:::
:::

`--location` peger stadig på en rigtig installer, blot forhåndsudfyldt med `preseed.cfg`, en
netinst-wizard kører stadig, blot uden at stoppe for input undervejs. `--import` har intet sådant
trin overhovedet: imaget er allerede et komplet, konfigureret system. Denne forskel er ikke kun
kosmetisk, Debians installer forsøger som udgangspunkt DHCP under netværksopsætningen, medmindre
den preseedes til statisk IP, en afhængighed der reelt forsinkede opsætningen af
`debian-comparison` (se modul 1's Delkonklusion for den fulde fejlfindingshistorie). NixOS' `--import`
kan aldrig ramme den klasse af problem, fordi der ikke findes en installationsfase, der afhænger af
noget netværksprotokol overhovedet.

### Samlet billede: spredte konfigurationsfiler vs. én `configuration.nix`

"Konfiguration"-rækken ovenfor gælder for hele projektet på én gang. På en traditionel
Debian-server er de seks moduler spredt over mindst otte forskellige filer og kommandoer:

| Modul | Traditionelt spredt over | Samlet i NixOS |
|---|---|---|
| 1: Netværk og SSH | `/etc/hostname`, `/etc/network/interfaces`, `/etc/ssh/sshd_config`, `~/.ssh/authorized_keys` | `nixos/modules/network.nix` |
| 2: Filsystem og adgangskontrol | Ingen konfigurationsfil, kun ad-hoc `mkdir`/`chown`/`chmod`-kommandoer | `nixos/modules/filesystem.nix` |
| 1 og 3: Brugere | `/etc/passwd`, `/etc/shadow`, `/etc/group` (via `useradd`/`passwd`) | `nixos/modules/users.nix` |
| 3: Sudo | `/etc/sudoers.d/*` | `nixos/modules/users.nix` |
| 4: Firewall | `/etc/ufw/*` | `nixos/modules/firewall.nix` |
| 5: Overvågning | Bruger-crontab, et separat script i `/usr/local/bin`, `/etc/logrotate.d/monitor` | `nixos/modules/monitoring.nix` |

Alt dette samles i én `configuration.nix`, der importerer de fem modulfiler:

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./modules/network.nix
    ./modules/users.nix
    ./modules/filesystem.nix
    ./modules/firewall.nix
    ./modules/monitoring.nix
  ];

  system.stateVersion = "24.05";

  environment.systemPackages = with pkgs; [
    vim
    git
    acl
    tealdeer
  ];
}
```

`nixos-rebuild switch`
bygger hele den ønskede konfiguration som én samlet, identificerbar generation, som derefter
aktiveres. Selve aktiveringen (genstart af tjenester m.v.) er ikke en databasetransaktion, men
resultatet er en generation, der kan rulles tilbage som en samlet enhed. På en traditionel server
findes intet tilsvarende: hver fil redigeres og genindlæses for sig, uden noget objekt der
repræsenterer hele systemets konfiguration som én genskabelig enhed.

## Flake-arkitektur og reproducerbarhed

En **flake** er Nix' standardiserede projektformat: en `flake.nix`-fil, der deklarerer et projekts
*inputs* (afhængigheder, fx en bestemt version af nixpkgs) og *outputs* (hvad der bygges, fx en
NixOS-konfiguration), evalueret i et isoleret miljø uafhængigt af lokale miljøvariabler. Den
tilhørende `flake.lock`-fil fastlåser den præcise version af hvert input, så to bygninger fra samme
flake giver identisk resultat, hvilket er grundlaget for hele projektets reproducerbarhedsargument.
Flakes er teknisk set stadig en eksperimentel Nix-funktion, selvom de reelt er de
facto-standarden i økosystemet. Derfor skal de aktiveres eksplicit med
`--extra-experimental-features "nix-command flakes"` (synligt i `verify-deploy.sh`, modul 6).

::: {.compare}
::: {.compare-side}
#### Debian: gælder ikke

Pakker installeret via `apt` har intet indholdsadresseret hash at genbygge og sammenligne mod, en
`.deb`-pakkes indhold er hvad vedligeholderen uploadede, ikke noget der genbygges lokalt og
verificeres. Reproducerbarhed i denne tekniske forstand er derfor ikke et begreb, der findes på
Debian-siden af denne sammenligning.
:::
::: {.compare-side}
#### NixOS: reproducerbarheden er efterprøvet, ikke kun antaget

Nix' `--rebuild`-flag tvinger en ægte gentagen bygning og sammenligner selv output-hashen mod den
eksisterende:

```
# evaluerer den deklarerede sti, uden at bygge noget
$ nix eval --raw ".#nixosConfigurations.nixos-comparison.config.system.build.toplevel"
/nix/store/8dnnc5bimgv0hza6rwlv1chfgkvy56c2-nixos-system-nixos-comparison-...
# tvinger en ægte ny bygning, sammenligner selv hash mod ovenstående
$ nix build ".#nixosConfigurations.nixos-comparison.config.system.build.toplevel" --rebuild -L
checking outputs of '/nix/store/kq5cfysipkzm3isli5353axyw50gd100-...-nixos-system-...drv'...
```

Ingen "may not be deterministic"-fejl ved en tvunget, ægte genbygning: selve systemkonfigurationen
er reproducerbar. Det gælder derimod **ikke** det færdige `.qcow`-diskimage som artefakt:

```
# samme test, nu på selve diskimaget i stedet for konfigurationen
$ nix build .#qcow --rebuild -L
error: derivation '.../nixos-disk-image.drv' may not be deterministic: output
".../nixos-disk-image" differs
```

Årsagen er `mkfs.ext4`, som genererer et nyt, tilfældigt filsystem-UUID for hver bygning af selve
diskimaget, en iboende egenskab ved diskimage-værktøjet, ikke et tegn på at selve konfigurationen
afviger. Konklusionen er derfor mere præcis end en ukvalificeret "NixOS er reproducerbart": det
gælder for den deklarerede systemtilstand, som reelt betyder noget for drift og verifikation
(`verify-deploy.sh`, modul 6), men ikke for et afledt build-artefakt med en iboende tilfældig
komponent.
:::
:::

VM'en køres under QEMU/KVM via libvirt på en CachyOS-vært, og opbygges i tre faser:

1. **Bootstrap:** `flake.nix` definerer hele serverens konfiguration. `nix build .#qcow` bygger et
   qcow2-diskimage direkte fra flaken; `virt-install --import` opretter VM'en i libvirt fra dette
   image. Hele processen er én reproducerbar kommandosekvens uden manuelle installationstrin. Se
   [`scripts/setup.sh`](scripts/setup.sh).
2. **Iteration:** Ændringer laves ved at redigere `.nix`-filerne, kopiere flake-kilden til VM'en
   (`~/nixos-comparison-config`), og køre `sudo nixos-rebuild switch --flake ~/nixos-comparison-config`
   lokalt på serveren.
3. **Sikkerhedsnet:** Før en risikabel ændring (fx firewall/sudo) deployes, testes den lokalt med
   `nixos-rebuild build-vm`, som bygger en midlertidig, isoleret test-VM uden at røre den rigtige
   server.

VM'en tildeles 2 vCPU og 3 GB RAM. Diskstørrelsen bestemmes automatisk af `nixos-generators`' qcow-
format (se tabel og forklaring nedenfor).

### Begge VM'er, side om side

Ud over `nixos-comparison` køres der til denne rapport også en **rigtig** Debian-VM
(`debian-comparison`), opsat i hånden efter den traditionelle, imperative arbejdsgang, på nøjagtig
samme QEMU/KVM/libvirt-grundlag. Formålet er at gøre sammenligningerne i modul 1-6 til en reel,
efterprøvet A/B-test i stedet for kun en teoretisk modstilling.

<table>
<thead>
<tr><th>Aspekt</th><th>Debian (<code>debian-comparison</code>)</th><th>NixOS (<code>nixos-comparison</code>)</th></tr>
</thead>
<tbody>
<tr><td>Diskimage</td><td><code>/var/lib/libvirt/images/debian-comparison.qcow2</code></td><td><code>/var/lib/libvirt/images/nixos-comparison.qcow2</code></td></tr>
<tr><td>Diskstørrelse</td><td>8,00 GiB</td><td>4,83 GiB</td></tr>
<tr><td>Statisk IP</td><td><code>192.168.122.11</code></td><td><code>192.168.122.10</code></td></tr>
<tr><td>vCPU / RAM</td><td colspan="2" style="text-align:center">2 vCPU / 3072 MB (begge, for en fair sammenligning)</td></tr>
<tr><td>SSH-port</td><td colspan="2" style="text-align:center">2222 (begge)</td></tr>
<tr><td>libvirt-netværk</td><td colspan="2" style="text-align:center"><code>default</code> (NAT-bro <code>virbr0</code>, gateway <code>192.168.122.1</code>)</td></tr>
<tr><td>Root-adgang (konsol)</td><td><code>root</code> / <code>comparison-temp-pw</code>, kun via <code>virsh console</code></td><td>Ingen adgangskode sat, login umuligt (<code>hashedPassword = "!"</code>)</td></tr>
</tbody>
</table>

Diskstørrelsen er den eneste reelle asymmetri, og selve årsagen til forskellen er et lille eksempel
på projektets egen pointe: NixOS' størrelse er slet ikke et valg, den er en **automatisk** konsekvens
af `nixos-generators`' `qcow`-format, som selv beregner diskstørrelsen ud fra det deklarerede
systems **closure** (hele det udregnede træ af pakker og filer, systemet reelt kræver for at køre).
`DISK_SIZE_BYTES` i `scripts/setup.sh` er blot den *målte* byte-størrelse af det allerede byggede
image. Debians `size=8` (GiB) i `virt-install`-kommandoen var derimod et
**manuelt**, rundt tal valgt på forhånd til en traditionel netinst-installation. vCPU og RAM er
derimod identiske på begge VM'er,
netop for at sammenligningerne i modul 1-6 måler platformsforskelle, ikke forskelle i tildelte
ressourcer.

## Repo-struktur

```
Linux_101/
├── report/                    (denne rapport)
├── flake.nix, flake.lock      (pinner nixpkgs, definerer VM'ens konfiguration)
├── nixos/
│   ├── configuration.nix
│   ├── hardware-vm.nix
│   └── modules/
│       ├── network.nix        (modul 1)
│       ├── users.nix          (modul 1 og 3)
│       ├── filesystem.nix     (modul 2)
│       ├── firewall.nix       (modul 4)
│       └── monitoring.nix     (modul 5)
└── scripts/
    ├── setup.sh                (modul 6)
    ├── healthcheck.sh          (modul 6)
    ├── monitor.sh              (modul 5)
    └── verify-deploy.sh        (modul 6)
```
