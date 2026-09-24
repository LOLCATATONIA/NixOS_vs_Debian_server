# Modul 1: VM-opsætning og netværk

## Formål

At etablere et rent, kontrolleret og reproducerbart udgangspunkt for serveren, samt sikre den
første og mest kritiske indgang til systemet: fjernadgang.

## Sikkerhedsmæssig relevans

Den første adgangsvej ind i en server (her: SSH) er samtidig den mest udsatte. Fejl i denne fase
(f.eks. adgangskodebaseret root-login) undergraver alle senere hærdningstiltag. Et reproducerbart
udgangspunkt er desuden en forudsætning for, at sikkerhedsvurderingen kan genskabes og kontrolleres
af andre.

## Sammenligning: traditionel tilgang vs. NixOS

| Opgave | Traditionel løsning | NixOS-løsning |
|---|---|---|
| Installer Linux server-distro uden GUI | Boot en installations-ISO og gennemgå en interaktiv netinst-wizard | `nix build .#qcow` bygger et diskimage direkte fra `flake.nix` (ingen interaktion); `virt-install --import` opretter VM'en |
| Statisk IP og sigende hostname | Redigér `/etc/network/interfaces` eller netplan manuelt | `networking.hostName` og `networking.interfaces.eth0.ipv4.addresses` i `nixos/modules/network.nix` |
| Ikke-root administratorbruger | `useradd -m -G sudo admin && passwd admin` | `users.users.admin = { isNormalUser = true; openssh.authorizedKeys.keys = [...]; };` i `nixos/modules/users.nix` |
| Deaktiver direkte root-login via SSH | Redigér `/etc/ssh/sshd_config`, genstart `sshd` manuelt | `services.openssh.settings.PermitRootLogin = "no";`, genereret ved hver `nixos-rebuild switch` |
| Kun nøglebaseret SSH | Redigér `sshd_config`, læg nøgle i `~/.ssh/authorized_keys` manuelt | `services.openssh.settings.PasswordAuthentication = false;` + `authorizedKeys.keys`, samme versionsstyrede fil |

## Sikkerhedsbegrundelse for hvert valg

- **Server-distribution uden GUI:** Et grafisk miljø tilføjer pakker, tjenester og angrebsflade, som
  en server, der udelukkende driftes via SSH, aldrig har brug for.
- **Statisk IP:** En DHCP-tildelt adresse kan ændre sig, hvilket ville bryde firewallens
  kilde-IP-begrænsning (modul 4) og gøre det sværere entydigt at identificere serveren i logs.
- **Sigende hostname** (`nixos-comparison`): Gør det muligt entydigt at identificere serveren i logs og
  alarmer, vigtigt i incident response.
- **Ikke-root administratorbruger:** Forudsætning for sporbarhed (handlinger spores til én konto)
  og for granulær sudo (modul 3) i stedet for permanent root-adgang.
- **Deaktiveret direkte root-login:** Root er den mest værdifulde konto at kompromittere; at kræve
  login som almindelig bruger først tilføjer et ekstra lag.
- **Kun nøglebaseret SSH:** Adgangskoder kan gættes eller genbruges; en privat nøgle findes kun ét
  sted og kan ikke gættes.

## Bevis: bootstrap og SSH-adgang

**Bootstrap-kommandosekvens:**

```
# byg det færdige, konfigurerede diskimage fra flake.nix
nix build .#qcow -L
# opret og start libvirts lager til VM-diskimages
sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default
# opret en tom volume, og upload det byggede image ind i den
sudo virsh vol-create-as default nixos-comparison.qcow2 5196742656 --format qcow2
sudo virsh vol-upload --pool default nixos-comparison.qcow2 result/nixos.qcow2
# opret selve VM'en fra det uploadede image, ingen installation
sudo virt-install --name nixos-comparison --memory 3072 --vcpus 2 \
    --disk vol=default/nixos-comparison.qcow2,bus=virtio \
    --network network=default,model=virtio \
    --graphics none --console pty,target_type=serial \
    --import --os-variant generic --noautoconsole
```

**Vellykket SSH-login med nøgle:**

::: {.compare}
::: {.compare-side}
#### Debian

```
$ ssh -i ~/.ssh/debian_comparison_admin_ed25519 -p 2222 admin@192.168.122.11 'hostname && whoami'
debian-comparison
admin
```
:::
::: {.compare-side}
#### NixOS

```
$ ssh -i ~/.ssh/nixos_comparison_admin_ed25519 -p 2222 admin@192.168.122.10 'hostname && whoami'
nixos-comparison
admin
```
:::
:::

