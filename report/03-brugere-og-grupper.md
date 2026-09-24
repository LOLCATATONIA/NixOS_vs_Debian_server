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

**Debian-siden har, verificeret direkte, samme underliggende mønster.** `admin` på
`debian-comparison` er medlem af standardgruppen `sudo` (`groups=...,27(sudo),...`), som Debians
eget `/etc/sudoers` som udgangspunkt giver fuld, password-krævende root-adgang
(`(ALL : ALL) ALL`, synligt i `sudo -l`). Denne adgang er, akkurat som `wheel` ovenfor,
neutraliseret i praksis: kontoen er password-låst (`passwd -S admin` → `L`), så der ikke findes
nogen adgangskode at opgive. Al faktisk, brugbar adgang kommer i stedet fra de eksplicitte
`NOPASSWD`-linjer i `/etc/sudoers.d/admin`, samme princip, forskellig implementering.

## Sammenligning: traditionel tilgang vs. NixOS

::: {.compare}
::: {.compare-side}
#### Traditionel: `useradd` + `/etc/sudoers.d/`

```bash
$ sudo useradd -m -G projekt developer
$ sudo useradd -m -G guest guest

# /etc/sudoers.d/admin (reelt indhold, akkumuleret modul for modul)
admin ALL=(ALL) NOPASSWD: /usr/bin/mkdir, /usr/bin/chown, /usr/bin/chmod, /usr/sbin/setfacl, /usr/bin/getfacl
admin ALL=(ALL) NOPASSWD: /usr/sbin/groupadd, /usr/sbin/usermod, /usr/sbin/useradd
admin ALL=(ALL) NOPASSWD: /usr/sbin/nft list ruleset
admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status verbose
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

Begge tilgange er granulære i princippet, men mekanikken, og dermed hvad "granulær" reelt betyder,
er forskellig: Debian samler regler i separate filer under `/etc/sudoers.d/`, tilføjet én linje ad
gangen i takt med at behovet opstod, NixOS har slet ikke denne mappe, verificeret direkte:

| Kommando | Debian | NixOS |
|---|---|---|
| `ls /etc/sudoers.d/` | `admin`, `README` | `ls: cannot access '/etc/sudoers.d/': No such file or directory` |

NixOS genererer i stedet **én samlet**, skrivebeskyttet `/etc/sudoers`-fil ud fra hele
konfigurationen ved hver rebuild, ikke separate drop-in-filer, der kan glemmes eller efterlades
uden versionsstyring. Selv Debians `README`-fil er et lille eksempel på den spredte tilgang: en
statisk forklaring, der ligger ved siden af de faktiske regler, i stedet for at være del af én
selv-dokumenterende, versionsstyret konfiguration.

## Bevis: granulær sudo virker

```
# -n: fejl med det samme, i stedet for at vente på en adgangskode der aldrig kommer
# (identisk resultat på både nixos-comparison og debian-comparison)
$ sudo -n whoami
sudo: a password is required
```

**Delt succes:** `sudo -n nft list ruleset` lykkes uden adgangskode på begge platforme, det eneste
punkt hvor de to regelsæt reelt er identiske, ikke bare begge har en regel for samme kommando
(Debians output starter endda med en advarsel om at `ufw` og `iptables-nft` deler samme
nftables-lag, en reel driftsdetalje, ikke tilføjet for effekt).

::: {.compare}
::: {.compare-side}
#### NixOS: hele kommandolinjen er del af matchningen

```
$ sudo systemctl restart sshd.service
OK

$ sudo -n systemctl restart dbus-broker.service
sudo: a password is required
```

Selv en anden `systemctl restart`-kommando afvises. Afgrænsningen er på den fulde kommandolinje,
argumenter inklusive.
:::
::: {.compare-side}
#### Debian: kun kommandoens sti er del af matchningen

```
$ sudo -n mkdir -p /tmp/sudo-arg-test
$ sudo -n chmod 777 /tmp/sudo-arg-test
$ ls -ld /tmp/sudo-arg-test
drwxrwxrwx 2 root root 40 Sep 24 09:49 /tmp/sudo-arg-test
```

`/etc/sudoers.d/admin` navngiver kun kommandoens sti (`/usr/bin/mkdir`, `/usr/bin/chmod`), ikke
dens argumenter, så et vilkårligt sted og en vilkårlig tilstand accepteres uden adgangskode.
:::
:::

Ingen af platformene er entydigt bedst her, samme underliggende sudoers-mekanisme giver
modsatrettede konsekvenser, afhængig af hvor præcist den enkelte regel er skrevet: NixOS' fulde
kommandolinje-match kan blive for snæver (et harmløst tillæg afvises, se nedenfor), mens Debians
sti-kun-match her viste sig bredere end formentlig tilsigtet, ikke fordi platformen er mindre
sikker, men fordi disse specifikke linjer blev skrevet uden argumentbegrænsning.

**Den genererede `/etc/sudoers`** (0440, kun læsbar af root, NixOS-siden; Debian-sidens
tilsvarende, reelle `/etc/sudoers.d/admin`-indhold er vist i Sammenligningen ovenfor):

```
root     ALL=(ALL:ALL)    SETENV: ALL
%wheel  ALL=(ALL:ALL)    SETENV: ALL
admin     ALL=(ALL:ALL)    NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch --flake /home/admin/nixos-comparison-config,
    NOPASSWD: /run/current-system/sw/bin/systemctl restart sshd.service,
    NOPASSWD: /run/current-system/sw/bin/chmod g+s /srv/projekt,
    NOPASSWD: /run/current-system/sw/bin/nft list ruleset
