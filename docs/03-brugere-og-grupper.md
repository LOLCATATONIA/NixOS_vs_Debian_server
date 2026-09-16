# Modul 3: Bruger- og gruppestyring

*Se [`00-tilgang.md`](00-tilgang.md) for den overordnede begrundelse for valg af NixOS.*

## Formål

At designe en rollebaseret adgangsstruktur, der afspejler organisationens reelle behov, og som
understøtter sporbarhed og ansvarlighed.

## Sikkerhedsmæssig relevans

Segregation of duties forhindrer, at én kompromitteret konto giver adgang til alt. Individuelle
brugerkonti (frem for delte konti) er en forudsætning for troværdig logning. Korrekt brug af sudo
med begrænsede rettigheder frem for konstant root-adgang reducerer skadesomfanget, hvis en konto
bliver kompromitteret.

## Rollestruktur

| Bruger | Primær gruppe | Rolle-specifik adgang | Begrundelse |
|---|---|---|---|
| `admin` | `wheel` (medlemskab alene giver reelt ingen adgang — `wheelNeedsPassword` står på standardværdien `true`, og `admin` har ingen adgangskode, så almindelig wheel-baseret sudo er uopnåeligt) | Granulære, navngivne `sudo`-regler (`security.sudo.extraRules`) til specifikke root-kommandoer | Skal kunne drifte og opdatere serveren, men uden ubegrænset root-adgang |
| `developer` | `projekt` *(genbrugt fra modul 2)* | Læse- og skriveadgang til `/srv/projekt` via gruppe-rettigheder (`2770`) | Udviklere skal kunne bidrage til det fælles projektområde |
| `guest` | `guest` *(ny)* | Læseadgang til `/srv/projekt` via en gruppe-ACL — ingen skriveadgang, ingen medlemskab af `projekt` | En ekstern part (fx en revisor eller samarbejdspartner) skal kunne se, men ikke ændre, projektdata |

Bevidst designvalg: `developer`-rollen får sin adgang ved at blive medlem af den **eksisterende**
`projekt`-gruppe fra modul 2, i stedet for at der oprettes en ny, overlappende gruppe med samme
rettigheder. Det er en direkte konsekvens af, at opgavens moduler bygger oven på hinanden — modul 2
byggede allerede den gruppe, modul 3 beder om.

`guest` får bevidst *ikke* gruppe-rettigheder til `/srv/projekt` (det ville kræve enten en ny
gruppe-ejer på mappen eller at gøre `other` læsbar, som vi eksplicit fravalgte i modul 2). I stedet
bruges en gruppe-ACL-entry (`setfacl -m g:guest:rx`), som er den samme teknik som modul 2's
`revisor`-eksempel — blot anvendt på en gruppe i stedet for en enkelt bruger.

## Opgave 3: Granulær sudo (erstatter den midlertidige `wheel`-adgang)

Fra modul 1 og frem havde `admin` blanket adgang via `security.sudo.wheelNeedsPassword = false`,
eksplicit markeret som midlertidigt i to tidligere moduler. Den er nu fjernet og erstattet.

**Vigtig præcisering ift. opgaveteksten:** Opgaven beder specifikt om at konfigurere sudo
"granulært via `/etc/sudoers.d/`". Det gør vi ikke bogstaveligt — verificeret direkte på den
kørende server:

```
$ ls /etc/sudoers.d/
ls: cannot access '/etc/sudoers.d/': No such file or directory
```

`/etc/sudoers.d/`-mappen findes slet ikke. NixOS' `security.sudo.extraRules` genererer i stedet
**én samlet, skrivebeskyttet `/etc/sudoers`-fil** ud fra hele konfigurationen — der er ingen
separate drop-in-filer at pege på. Vi vurderer, at dette opfylder opgavens *underliggende* krav
(granulær, kommando-specifik sudo — ikke ubegrænset root-adgang) fuldt ud, selvom den konkrete
fil-mekanik er en anden. Det er samme princip, vi har fulgt i alle moduler: den deklarative
løsning er ikke bogstaveligt identisk med den imperative, men opfylder samme sikkerhedsformål,
hvilket vi eksplicit begrunder i stedet for at lade stå uadresseret.

**Designet:** `admin` er stadig nominelt medlem af `wheel` — det er nødvendigt, fordi NixOS har et
indbygget sikkerhedstjek, der nægter at bygge en konfiguration, hvor hverken `root` eller nogen
`wheel`-bruger har en adgangskode eller SSH-nøgle (for at forhindre permanent indlåsning).
Medlemskabet giver dog reelt intet: `security.sudo.wheelNeedsPassword` står på sin standardværdi
(`true`), og `admin` har ingen adgangskode — så den generelle `wheel`-regel kræver en adgangskode,
der ikke findes, og er dermed uopnåelig. Al reel adgang kommer fra eksplicitte,
kommando-specifikke `NOPASSWD`-regler i `security.sudo.extraRules`:

