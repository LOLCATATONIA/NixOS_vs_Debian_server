# Modul 3: Bruger- og gruppestyring

## Formål

At designe en rollebaseret adgangsstruktur, der afspejler organisationens reelle behov, og som
understøtter sporbarhed og ansvarlighed.

## Sikkerhedsmæssig relevans

Segregation of duties forhindrer, at én kompromitteret konto giver adgang til alt. Individuelle
brugerkonti er en forudsætning for troværdig logning. Korrekt brug af sudo med begrænsede
rettigheder reducerer skadesomfanget, hvis en konto kompromitteres.

## Rollestruktur

| Bruger | Sekundær gruppe (`extraGroups`) | Rolle-specifik adgang | Begrundelse |
|---|---|---|---|
| `admin` | `wheel` (medlemskab alene giver ingen adgang, se nedenfor) | Granulære, navngivne `sudo`-regler | Skal kunne drifte serveren uden ubegrænset root-adgang |
| `developer` | `projekt` *(fra modul 2)* | Læse-/skriveadgang til `/srv/projekt` via gruppe-rettigheder | Udviklere skal kunne bidrage til det fælles projektområde |
| `guest` | `guest` *(ny)* | Læseadgang til `/srv/projekt` via gruppe-ACL, ingen skriveadgang | En ekstern part skal kunne se, men ikke ændre, projektdata |

Alle tre brugeres faktiske primære gruppe er `users` (gid 100), NixOS' standard for
`isNormalUser = true`, se `id`-output nedenfor. Den rolle-specifikke adgang kommer fra
gruppemedlemsskabet ovenfor, sat via `extraGroups`, ikke fra selve den primære gruppe.

I Linux-verdenen refererer `wheel` til en speciel brugergruppe, hvor medlemmerne som udgangspunkt
har tilladelse til at køre administrator-kommandoer via `sudo`. `admin` er medlem af `wheel` (og
har dermed som udgangspunkt sudo-rettigheder), primært fordi NixOS kræver dette af mindst én
bruger, for at undgå at systemet låser sig selv ude. I praksis er denne adgang dog neutraliseret:
`security.sudo.wheelNeedsPassword` står på sin standardværdi (`true`), og `admin` har ingen
adgangskode, så almindelig wheel-baseret sudo reelt er uopnåeligt. Al faktisk adgang kommer i
stedet fra `security.sudo.extraRules`.

## Sammenligning: traditionel tilgang vs. NixOS

::: {.compare}
::: {.compare-side}
#### Traditionel: `useradd` + `/etc/sudoers.d/`

```bash
$ sudo useradd -m -G projekt developer
$ sudo useradd -m -G guest guest

# /etc/sudoers.d/admin
admin ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart sshd.service
admin ALL=(ALL) NOPASSWD: /usr/bin/chmod g+s /srv/projekt
admin ALL=(ALL) NOPASSWD: /usr/sbin/nft list ruleset
```
:::
::: {.compare-side}
#### NixOS: `users.nix`

```nix
users.users.developer = {
  isNormalUser = true;
  extraGroups = [ "projekt" ];
};
users.users.guest = {
  isNormalUser = true;
  extraGroups = [ "guest" ];
};

security.sudo.extraRules = [{
  users = [ "admin" ];
  commands = [
    { command = "/run/current-system/sw/bin/systemctl restart sshd.service"; options = [ "NOPASSWD" ]; }
    { command = "/run/current-system/sw/bin/chmod g+s /srv/projekt"; options = [ "NOPASSWD" ]; }
    { command = "/run/current-system/sw/bin/nft list ruleset"; options = [ "NOPASSWD" ]; }
  ];
}];
```
:::
:::

Begge tilgange giver samme granulære, kommando-specifikke sudo, men mekanikken er forskellig:
Debian samler regler i separate filer under `/etc/sudoers.d/`, NixOS har slet ikke denne mappe,
verificeret direkte:

```
$ ls /etc/sudoers.d/
ls: cannot access '/etc/sudoers.d/': No such file or directory
```

NixOS genererer i stedet **én samlet**, skrivebeskyttet `/etc/sudoers`-fil ud fra hele
konfigurationen ved hver rebuild, ikke separate drop-in-filer, der kan glemmes eller efterlades
uden versionsstyring.

## Bevis: granulær sudo virker

```
$ sudo -n whoami
sudo: a password is required

$ sudo systemctl restart sshd.service
OK

$ sudo -n systemctl restart dbus-broker.service
sudo: a password is required
```

Selv en anden `systemctl restart`-kommando afvises. Afgrænsningen er på den fulde kommandolinje,
ikke kun programnavnet.

**Den genererede `/etc/sudoers`** (0440, kun læsbar af root):

```
root     ALL=(ALL:ALL)    SETENV: ALL
%wheel  ALL=(ALL:ALL)    SETENV: ALL
admin     ALL=(ALL:ALL)    NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake /home/admin/linux101-config,
    NOPASSWD: /run/current-system/sw/bin/systemctl restart sshd.service,
    NOPASSWD: /run/current-system/sw/bin/chmod g+s /srv/projekt,
    NOPASSWD: /run/current-system/sw/bin/nft list ruleset
```

## Dokumentation: `/etc/group` og `id`

```
$ grep -E "^(wheel|projekt|guest):" /etc/group
wheel:x:1:admin
projekt:x:997:developer
guest:x:999:guest

$ id admin
uid=1000(admin) gid=100(users) groups=100(users),1(wheel)
$ id developer
uid=1001(developer) gid=100(users) groups=100(users),997(projekt)
$ id guest
uid=1002(guest) gid=100(users) groups=100(users),999(guest)
```
