# Modul 3: Bruger- og gruppestyring

## Formål

At designe en rollebaseret adgangsstruktur, der afspejler organisationens reelle behov, og som
understøtter sporbarhed og ansvarlighed.

## Sikkerhedsmæssig relevans

Segregation of duties (adskillelse af ansvarsområder) forhindrer, at én kompromitteret konto giver
adgang til alt. Individuelle brugerkonti er en forudsætning for troværdig logning. Korrekt brug af
sudo med begrænsede rettigheder reducerer skadesomfanget, hvis en konto kompromitteres.

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
# -n: fejl med det samme, i stedet for at vente på en adgangskode der aldrig kommer
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

**Note: en driftsmæssig omkostning ved den snævre kommandomatch, bekræftet ved en faktisk
omdøbning.** Sudoers' fulde-kommandolinje-match (vist ovenfor) er selve pointen med granulær
adgang, men den er bogstavelig, ikke semantisk. Serveren blev senere rent faktisk omdøbt (fra
`linux101-srv` til `nixos-comparison`, se `00-tilgang.md`), hvilket krævede både et nyt
`networking.hostName` og et nyt navn på flakens `nixosConfigurations`-attribut, og satte derfor
reglen på en reel prøve, ikke kun en tænkt situation:

```
$ sudo -n nixos-rebuild switch --flake /home/admin/linux101-config
Done. The new configuration is /nix/store/8dnnc5bimgv0hza6rwlv1chfgkvy56c2-nixos-system-nixos-comparison-...

$ sudo -n nixos-rebuild switch --flake /home/admin/linux101-config#nixos-comparison
sudo: a password is required
```

Et harmløst, semantisk identisk `#nixos-comparison`-tillæg, der blot gør eksplicit hvilken
konfiguration der bygges, er nok til at blive afvist (ingen tilfældighed, se Delkonklusionen for
hvorfor selve reglen ikke kan indeholde et `#`-tegn). Konsekvensen er reel: `admin` har ingen
adgangskode, og `root` har hverken SSH-adgang (`PermitRootLogin = "no"`, modul 1) eller en gyldig
adgangskode til konsollen, så der findes intet fallback, hvis en kommando afviger bare en smule fra
den præcise, hvidlistede streng. Selve omdøbningen lykkedes uden problemer, netop fordi
rækkefølgen (hostname ændret først, flake-attributten omdøbt bagefter, aldrig samtidig) undgik
nogensinde at skulle bruge andet end den ene, hvidlistede streng. På en traditionel Debian-server
ville et tilsvarende fallback typisk kunne reddes via en almindelig `sudo`-adgangskode eller
root-konsoladgang, som `debian-comparison` faktisk har. Den granulære
sudo-model er derfor ikke gratis: den fjerner ikke kun uautoriseret adgang, den fjerner også ens
eget nødspor, hvis noget ikke er forudset præcist.

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

## Delkonklusion

Begge platforme kan opnå præcis samme granulære, kommando-specifikke sudo-adgang, blot udtrykt
forskelligt (separate `/etc/sudoers.d/`-filer vs. én genereret `/etc/sudoers`). Den erfaring, der er
værd at fremhæve, er dog at den deklarative tilgang ikke er immun over for reelle fejl: den
oprindelige `security.sudo.extraRules`-regel for fjern-deployment *så* korrekt ud (`sudo -l` viste
den rigtige adgang), men fejlede alligevel ved et faktisk deploy-forsøg, fordi den forsøgte at
forudsige `nixos-rebuild`s interne kommandoindpakning i stedet for at pege på selve værktøjet (se
kommentaren "ARKITEKTUR-REVISION" i `nixos/modules/users.nix`). Der blev også fundet en konkret,
uventet faldgrube: `#`-tegnet i en flake-reference (`--flake sti#attribut`) bliver læst som
sudoers' eget kommentartegn og afkorter resten af linjen. Pointen er ikke at NixOS er skrøbeligt,
men at den deklarative tilgang flytter fejlene, den fjerner dem ikke, og de kræver stadig at man
rent faktisk tester et deploy, ikke kun læser konfigurationen.