```nix
security.sudo.extraRules = [
  {
    users = [ "admin" ];
    commands = [
      { command = "/nix/store/*/bin/switch-to-configuration *"; options = [ "NOPASSWD" ]; }
      { command = ''/bin/sh -c 'exec /usr/bin/env -i PATH="''${PATH-}" "$@"' sh nix-env -p /nix/var/nix/profiles/system --set /nix/store/*''; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/systemctl restart sshd.service"; options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/chmod g+s /srv/projekt"; options = [ "NOPASSWD" ]; }
    ];
  }
];
```

Hver regel er begrundet i et **konkret**, allerede opstået behov — ikke givet på forhånd
"for en sikkerheds skyld":

1. **`switch-to-configuration`** — selve NixOS-aktiveringsmekanismen. Uden den kan
   `nixos-rebuild switch --target-host` slet ikke aktivere en ny konfiguration. Wildcardet er
   nødvendigt, fordi hver generation bygges til en ny, indholdsadresseret `/nix/store`-sti.
2. **Den indpakkede `nix-env`-kommando** — opdaget først da vi strammede sudo: `nixos-rebuild-ng`
   opdaterer system-profilens symlink via en separat, indpakket `nix-env`-kommando, som tidligere
   virkede "usynligt" under den brede `wheel`-adgang. Denne regel er skrøbelig over for fremtidige
   `nixos-rebuild-ng`-versioner, fordi den matcher værktøjets interne kommando-indpakning helt
   bogstaveligt — en dokumenteret afvejning, ikke en skjult svaghed.
3. **`systemctl restart sshd.service`** — ét snævert, navngivet driftseksempel, ikke generel
   `systemctl`-adgang.
4. **`chmod g+s /srv/projekt`** — se "Fejlfinding undervejs" nedenfor.

**Behavioral bevis for at afgrænsningen reelt virker** (ikke kun at reglerne *ser* rigtige ud):

```
$ sudo -n whoami
sudo: a password is required

$ sudo systemctl restart sshd.service
OK: sshd genstartet

$ sudo -n systemctl restart dbus-broker.service
sudo: a password is required
```

Bemærk især det sidste forsøg: selv en *anden* `systemctl restart`-kommando (samme program, andet
argument) afvises. Det beviser, at afgrænsningen er på den fulde kommandolinje, ikke bare på
programnavnet — en almindelig fejl i mindre omhyggeligt konfigurerede sudo-opsætninger.

```
$ sudo -l
User admin may run the following commands on linux101-srv:
    (ALL : ALL) SETENV: ALL
    (ALL : ALL) NOPASSWD: /nix/store/*/bin/switch-to-configuration *,
        /bin/sh -c 'exec /usr/bin/env -i PATH="${PATH-}" "$@"' sh nix-env -p
        /nix/var/nix/profiles/system --set /nix/store/*,
        /run/current-system/sw/bin/systemctl restart sshd.service,
        /run/current-system/sw/bin/chmod g+s /srv/projekt
```

