# Modul 3: Bruger- og gruppestyring

## Formål

At designe en rollebaseret adgangsstruktur, der afspejler organisationens reelle behov, og som
understøtter sporbarhed og ansvarlighed.

## Sikkerhedsmæssig relevans

Segregation of duties forhindrer, at én kompromitteret konto giver adgang til alt. Individuelle
brugerkonti er en forudsætning for troværdig logning. Korrekt brug af sudo med begrænsede
rettigheder reducerer skadesomfanget, hvis en konto kompromitteres.

## Rollestruktur

| Bruger | Primær gruppe | Rolle-specifik adgang | Begrundelse |
|---|---|---|---|
| `admin` | `wheel` (medlemskab alene giver ingen adgang, se nedenfor) | Granulære, navngivne `sudo`-regler | Skal kunne drifte serveren uden ubegrænset root-adgang |
| `developer` | `projekt` *(fra modul 2)* | Læse-/skriveadgang til `/srv/projekt` via gruppe-rettigheder | Udviklere skal kunne bidrage til det fælles projektområde |
| `guest` | `guest` *(ny)* | Læseadgang til `/srv/projekt` via gruppe-ACL, ingen skriveadgang | En ekstern part skal kunne se, men ikke ændre, projektdata |

`admin` er nominelt medlem af `wheel`. NixOS kræver dette af mindst én bruger, for at undgå at
systemet låser sig selv ude. Medlemskabet giver dog ingen reel adgang: `security.sudo.wheelNeedsPassword`
står på sin standardværdi (`true`), og `admin` har ingen adgangskode, så almindelig wheel-baseret
sudo er uopnåeligt. Al faktisk adgang kommer fra `security.sudo.extraRules`.

## Sammenligning: traditionel tilgang vs. NixOS

| Opgave | Traditionel løsning | NixOS-løsning |
|---|---|---|
| Brugerroller | `useradd developer`, `useradd guest` | `users.users.developer`/`users.users.guest` i `nixos/modules/users.nix` |
| Granulær sudo | Filer i `/etc/sudoers.d/` | `security.sudo.extraRules`, genererer **én samlet** `/etc/sudoers`-fil, ikke separate drop-in-filer (se nedenfor) |

**Ift. opgavens ordlyd** ("via `/etc/sudoers.d/`"): `/etc/sudoers.d/` findes ikke på systemet,
verificeret direkte:

```
$ ls /etc/sudoers.d/
ls: cannot access '/etc/sudoers.d/': No such file or directory
```

NixOS genererer i stedet én skrivebeskyttet `/etc/sudoers`-fil ud fra hele konfigurationen. Dette
vurderes at opfylde opgavens *underliggende* krav (granulær, kommando-specifik sudo, ikke
ubegrænset root-adgang) fuldt ud, selvom filmekanikken er en anden.

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