```

**Note: en driftsmæssig omkostning ved den snævre kommandomatch.** Sudoers' fulde-kommandolinje-match
(vist ovenfor) er selve pointen med granulær adgang, men den er bogstavelig, ikke semantisk:

```
$ sudo -n nixos-rebuild switch --flake /home/admin/nixos-comparison-config
Done. The new configuration is /nix/store/zra2zp26hyakmd8h5vywp08n78l8hdgp-nixos-system-nixos-comparison-...

$ sudo -n nixos-rebuild switch --flake /home/admin/nixos-comparison-config#nixos-comparison
sudo: a password is required
```

Et harmløst, semantisk identisk `#nixos-comparison`-tillæg, der blot gør eksplicit hvilken
konfiguration der bygges, er nok til at blive afvist (ingen tilfældighed, se Delkonklusionen for
hvorfor selve reglen ikke kan indeholde et `#`-tegn). Konsekvensen er reel: `admin` har ingen
adgangskode, og `root` har hverken SSH-adgang (`PermitRootLogin = "no"`, modul 1) eller en gyldig
adgangskode til konsollen, så der findes intet fallback, hvis en kommando afviger bare en smule fra
den præcise, hvidlistede streng. `debian-comparison` har, som vist ovenfor, samme neutraliserede
`sudo`-gruppe-fallback som NixOS' `wheel`, men til forskel fra NixOS har Debian-siden stadig
`root`-konsoladgang som et reelt, brugbart nødspor (se VM-sammenligningstabellen i
`00-tilgang.md`). Den granulære sudo-model er derfor ikke gratis: den fjerner ikke kun
uautoriseret adgang, den fjerner også ens eget nødspor, hvis noget ikke er forudset præcist,
medmindre man, som Debian-siden her, bevidst har bevaret én anden vej ind.

Skulle selve stien i den hvidlistede kommando nogensinde skulle ændres (fx hvis config-mappen
omdøbes), findes der dog en sikker vej uden om denne stivhed: fordi `security.sudo.extraRules` blot
er en deklareret liste, kan en ny sti tilføjes som en **ekstra** regel, ved siden af den gamle,
appliceret via den kommando der allerede virker. Først når den nye sti er bekræftet at virke,
fjernes den gamle regel, via den nu-virkende, nye kommando. På intet tidspunkt i den overgang
mangler `admin` en gyldig, hvidlistet kommando at falde tilbage på. Den tilsvarende operation på
Debian, en direkte `visudo`-redigering af `/etc/sudoers.d/admin`, har ingen sådan mellemtilstand: en
fejlskrevet sti er øjeblikkeligt aktiv, uden en tidligere, stadig gyldig generation at falde tilbage
på. Den stive, bogstavelige matchning bliver ikke mindre stiv af det, men fordi konfigurationen er
data, man kan udvide additivt og derefter indskrænke igen i stedet for en fil man redigerer
destruktivt på stedet, koster selve stivheden ikke det samme som den ville på en traditionel server.

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

Begge platforme bygger på den samme sudoers-mekanisme, men det viste sig, at "granulær" ikke
betyder det samme i praksis: Debian-sidens sti-kun-regler var bredere end tilsigtet (vilkårlige
`chmod`/`mkdir`-argumenter), mens NixOS' fulde-kommandolinje-match var strengere, til tider for
strengt (et harmløst `#attribut`-tillæg afvist). Ingen af delene er en fejl i selve
sammenligningen, det er to reelt forskellige konsekvenser af samme underliggende værktøj, afhængig
af om reglen udtrykkes som en sti eller en hel linje. Den erfaring, der derudover er værd at
fremhæve, er at den deklarative tilgang ikke er immun over for reelle fejl: den
oprindelige `security.sudo.extraRules`-regel for fjern-deployment *så* korrekt ud (`sudo -l` viste
den rigtige adgang), men fejlede alligevel ved et faktisk deploy-forsøg, fordi den forsøgte at
forudsige `nixos-rebuild`s interne kommandoindpakning i stedet for at pege på selve værktøjet (se
kommentaren "ARKITEKTUR-REVISION" i `nixos/modules/users.nix`). Der blev også fundet en konkret,
uventet faldgrube: `#`-tegnet i en flake-reference (`--flake sti#attribut`) bliver læst som
sudoers' eget kommentartegn og afkorter resten af linjen. Pointen er ikke at NixOS er skrøbeligt,
men at den deklarative tilgang flytter fejlene, den fjerner dem ikke, og de kræver stadig at man
rent faktisk tester et deploy, ikke kun læser konfigurationen.
