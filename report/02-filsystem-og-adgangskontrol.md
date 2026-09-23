# Modul 2: Filsystemet og adgangskontrol

## Formål

At forstå og anvende Linux' filsystemhierarki og rettighedsmodel korrekt, så data og programmer kun
er tilgængelige for dem, der reelt har brug for adgang.

## Sikkerhedsmæssig relevans

Forkerte fil- og mapperettigheder er en af de hyppigste årsager til privilege escalation-angreb.
ACL'er (Access Control Lists) gør det muligt at implementere finkornet adgangsstyring, når standard
bruger/gruppe/andre-modellen ikke er tilstrækkelig præcis.

## Opgave 1: Formålet med de vigtigste mapper i Filesystem Hierarchy Standard (FHS)

| Mappe | Formål |
|---|---|
| `/etc` | Systemkonfiguration. På NixOS genereret ud fra `configuration.nix` ved hver rebuild. |
| `/var` | Variable data: logs, caches, spool-filer. |
| `/var/log` | Systemets logfiler, det primære sted en analytiker kigger efter tegn på misbrug. |
| `/home` | Personlige hjemmemapper for almindelige brugere. |
| `/tmp` | Midlertidige filer, typisk world-writable med sticky bit, klassisk mål for symlink-angreb. |
| `/srv` | Data for services, som systemet stiller til rådighed. Her ligger `/srv/projekt` (se opgave 2). |
| `/nix/store` *(NixOS-specifikt)* | Indholdsadresseret, skrivebeskyttet lager for alle pakker og genererede konfigurationsfiler. |

`/nix/store` er ikke blot endnu en mappe føjet til FHS, NixOS bryder reelt med hierarkiet: `/bin`,
`/usr/lib` og tilsvarende er i praksis tomme, og programmer linkes i stedet direkte til deres egen,
unikke sti i `/nix/store` (navngivet med en kryptografisk hash af alle dens input). Det løser
konkret et problem, FHS-modellen strukturelt ikke kan: kræver `program A` `libssl 1.1` og
`program B` `libssl 3.0`, er det på et traditionelt FHS-system en reel konflikt (begge deler
normalt samme `/usr/lib`), mens de to versioner på NixOS blot er to forskellige stier i
`/nix/store`, som aldrig kan kollidere.

## Sammenligning: traditionel tilgang vs. NixOS

::: {.compare}
::: {.compare-side}
#### Traditionel: tre kommandoer, hver gang

```bash
$ sudo mkdir /srv/projekt
$ sudo chown admin:projekt /srv/projekt
$ sudo chmod 2770 /srv/projekt
```
:::
::: {.compare-side}
#### NixOS: én deklareret linje

```nix
# nixos/modules/filesystem.nix
systemd.tmpfiles.rules = [
  "d /srv/projekt 2770 admin projekt -"
];
```
:::
:::

**ACL til afgrænset adgang** bruger derimod nøjagtig de samme `setfacl`-kommandoer på begge
platforme, NixOS overtager ikke ACL'er på datafiler deklarativt, så metoden forbliver identisk med
den traditionelle, se `Opgave 4` nedenfor.

## Opgave 2: Delt projektmappe (ikke `chmod 777`)

**Evidens (NixOS):**

```
$ ls -ld /srv/projekt
drwxrws--- 2 admin projekt 4096 Sep 14 09:05 /srv/projekt
```

`2770`: ejer og gruppe (`projekt`) har fuld adgang, andre har ingen. Setgid (`2`) sikrer at nye
filer arver gruppen `projekt` automatisk. `chmod 777` undgås, fordi det giver alle på systemet
adgang og dermed modarbejder need-to-know-princippet.

## Opgave 3: Identifikation og rettelse af forkert konfigurerede rettigheder

**Før (NixOS):**

```
$ ls -l /srv/projekt/
-rw-rw-rw- 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxrwxrwx 1 admin projekt 28 Sep 14 09:07 deploy.sh
```

`app.conf` (666) er world-writable, og `deploy.sh` (777) er både world-writable og eksekverbart.
Sidstnævnte er et klassisk privilege escalation-mønster: enhver kan overskrive et script, som senere
køres med højere rettigheder.

**Rettelse og efter (NixOS):**

```
$ chmod 640 /srv/projekt/app.conf
$ chmod 750 /srv/projekt/deploy.sh
$ ls -l /srv/projekt/
-rw-r----- 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxr-x--- 1 admin projekt 28 Sep 14 09:07 deploy.sh
```

## Opgave 4: ACL til midlertidig, afgrænset adgang

**Før: ingen adgang (NixOS)**

```
$ sudo -u revisor ls /srv/projekt
ls: cannot open directory '/srv/projekt': Permission denied
```

**Tildeling og efter (NixOS):**

```
$ sudo setfacl -m u:revisor:rx /srv/projekt
$ sudo setfacl -R -m u:revisor:r /srv/projekt/app.conf /srv/projekt/deploy.sh

$ sudo -u revisor ls -l /srv/projekt
-rw-r-----+ 1 admin projekt 37 Sep 14 09:07 app.conf
-rwxr-x---+ 1 admin projekt 28 Sep 14 09:07 deploy.sh

$ getfacl /srv/projekt
user::rwx
user:revisor:r-x
group::rwx
mask::rwx
other::---
```

Gruppen `projekt` har fortsat ingen nye medlemmer. `revisor` fik adgang udelukkende via ACL'en.

## Delkonklusion

For selve mappeoprettelsen er NixOS' fordel klar: én deklareret linje
(`systemd.tmpfiles.rules`) erstatter tre kommandoer, der ellers skal huskes og gentages identisk
hver gang. For ACL-delen (opgave 4) er der derimod slet ingen forskel: `setfacl`/`getfacl` bruges
uændret på begge platforme, fordi NixOS ikke forsøger at gøre datafil-rettigheder deklarative.
Det gør modul 2 til det første sted i projektet, hvor NixOS ikke automatisk vinder, en påmindelse om
at vurdere hver opgave for sig, i stedet for at antage at den deklarative tilgang er bedre alle
steder blot fordi den er bedre nogle steder.
