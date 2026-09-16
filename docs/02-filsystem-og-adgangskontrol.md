# Modul 2: Filsystemet og adgangskontrol

*Se [`00-tilgang.md`](00-tilgang.md) for den overordnede begrundelse for valg af NixOS.*

## Formål

At forstå og anvende Linux' filsystemhierarki og rettighedsmodel korrekt, så data og programmer
kun er tilgængelige for dem, der reelt har brug for adgang.

## Sikkerhedsmæssig relevans

Forkerte fil- og mapperettigheder er en af de hyppigste årsager til privilege escalation-angreb.
Forståelse af FHS er nødvendig for at vide, hvor følsomme data, konfigurationer og logs bør ligge
og beskyttes. ACL'er gør det muligt at implementere finkornet adgangsstyring, når standard
bruger/gruppe/andre-modellen ikke er tilstrækkelig præcis.

## Opgave 1: Formålet med de vigtigste mapper i FHS

| Mappe | Formål |
|---|---|
| `/etc` | Systemkonfiguration. På NixOS er langt størstedelen af `/etc` genereret ud fra `configuration.nix` ved hver `nixos-rebuild switch` (mange filer er symlinks ind i `/nix/store`) — en ad hoc-redigering direkte i `/etc` overlever derfor kun til næste rebuild, hvor den erstattes af den version, der faktisk er godkendt i konfigurationen. |
| `/var` | Variable data, der ændrer sig under drift: logs, caches, spool-filer. |
| `/var/log` | Systemets logfiler — det primære sted en analytiker kigger efter tegn på misbrug (uddybes i modul 5, hvor `/var/log/monitor.log` og `journalctl` bruges til overvågning). |
| `/home` | Personlige hjemmemapper for almindelige brugere. |
| `/tmp` | Midlertidige filer, typisk world-writable med sticky bit — netop derfor et klassisk mål for symlink-angreb. Kernens `protected_regular`-hærdning (som vi selv stødte på under værtsopsætningen, se modul 1) forhindrer netop denne angrebsklasse ved at nægte at følge symlinks til filer ejet af andre i denne slags mapper. |
| `/srv` | Data for services, som systemet stiller til rådighed. Dette er, hvor `/srv/projekt` (den delte projektmappe, se opgave 2 nedenfor) er placeret — `2770`, ejet `admin:projekt`. |
| `/nix/store` *(NixOS-specifikt)* | Indholdsadresseret, skrivebeskyttet lager for alle installerede pakker og genererede konfigurationsfiler. Findes ikke i standard-FHS, men er selve grundlaget for NixOS' reproducerbarhed og integritetsgaranti (jf. [`00-tilgang.md`](00-tilgang.md)). |

**Sikkerhedsargument (NixOS vs. traditionel FHS-brug):** På et traditionelt system er `/etc`
almindelige, frit redigerbare filer — en angriber eller en fejltagelse kan ændre fx
`/etc/ssh/sshd_config` direkte, og ændringen overlever indtil nogen opdager det. På NixOS er de
sikkerhedskritiske dele af `/etc` genererede outputs af en deklaration; en ad hoc-ændring direkte i
`/etc` overlever kun til næste `nixos-rebuild switch`, hvor den bliver overskrevet af den
version, der faktisk er godkendt i `configuration.nix`.

## Opgave 2: Delt projektmappe via gruppe-rettigheder (ikke `chmod 777`)

Mappen `/srv/projekt` oprettes deklarativt via `nixos/modules/filesystem.nix`:

```nix
users.groups.projekt = {};

systemd.tmpfiles.rules = [
  "d /srv/projekt 2770 admin projekt -"
];
```

```
$ ls -ld /srv/projekt
drwxrws--- 2 admin projekt 4096 Sep 14 09:05 /srv/projekt
```

**Hvorfor ikke `chmod 777`:** `777` giver læse-, skrive- og køre-adgang til *alle* på systemet —
også processer og brugere, der intet har med projektet at gøre. Det er det modsatte af
need-to-know og gør det umuligt at vide bagefter, hvem der kunne have ændret noget. I stedet
bruges `2770`:

- Ejer (`admin`) og gruppen (`projekt`) har fuld adgang (`rwx`), andre har ingen adgang overhovedet (`---`).
- Det første ciffer (`2`) er **setgid**: nye filer og undermapper oprettet i `/srv/projekt` arver
  automatisk gruppen `projekt`, uanset hvilken der er den opskabende brugers primære gruppe. Uden
  setgid ville et gruppemedlem let komme til at oprette en fil, som resten af gruppen alligevel
  ikke kunne tilgå — en subtil, men almindelig fejlkilde.

**NixOS-nuance:** Selve mappens *eksistens og grundrettigheder* er deklareret og kan derfor ikke
drifte. Men filerne, som brugere efterfølgende lægger i mappen, er almindelige data — NixOS
"ejer" ikke deres indhold eller rettigheder på samme måde som konfigurationsfiler i `/etc`. Det er
derfor stadig `chmod`/`chgrp`/`setfacl`, som opgaven beder om, der er de relevante værktøjer her —
et af de moduler, hvor NixOS' deklarative model og den traditionelle arbejdsgang falder mest
sammen.

