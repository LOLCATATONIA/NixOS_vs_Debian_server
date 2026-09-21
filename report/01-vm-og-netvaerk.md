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
- **Sigende hostname** (`linux101-srv`): Gør det muligt entydigt at identificere serveren i logs og
  alarmer, vigtigt i incident response.
- **Ikke-root administratorbruger:** Forudsætning for sporbarhed (handlinger spores til én konto)
  og for granulær sudo (modul 3) i stedet for permanent root-adgang.
- **Deaktiveret direkte root-login:** Root er den mest værdifulde konto at kompromittere; at kræve
  login som almindelig bruger først tilføjer et ekstra lag.
- **Kun nøglebaseret SSH:** Adgangskoder kan gættes eller genbruges; en privat nøgle findes kun ét
  sted og kan ikke gættes.

## Dokumentation/output

**Bootstrap-kommandosekvens:**

```
nix build .#qcow -L
sudo virsh pool-define-as default dir --target /var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default
sudo virsh vol-create-as default linux101-srv.qcow2 5196742656 --format qcow2
sudo virsh vol-upload --pool default linux101-srv.qcow2 result/nixos.qcow2
sudo virt-install --name linux101-srv --memory 3072 --vcpus 2 \
    --disk vol=default/linux101-srv.qcow2,bus=virtio \
    --network network=default,model=virtio \
    --graphics none --console pty,target_type=serial \
    --import --os-variant generic --noautoconsole
```

**Vellykket SSH-login med nøgle (NixOS):**

```
$ ssh -i ~/.ssh/linux101_ed25519 admin@192.168.122.10 'hostname && whoami'
linux101-srv
admin
```

**Afvist password-login (NixOS):**

```
$ ssh -v -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@192.168.122.10 'echo test'
debug1: Authentications that can continue: publickey
admin@192.168.122.10: Permission denied (publickey).
```

**Afvist root-login (selv med gyldig nøgle, NixOS):**

```
$ ssh -i ~/.ssh/linux101_ed25519 root@192.168.122.10 'echo test'
root@192.168.122.10: Permission denied (publickey).
```

Root afvises fordi `PermitRootLogin = "no"`. Root har derudover ingen gyldig adgangskode
(`users.users.root.hashedPassword = "!"`), hvilket lukker adgangsvejen helt af.

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
linux101-srv

# /etc/network/interfaces
auto eth0
iface eth0 inet static
    address 192.168.122.10/24

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
networking.hostName = "linux101-srv";
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