**Afvist password-login og afvist root-login: identisk adfærd på begge platforme.** Kun IP og
nøglefil adskiller kommandoerne, selve resultatet er ens:

```
# tving et password-forsøg, selvom en gyldig nøgle findes (Debian: .11, NixOS: .10)
$ ssh -v -p 2222 -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@<IP> 'echo test'
debug1: Authentications that can continue: publickey
admin@<IP>: Permission denied (publickey).

# root, selv med en ellers gyldig admin-nøgle
$ ssh -i <admin-nøgle> -p 2222 root@<IP> 'echo test'
root@<IP>: Permission denied (publickey).
```

Root afvises fordi `PermitRootLogin = "no"` på begge platforme (NixOS: `nixos/modules/network.nix`;
Debian: `/etc/ssh/sshd_config`, se "Samme fire opgaver" nedenfor). NixOS-siden lukker adgangsvejen
yderligere af med en direkte ugyldig adgangskode-hash (`users.users.root.hashedPassword = "!"`),
Debian-siden har i stedet en gyldig, men kun konsol-tilgængelig, `root`-adgangskode
(`comparison-temp-pw`, se VM-sammenligningstabellen i `00-tilgang.md`).

**Debian-siden: en reel installationsblokering, fundet og rettet.** Under opsætningen af den
faktiske Debian-sammenligningsserver fejlede DHCP under selve installationen. `sudo nft list
ruleset` på **værten** viste at `ufw-user-input` kun havde regler for DNS (port 53), ingen regel
for DHCP-serverporten (UDP 67):

```
$ sudo ufw allow in on virbr0 to any port 67 proto udp
```

```
$ dhcpcd -t 15 -1 ens2
# før fixet: intet svar, gentagne forsøg fejlede
# efter fixet: øjeblikkelig lease på 192.168.122.85, 3600 sekunder
```

Værtens firewall var opbygget ad hoc, over tid, uden nogen samlet oversigt over hvilke porte der
reelt var åbnet, en direkte konsekvens af den traditionelle, imperative tilgang til
firewall-konfiguration (se også modul 4). NixOS-siden rammer aldrig denne klasse af problem: der
er slet ingen installationsfase, der afhænger af DHCP eller andet runtime-netværk.

**Samme fire opgaver, side om side** (statisk IP, hostname, deaktiveret root-login, kun
nøglebaseret SSH):

::: {.compare}
::: {.compare-side}
#### Traditionel: tre filer, to kommandoer

```bash
# /etc/hostname
debian-comparison

# /etc/network/interfaces
auto ens2
iface ens2 inet static
    address 192.168.122.11/24

# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
```
```bash
$ systemctl restart networking
$ systemctl restart sshd
```
:::
::: {.compare-side}
#### NixOS: én fil, ingen manuel genstart

```nix
# nixos/modules/network.nix
networking.hostName = "nixos-comparison";
networking.interfaces.eth0.ipv4.addresses = [
  { address = "192.168.122.10"; prefixLength = 24; }
];

services.openssh.settings = {
  PermitRootLogin = "no";
  PasswordAuthentication = false;
};
```
```bash
$ sudo nixos-rebuild switch --flake .
```
:::
:::

Samme resultat, men den traditionelle version er spredt over tre filer og kræver at huske at
genstarte to tjenester manuelt bagefter. Den deklarative version er én fil, og `nixos-rebuild
switch` sørger selv for at aktivere ændringen korrekt, uanset hvilke tjenester der reelt er
berørt.

## Delkonklusion

Modul 1 viser den tydeligste strukturelle forskel i hele rapporten: NixOS har reelt intet
installationstrin. `nix build .#qcow` producerer et færdigt, konfigureret image, og `virt-install
--import` importerer det uden en eneste interaktiv beslutning, mens Debian kræver en rigtig
installationsproces, før modul 1's egentlige opgaver (statisk IP, ny bruger, SSH-hærdning) kan
starte. Konkret var forskellen stor: Debians installer forsøger som udgangspunkt DHCP under
netværksopsætningen, medmindre den preseedes til statisk IP, og her blokerede en host-side
`ufw`-regel al DHCP-trafik, hvilket forsinkede opsætningen reelt, indtil årsagen blev fundet og en
statisk IP-preseed blev valgt i stedet. NixOS-siden rammer aldrig dette: der findes slet ikke en
installationsfase, der afhænger af noget netværksprotokol overhovedet. Det er ikke et bevis på at
NixOS generelt er "nemmere" — kun at dens bootstrap har færre bevægelige dele, når den først er sat
korrekt op. Til gengæld er Debians fejlsøgningsterræn (DHCP, netværksinterfaces) langt mere
almindeligt kendt end at fejlsøge Nix' eget evalueringslag.