## Opgave 3: Identifikation og rettelse af forkert konfigurerede rettigheder

Der blev ikke udleveret et fysisk testmiljø til denne opgave. Vi har derfor selv konstrueret et
lille, repræsentativt scenarie: to filer, som en tænkt tidligere administrator har efterladt med
forkerte rettigheder i `/srv/projekt` — oprettet direkte på den kørende server (uden om Nix), for
at simulere en reel, udokumenteret fejlkonfiguration snarere end noget der var "korrekt fra
starten" i vores egen konfiguration.

**Før:**

```
$ ls -l /srv/projekt/
total 8
-rw-rw-rw- 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxrwxrwx 1 admin projekt 28 Sep 14 09:07 deploy.sh
```

**Identificerede problemer:**

1. `app.conf` (`666`, `-rw-rw-rw-`) — en konfigurationsfil (indeholder bl.a. et adgangskode-felt)
   er world-writable. Enhver lokal bruger eller proces kan ændre serverens konfiguration.
2. `deploy.sh` (`777`, `-rwxrwxrwx`) — et script er både world-writable *og* eksekverbart. Dette er
   et klassisk privilege escalation-mønster: hvis dette script nogensinde køres af en mere
   privilegeret bruger (fx via cron eller en tjeneste), kan enhver på systemet injicere vilkårlig
   kode ved blot at overskrive filen.

**Rettelse:**

```
$ chmod 640 /srv/projekt/app.conf
$ chmod 750 /srv/projekt/deploy.sh
```

**Efter:**

```
$ ls -l /srv/projekt/
total 8
-rw-r----- 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxr-x--- 1 admin projekt 28 Sep 14 09:07 deploy.sh
```

Nu kan kun ejeren (`admin`) og gruppen (`projekt`) læse konfigurationsfilen, og kun de samme kan
læse/eksekvere scriptet — verden (`other`) har ingen adgang til nogen af delene.

## Opgave 4: ACL til midlertidig, afgrænset adgang

Scenarie: en "revisor" (ekstern kontrollant) skal midlertidigt kunne læse indholdet af
`/srv/projekt` — uden at blive optaget som medlem af `projekt`-gruppen, og uden at det ændrer den
grundlæggende gruppestruktur for de faste projektmedlemmer. Brugeren `revisor` er deklareret i
`nixos/modules/filesystem.nix` specifikt til denne demonstration.

**Før — revisor har ingen adgang:**

```
$ sudo -u revisor ls /srv/projekt
ls: cannot open directory '/srv/projekt': Permission denied

$ getfacl /srv/projekt
# file: srv/projekt
# owner: admin
# group: projekt
user::rwx
group::rwx
other::---
```

**Tildeling af afgrænset ACL-adgang** (læs+udførsel på selve mappen, kun læs på de eksisterende filer):

```
$ sudo setfacl -m u:revisor:rx /srv/projekt
$ sudo setfacl -R -m u:revisor:r /srv/projekt/app.conf /srv/projekt/deploy.sh
```

*Bevidst valg: der bruges ingen "default"-ACL (`-d`), fordi adgangen er ment som midlertidig og
afgrænset — den skal ikke automatisk arves af fremtidige filer, kun gælde det, der eksplicit er
givet adgang til nu.*

**Efter — revisor kan læse, men ikke skrive:**

```
$ sudo -u revisor ls -l /srv/projekt
-rw-r-----+ 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxr-x---+ 1 admin projekt 28 Sep 14 09:07 deploy.sh

$ sudo -u revisor cat /srv/projekt/app.conf
db_host=10.0.0.5
db_password=hunter2

$ sudo -u revisor sh -c "echo hack >> /srv/projekt/app.conf"
sh: line 1: /srv/projekt/app.conf: Permission denied

$ getfacl /srv/projekt
# file: srv/projekt
# owner: admin
# group: projekt
user::rwx
user:revisor:r-x
group::rwx
mask::rwx
other::---
```

(Bemærk `+`'et efter rettighederne i `ls -l` — det er standardmåden `ls` viser, at en fil har
udvidede ACL-regler ud over den klassiske bruger/gruppe/andre-model.)

**Bekræftelse af at den grundlæggende gruppestruktur er uændret:**

```
$ getent group projekt
projekt:x:998:
```

Gruppen har stadig ingen medlemmer — revisor fik adgang udelukkende via ACL'en, ikke ved at blive
tilføjet til `projekt`-gruppen. Det er selve pointen: adgangen er præcist afgrænset til denne ene
bruger og denne ene mappe/disse filer, og kan fjernes igen med `setfacl -x u:revisor /srv/projekt`
uden at røre resten af adgangsstrukturen.

## Dokumentationskrav for modulet — opsummering

- `ls -l`/`getfacl`-output for "før" og "efter" er vist under opgave 3 og 4 ovenfor.
- Begrundelse for at undgå `chmod 777`: se opgave 2. I stedet bruges gruppe-ejerskab + setgid
  (`2770`) til den daglige, vedvarende adgangsstruktur, og ACL'er (`setfacl`) til midlertidig,
  individuel adgang der afviger fra gruppestrukturen.
