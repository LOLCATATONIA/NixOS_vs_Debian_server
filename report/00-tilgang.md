---
title: "Linux 101"
subtitle: "Design, hærdning og overvågning af en Linux-server:  \nNixOS sammenlignet med Debian"
author: "Alexander Mangaard"
date: "16. september 2026"
---

# Overordnet tilgang og metodevalg

## Valg af virtualiseringsplatform: QEMU/KVM (libvirt) frem for VirtualBox/VMware

Før valget af gæste-styresystem skulle en hypervisor til værten (CachyOS) vælges. VirtualBox og
VMware Workstation er de mest udbredte alternativer, men QEMU/KVM (libvirt) er valgt for dets tætte
integration med Linux-værten og NixOS' eget værktøjsøkosystem.

| Aspekt | VirtualBox/VMware | QEMU/KVM (libvirt) |
|---|---|---|
| Arkitektur og ydeevne | Kører som et separat program oven på værtens OS og emulerer hardware i brugerrum, hvilket typisk giver mere overhead | KVM er indbygget i Linux-kernen og udnytter CPU'ens VT-x/AMD-V-udvidelser direkte, tættere på native ydeevne |
| Scriptbarhed | CLI findes (`VBoxManage`), men værktøjet er primært bygget til den grafiske brugerflade | `virt-install`/`virsh` er fuldt scriptbare kommandolinjeværktøjer, i tråd med opgavens egen vægt på "scriptet, ikke klikket sammen" |
| Licens/åbenhed | VirtualBox's kerne er GPL, men Extension Pack (USB 2/3, RDP) er proprietær. VMware Workstation er kommerciel | QEMU, KVM og libvirt er fuldt open source i alle dele, ingen separate proprietære tilføjelser |
| Brugervenlighed | Modent, grafisk værktøj med lav indlæringskurve, især med forudgående VirtualBox-erfaring | Kræver CLI-fortrolighed. `virt-manager` findes som GUI, men projektets daglige arbejdsgang er CLI-baseret |

**Konklusion:** QEMU/KVM via libvirt er valgt, primært fordi NixOS' eget værktøjsøkosystem
(`nixos-generators`, `nixos-rebuild build-vm`) er bygget direkte til QEMU. At vælge VirtualBox eller
VMware ville have betydet at opgive den ubrudte "flake til kørende server"-arbejdsgang, som hele
modul 1's reproducerbarhedsargument bygger på, til fordel for en manuel eksport/import-proces. Dertil
kommer en fuldt åben værktøjskæde (Nix, NixOS, QEMU, KVM, libvirt) uden proprietære komponenter, som
afspejler den samme "åbenhed og gennemsigtighed" opgaven selv fremhæver som en styrke ved Linux. Den
reelle omkostning er en stejlere indlæringskurve, men til gengæld fås en ubrudt, scriptbar vej fra
flake til kørende server og et fuldt åbent værktøjsøkosystem hele vejen igennem.

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
| Sikkerheds-patch-hastighed | Dedikeret `debian-security`-repo, hurtigt patch-flow | Kræver typisk en fuld rebuild via nixpkgs-kanalen, historisk langsommere på akutte CVE'er |
| Hærdningsøkosystem (CIS/STIG) | Meget modent, skrevet direkte til Debian/RHEL | Mindre modent end for Debian/RHEL |
| Match med opgavens ordlyd | Direkte match (`/etc/sudoers.d/`, `ufw`, `sshd_config`) | Kræver oversættelse og eksplicit argumentation per modul (se de enkelte moduler) |

**Konklusion:** NixOS er valgt, fordi de arkitektoniske fordele (reproducerbarhed, rollback til en
tidligere, fuldt bygget generation, umuliggørelse af konfigurationsafvigelser) er direkte relevante
sikkerhedsegenskaber, og fordi
opgaven selv lægger vægt på automatisering frem for manuel opsætning. Hvor NixOS' model afviger fra
opgavens forventede arbejdsgang, dokumenteres eksplicit hvad forskellen er, og hvorfor den
deklarative løsning vurderes som ligeværdig eller stærkere. Se sammenligningstabellen i hvert
modul.

### Samlet billede: spredte konfigurationsfiler vs. én `configuration.nix`

"Konfiguration"-rækken ovenfor gælder for hele projektet på én gang. På en traditionel
Debian-server er de seks moduler spredt over mindst otte forskellige filer og kommandoer:

| Modul | Traditionelt spredt over | Samlet i NixOS |
|---|---|---|
| 1: Netværk og SSH | `/etc/hostname`, `/etc/network/interfaces`, `/etc/ssh/sshd_config`, `~/.ssh/authorized_keys` | `nixos/modules/network.nix` |
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
  ];
}
```

`nixos-rebuild switch`
bygger hele den ønskede konfiguration som én samlet, identificerbar generation, som derefter
aktiveres. Selve aktiveringen (genstart af tjenester m.v.) er ikke en databasetransaktion, men
resultatet er en generation, der kan rulles tilbage som en samlet enhed. På en traditionel server
findes intet tilsvarende: hver fil redigeres og genindlæses for sig, uden noget objekt der
repræsenterer hele systemets konfiguration som én genskabelig enhed.

## Teknisk arkitektur

En **flake** er Nix' standardiserede projektformat: en `flake.nix`-fil, der deklarerer et projekts
*inputs* (afhængigheder, fx en bestemt version af nixpkgs) og *outputs* (hvad der bygges, fx en
NixOS-konfiguration), evalueret i et isoleret miljø uafhængigt af lokale miljøvariabler. Den
tilhørende `flake.lock`-fil fastlåser den præcise version af hvert input, så to bygninger fra samme
flake giver identisk resultat, hvilket er grundlaget for hele projektets reproducerbarhedsargument.
Flakes er teknisk set stadig en eksperimentel Nix-funktion, selvom de reelt er de
facto-standarden i økosystemet. Derfor skal de aktiveres eksplicit med
`--extra-experimental-features "nix-command flakes"` (synligt i `verify-deploy.sh`, modul 6).

VM'en køres under QEMU/KVM via libvirt på en CachyOS-vært, og opbygges i tre faser:

1. **Bootstrap:** `flake.nix` definerer hele serverens konfiguration. `nix build .#qcow` bygger et
   qcow2-diskimage direkte fra flaken; `virt-install --import` opretter VM'en i libvirt fra dette
   image. Hele processen er én reproducerbar kommandosekvens uden manuelle installationstrin. Se
   [`scripts/setup.sh`](../scripts/setup.sh).
2. **Iteration:** Ændringer laves ved at redigere `.nix`-filerne, kopiere flake-kilden til VM'en
   (`~/linux101-config`), og køre `sudo nixos-rebuild switch --flake ~/linux101-config` lokalt på
   serveren.
3. **Sikkerhedsnet:** Før en risikabel ændring (fx firewall/sudo) deployes, testes den lokalt med
   `nixos-rebuild build-vm`, som bygger en midlertidig, isoleret test-VM uden at røre den rigtige
   server.

VM'en tildeles 2 vCPU, 3-4 GB RAM og 20 GB disk (qcow2).

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