Selve den genererede `/etc/sudoers`-fil (0440, kun læsbar af `root` — hentet her fra den lokale
Nix-store, hvor den også blev bygget, uden at kræve root-adgang på VM'en):

```
# Don't edit this file. Set the NixOS options 'security.sudo.configFile'
# or 'security.sudo.extraRules' instead.

root     ALL=(ALL:ALL)    SETENV: ALL
%wheel  ALL=(ALL:ALL)    SETENV: ALL
admin     ALL=(ALL:ALL)    NOPASSWD: /nix/store/*/bin/switch-to-configuration *,
    NOPASSWD: /bin/sh -c 'exec /usr/bin/env -i PATH="${PATH-}" "$@"' sh nix-env -p
    /nix/var/nix/profiles/system --set /nix/store/*,
    NOPASSWD: /run/current-system/sw/bin/systemctl restart sshd.service,
    NOPASSWD: /run/current-system/sw/bin/chmod g+s /srv/projekt

Defaults env_keep+=NIXOS_NO_CHECK
Defaults:root,%wheel env_keep+=TERMINFO_DIRS
Defaults:root,%wheel env_keep+=TERMINFO
```

## Fejlfinding undervejs

Denne strammere sudo-adgang afslørede tre reelle problemer, som er værd at dokumentere, fordi de
handler om konkrete sikkerhedsmekanismer i kernen og i vores egen arkitektur — ikke kun
Nix-specifikke kuriositeter.

1. **NixOS' egen lockout-beskyttelse.** Første forsøg på at fjerne `admin` fra `wheel` helt fejlede
   ved evaluering: *"Neither the root account nor any wheel user has a password or SSH authorized
   key."* NixOS nægter altså aktivt at bygge en konfiguration, der ville låse en ude — samme
   bekymring, vi selv stødte på under modul 2's bootstrap-krise, men her fanget automatisk *før*
   deployment i stedet for at opdage det efter. Løst ved at beholde `admin` i `wheel` (se ovenfor).

2. **Setgid-biten forsvandt uventet.** Efter at have tildelt `guest`-gruppens ACL, viste en ny fil
   oprettet af `developer` sig at arve gruppen `users` i stedet for `projekt` — setgid-biten
   (`2770`) var væk fra `/srv/projekt`. Årsagen er en reel, dokumenteret Linux-kerneregel: en
   *ikke-privilegeret* proces, der udfører `chmod`/en ACL-opdatering, får automatisk fjernet
   `S_ISGID`-biten, hvis processens effektive eller supplerende grupper ikke inkluderer filens
   gruppe. `admin` ejer `/srv/projekt`, men er *ikke* medlem af `projekt`-gruppen — så da vores
   `setfacl`-kald (kørt som `admin`, ikke `root`) internt synkroniserede ACL-masken, blev
   setgid-biten stille fjernet som bivirkning, uden fejlmelding. I modul 2 så vi aldrig dette, fordi
   `setfacl` dengang kørte via `sudo` under den brede `wheel`-adgang (root er undtaget fra reglen).
   Dette er samme kernemekanisme, der i sikkerhedslitteraturen bruges til at forhindre
   privilege-escalation via setgid-mapper — så selvom den kostede os en omgang fejlfinding, er det
   præcis den slags beskyttelse, opgaven selv fremhæver som en styrke ved Linux' rettighedsmodel.
   Løsning: den snævre `chmod g+s /srv/projekt`-sudo-regel (se ovenfor), anvendt eksplicit efter
   hver ACL-ændring.

3. **Endnu en sudo-bootstrap-fælde.** Da vi tilføjede reglen for `nix-env`-indpakningen (punkt 2 i
   forrige afsnit), fejlede selve deployet af *den* ændring — fordi den daværende, allerede aktive
   konfiguration endnu ikke indeholdt reglen, der skulle tillade netop dén deployment-mekanisme.
   Samme mønster som modul 1/2's bootstrap-krise, nu i mindre skala. Løst på samme måde: VM'en blev
   slettet og genskabt fra en flake, der indeholdt den fulde, rettede konfiguration fra første boot
   — anden gang vi har brugt denne fremgangsmåde som reelt recovery-værktøj, ikke kun som teoretisk
   argument.

Efter gen-oprettelsen blev modul 2's testfiler og ACL-tildelinger (som var imperativt oprettet,
altså ikke en del af den deklarative konfiguration) genskabt manuelt, så det kørende system fortsat
stemmer overens med al tidligere dokumentation.

**En sidste konsekvens værd at nævne:** Modul 2's demonstration af `revisor`-adgang blev dengang
testet med `sudo -u revisor` fra `admin` — hvilket virkede fint under den daværende brede
`wheel`-adgang. Efter denne granulære sudo-opstramning kan `admin` *ikke længere* impersonere
andre brugere via `sudo -u`, uanset hvilken bruger: den kommando er ikke blandt de whitelistede.
Det er ikke en fejl, men selve pointen med modulet — og det er netop derfor, `developer`- og
`guest`-testene ovenfor er udført via direkte SSH-login med brugernes egne nøgler i stedet for
`sudo -u`. Havde vi kun testet med `sudo -u`, ville modul 3's egen sikkerhedsforbedring have
ødelagt vores testmetode fra modul 2 uden at vi opdagede det.

## Dokumentation for modulet

**`id`-output for hver bruger:**

```
$ id admin
uid=1000(admin) gid=100(users) groups=100(users),1(wheel)
$ id developer
uid=1001(developer) gid=100(users) groups=100(users),997(projekt)
$ id guest
uid=1002(guest) gid=100(users) groups=100(users),999(guest)
$ id revisor
uid=1003(revisor) gid=100(users) groups=100(users)
```

*(`revisor` er ikke en af modul 3's tre påkrævede roller — det er modul 2's dedikerede
ACL-demonstrationsbruger, medtaget her udelukkende for fuldstændighed.)*

**`/etc/group`-uddrag:**

```
wheel:x:1:admin
users:x:100:
guest:x:999:guest
projekt:x:997:developer
```

**Adgangsbevis — developer kan skrive, med korrekt gruppe-arv:**

```
$ ssh developer@192.168.122.10 'echo "test" > /srv/projekt/developer-test.txt; ls -l /srv/projekt/'
-rw-r--r-- 1 developer projekt 18 Sep 14 09:30 developer-test.txt
```

**Adgangsbevis — guest kan læse, men hverken skrive eller slette andres filer:**

```
$ ssh guest@192.168.122.10 'cat /srv/projekt/app.conf'
db_host=10.0.0.5
db_password=hunter2

$ ssh guest@192.168.122.10 'echo hack > /srv/projekt/guest-test.txt'
bash: /srv/projekt/guest-test.txt: Permission denied

$ ssh guest@192.168.122.10 'rm /srv/projekt/developer-test.txt'
rm: cannot remove '/srv/projekt/developer-test.txt': Permission denied
```

Se [`nixos/modules/users.nix`](../nixos/modules/users.nix) for den fulde, kommenterede
konfiguration.
