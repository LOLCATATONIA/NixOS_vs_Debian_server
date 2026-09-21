# Resultater: modul 1-6 udført i hånden på Debian, sammenlignet med NixOS

Faktiske tal og bevis, indsamlet løbende. Denne fil er rådata til `07-syntese-nixos-fremtidens-valg.md`
og til at berige de side-om-side-sammenligninger, der allerede står i selve rapporten. Ikke
rapport-tekst i sig selv.

**Debian-VM:** `debian-comparison`, statisk IP `192.168.122.50` (sat via preseed ved
installation, se `08-log-debian-vs-nixos-install.md`), `bus=virtio`/`model=virtio`, samme
QEMU-opsætning som `linux101-srv`.

## Modul 1: VM-opsætning og netværk

**Udgangspunkt:** Statisk IP og hostname var allerede sat via preseed ved selve installationen
(samme situation som NixOS' image, der har det deklareret før første boot), tælles derfor ikke som
manuelt modul 1-arbejde her. Det der reelt blev udført i hånden:

**Kommandoer kørt** (via seriel konsol, som root, første adgang til en frisk installation):

```bash
useradd -m -s /bin/bash -G sudo admin
mkdir -p /home/admin/.ssh && chmod 700 /home/admin/.ssh
echo "ssh-ed25519 AAAA... admin@debian-comparison" > /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys && chown -R admin:admin /home/admin/.ssh
passwd -l admin
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart sshd
```

**Antal kommandoer:** 8. **Antal filer rørt:** 2 (`~/.ssh/authorized_keys`, `/etc/ssh/sshd_config`).
**Tid:** 27 sekunder (ren udførelsestid, kommandosekvensen kendt på forhånd).

**Uventet fund:** `sudo` var slet ikke installeret (minimal Debian-installation vælger kun
`standard` + `ssh-server` i tasksel, ikke `sudo`). Krævede et ekstra trin, ikke en del af den
oprindelige plan:

```bash
apt-get update -qq
apt-get install -y -qq sudo
```

**Tid for dette ekstra trin:** 42 sekunder (mest `apt-get update`, netværksafhængig). Dette er i sig
selv en konkret sammenligningspointe: den traditionelle tilgang har et implicit, ikke-dokumenteret
afhængighedstræ (at oprette en "administratorbruger" kræver stiltiende at `sudo`-pakken allerede
findes, hvilket ikke er givet på en minimal installation). NixOS' `users.users.admin` med
`extraGroups = [ "wheel" ]` kræver ingen tilsvarende, skjult forudsætning, `security.sudo`-modulet
er en del af NixOS' basissystem uanset hvilke pakker der er installeret.

**Verificeret** (identisk metode som brugt for `linux101-srv`):

```
$ ssh -i ~/.ssh/debian_comparison_admin_ed25519 admin@192.168.122.50 "hostname && whoami"
debian-tmp
admin

$ ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no admin@192.168.122.50 "echo test"
admin@192.168.122.50: Permission denied (publickey).

$ ssh -i ~/.ssh/debian_comparison_admin_ed25519 root@192.168.122.50 "echo test"
root@192.168.122.50: Permission denied (publickey).
```

Alle tre krav fra modul 1's afleveringskrav opfyldt: nøgle-login virker, password afvises,
root afvises.

**NixOS-sammenligning:** Samme fire resultater (admin-bruger, nøglebaseret SSH, deaktiveret
root-login, ingen password-auth) opnås ved én `nixos-rebuild switch` af en allerede skrevet
`users.nix`/`network.nix`, ingen separate kommandoer, intet der kan glemmes i forkert rækkefølge, og
ingen skjult pakkeafhængighed at støde på undervejs.

## Modul 2: Filsystemet og adgangskontrol

**Forudsætning, ny sudo-regel:** `admin`s konto er password-låst (matcher NixOS-siden), så en
granulær `/etc/sudoers.d/admin`-regel blev tilføjet i takt med det konkrete behov opstod, præcis
samme filosofi som NixOS-siden selv bruger. Endte efter modul 2 med disse linjer:
```
admin ALL=(ALL) NOPASSWD: /usr/bin/mkdir, /usr/bin/chown, /usr/bin/chmod, /usr/sbin/setfacl, /usr/bin/getfacl
admin ALL=(ALL) NOPASSWD: /usr/sbin/groupadd, /usr/sbin/usermod, /usr/sbin/useradd
admin ALL=(ALL:ALL) NOPASSWD: /usr/bin/setfacl, /usr/bin/getfacl, /usr/bin/ls
```
(To rækker for `setfacl`/`getfacl` er en efterladt duplikering: den første manglede `(ALL:ALL)`,
nødvendigt for `sudo -u revisor ...`. Værd at nævne i syntesen: selv en erfaren udførelse producerer
overlappende, senere overflødige linjer, når reglerne bygges op løbende i stedet for på forhånd.)

**Uventet fund #2:** `acl`-pakken (giver `setfacl`/`getfacl`) er heller ikke installeret som
standard. **Dette er symmetrisk**, ikke et Debian-minus: NixOS-siden krævede også eksplicit `acl` i
`environment.systemPackages` (allerede opdaget under det oprindelige modul 2-arbejde).

**Kommandoer kørt** (delt projektmappe):
```bash
sudo mkdir -p /srv/projekt && sudo chown admin:projekt /srv/projekt && sudo chmod 2770 /srv/projekt
```
**Resultat:** `drwxrws--- 2 admin projekt`, identisk med NixOS-siden.

**Forkert konfigurerede filer, identificeret og rettet** (samme eksempel som NixOS-siden):
```
FØR:  -rw-rw-rw- app.conf (666)   -rwxrwxrwx deploy.sh (777)
EFTER: -rw-r----- app.conf (640)   -rwxr-x--- deploy.sh (750)
```

**ACL til `revisor`** (samme eksempel som NixOS-siden):
```
FØR:  ls: cannot open directory '/srv/projekt': Permission denied
EFTER: user:revisor:r-x, getfacl-output identisk i struktur med NixOS-siden
```

**Samlet tid, modul 2 (inkl. pakkeinstallation og sudo-opsætning undervejs):** ca. 60 sekunder ren
udførelsestid. **Filer/tilstande rørt:** 1 ny mappe, 2 testfiler, 1 ny gruppe, 3 sudoers-linjer,
1 pakkeinstallation.

## Modul 3: Bruger- og gruppestyring

**Uventet fund #3 (reel Unix-faldgrube, ikke pakke-relateret denne gang):** `useradd -G guest guest`
fejlede: `useradd: group guest exists - if you want to add this user to that group, use -g.`
`useradd` forsøger som standard at oprette en privat primær gruppe med samme navn som brugeren, hvilket
kolliderer, hvis den gruppe allerede findes (her fordi `groupadd guest` blev kørt først, med hensigt
om at bruge den som en almindelig, delt gruppe). Rettelse: `-g guest` (primær gruppe) i stedet for
`-G guest` (sekundær gruppe). En reel, klassisk Unix-administrations-fælde, ikke noget der er unikt
for denne opgave, men et konkret eksempel på, at selv rutinemæssig brugeroprettelse har skjulte
regler at kende til.

**Kommandoer kørt (fuld sekvens, retter fejlen indregnet):**
```bash
groupadd guest
useradd -m -s /bin/bash -G projekt developer
useradd -m -s /bin/bash -g guest guest        # -g, ikke -G, se fund ovenfor
passwd -l developer && passwd -l guest
# + mkdir/chmod/chown for ~/.ssh og authorized_keys for begge brugere
```

**Sudo-reglerne endte med** (bygget op løbende, jf. modul 2):
```
admin ALL=(ALL) NOPASSWD: /usr/bin/mkdir, /usr/bin/chown, /usr/bin/chmod, /usr/sbin/setfacl, /usr/bin/getfacl
admin ALL=(ALL) NOPASSWD: /usr/sbin/groupadd, /usr/sbin/usermod, /usr/sbin/useradd
admin ALL=(ALL:ALL) NOPASSWD: /usr/bin/setfacl, /usr/bin/getfacl, /usr/bin/ls
admin ALL=(ALL:ALL) NOPASSWD: /usr/bin/touch
```
Interessant sammenligningspointe til syntesen: NixOS-sidens granulære sudo-regler er ankret om
NixOS' *eget deployment-værktøj* (`nixos-rebuild switch`, `systemctl restart sshd`). Debian-sidens
regler endte i stedet ankret om rå filsystem-/brugeradministrationskommandoer (`mkdir`, `useradd`,
`setfacl`), fordi det var det, det faktiske arbejde krævede. Ingen af delene er forkerte, det viser
bare at "granulær sudo" konkret ser meget forskelligt ud alt efter hvilken slags arbejdsopgaver
platformen faktisk lægger på administratoren.

**Verificeret (samme rollemønster som rapportens rolleskema):**
```
$ sudo -u developer touch /srv/projekt/developer-test.txt && ls -l ...
-rw-rw-r-- 1 developer projekt 0 ... developer-test.txt          # developer KAN skrive

$ sudo -u guest touch /srv/projekt/guest-write-test.txt
touch: cannot touch '...': Permission denied                      # guest kan IKKE skrive

$ getfacl /srv/projekt
group:guest:r-x                                                   # guest har læse-/gennemsynsadgang
```

**Samlet tid, modul 3:** ca. 45 sekunder ren udførelsestid (inkl. fejlrettelsen for `guest`-gruppen).

## Modul 1-3: samlet i et script, testet, ikke kun antaget

Hele modul 1-3-sekvensen er fanget i `TODO/08-debian-provision.sh`, skrevet *efter* det manuelle
arbejde ovenfor, som en samlet, dokumenteret reference, ikke en genvej der erstatter det talte,
manuelle arbejde (det er allerede udført og målt separat, ovenfor).

**Idempotens forsøgt og faktisk testet**, ikke kun påstået: scriptet blev kopieret til den allerede
opsatte VM og kørt igen mod den eksisterende tilstand.

```
$ bash /tmp/provision.sh
[provision] Deaktiverer root-login og password-auth (modul 1)
[provision] Opretter delt projektmappe med gruppe-rettigheder (modul 2)
[provision] Giver guest-gruppen læseadgang via ACL, ingen skriveadgang (modul 3)
[provision] Færdig. Modul 1-3 er nu opsat traditionelt/imperativt på denne server.
$ echo $?
0
```

Bemærk hvad der IKKE blev logget ved andet forsøg: ingen "Opretter admin/developer/guest-bruger"
og ingen "Installerer manglende pakke", fordi `id`/`dpkg -s`-tjekkene korrekt genkendte at de
allerede var opfyldt. Efterfølgende verifikation bekræftede at intet gik i stykker eller blev
duplikeret (samme UID'er, samme rettigheder).

**Vigtig, ærlig begrænsning, som scriptets egen kommentar også påpeger:** dette er *delvist*
idempotent, ikke fuldt, i modsætning til `nixos-rebuild switch`. SSH-nøgler, sudoers-filen og
ACL'erne genskrives/genanvendes ubetinget ved hver kørsel (harmløst her, men ikke et bevis for at
scriptet aldrig kunne have en utilsigtet bivirkning et andet sted). At opnå ægte, garanteret
idempotens på den traditionelle side kræver eksplicit arbejde for hvert eneste trin, det er ikke en
egenskab, man får gratis, sådan som NixOS' evaluerings-model giver det. Denne forskel er selv en
central pointe til syntesen.

## Modul 4: Firewall og netværkssikkerhed

**Kommandoer kørt:**
```bash
apt-get install -y ufw
sed -i "s/^#\?Port .*/Port 2222/" /etc/ssh/sshd_config
ufw allow from 192.168.122.1 to any port 2222 proto tcp
ufw default deny incoming
ufw default allow outgoing
systemctl restart sshd
ufw --force enable
```
**Antal kommandoer:** 7. **Tid:** 32 sekunder. Ingen uventede fund denne gang, `ufw` er selv den
forventede, veldokumenterede pakke for opgaven, intet skjult afhængighedstræ som `sudo`/`acl`.

**Verificeret:**
```
$ ssh -p 2222 admin@192.168.122.50 hostname
debian-tmp
$ ssh -p 22 admin@192.168.122.50 echo test
ssh: connect to host 192.168.122.50 port 22: Connection timed out

$ sudo ufw status verbose
Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)
To                         Action      From
2222/tcp                   ALLOW IN    192.168.122.1
```

**Samlet tid, modul 4:** 32 sekunder ren udførelsestid, plus én ekstra sudoers-linje
(`/usr/sbin/ufw status verbose`, NOPASSWD) for at kunne dokumentere status uden fuld root, direkte
sammenligneligt med NixOS-sidens tilsvarende `nft list ruleset`-regel.

## Modul 5: System monitoring og logging

**Uventet fund #4:** `cron` er heller ikke installeret som standard. **Uventet fund #5, mere
væsentligt, retter en påstand i selve rapporten:** `/var/log/auth.log` **findes slet ikke**, fordi
`rsyslog` heller ikke er installeret på en minimal Debian 13. En frisk, minimal Debian-installation
bruger, ligesom NixOS, udelukkende `journald`. Rapportens nuværende sammenligningstabel i modul 5
("Fejlede loginforsøg: `/var/log/auth.log` vs. `journalctl -u sshd`") er derfor **ikke korrekt for
en moderne, minimal installation** og bør rettes, `auth.log` er en valgfri, ekstra pakke
(`rsyslog`), ikke noget der følger med automatisk. Se fix nedenfor.

**Kommandoer kørt:**
```bash
apt-get install -y cron
mkdir -p /etc/scripts && cp monitor.sh /etc/scripts/ && chmod +x /etc/scripts/monitor.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /etc/scripts/monitor.sh") | crontab -
# /etc/logrotate.d/monitor: daily, rotate 7, compress, missingok, notifempty
```

**Genbrug uden ændringer:** `scripts/monitor.sh` og `scripts/healthcheck.sh` blev kopieret
*uændrede* fra NixOS-siden og kørte korrekt med det samme, konkret bevis på rapportens egen påstand
om at disse to scripts er almindelig, portabel bash uden NixOS-specifik afhængighed:
```
$ /etc/scripts/monitor.sh && cat /var/log/monitor.log
2026-09-18 13:39:17 CPU=0% DISK=14% MEM=7%
```

**Fejlede loginforsøg, faktisk via `journalctl`, ikke `auth.log`:**
```
$ journalctl -u ssh --no-pager | tail -1
Sep 18 13:40:58 debian-tmp sshd-session[3328]: Connection closed by authenticating user admin 192.168.122.1 port 36132 [preauth]
```
Formatet er identisk med NixOS-sidens eksempel i selve rapporten (samme `sshd-session[...]:
Connection closed ... [preauth]`-linje), fordi begge platforme kører samme nyere OpenSSH-version
oven på samme `journald`.

**`healthcheck.sh`, uændret, kørt direkte:** Virker fuldt ud, men firewall-sektionen er markant mere
ordrig end på NixOS-siden, `ufw` (via `iptables-nft`) genererer et langt større, mere støjende
`nft`-regelsæt (over 100 linjer, inkl. IPv6/ICMP/NetBIOS-boilerplate, der ikke er relevant for denne
server) end NixOS' håndskrevne, native `nftables`-konfiguration (under 20 linjer i alt). Samme
kommando, samme script, markant forskelligt informationsstøjniveau.

**Samlet tid, modul 5:** ca. 40 sekunder ren udførelsestid.

## Modul 6: Shell og Bash scripting

`TODO/08-debian-provision.sh` blev udvidet til at dække modul 4 (firewall) og modul 5
(overvågning/logrotation) oveni modul 1-3, og opfylder dermed selv modul 6's kerneopgave: "skriv
ét eller flere modulopdelte bash-scripts, der automatiserer så meget af modul 1-5 som muligt."
Bruger funktioner, variable, `set -euo pipefail`, og tjek-før-handling-mønstre gennemgående.

**Genkørt (anden gang, nu med modul 4-5 inkluderet) mod den allerede opsatte VM:**
```
$ bash 08-debian-provision.sh
[provision] Deaktiverer root-login og password-auth (modul 1)
[provision] Opretter delt projektmappe med gruppe-rettigheder (modul 2)
[provision] Giver guest-gruppen læseadgang via ACL, ingen skriveadgang (modul 3)
[provision] Konfigurerer ufw: default-deny, kun SSH på 2222 fra værten (modul 4)
Skipping adding existing rule
[provision] Sætter overvågningsscript op via cron og logrotate (modul 5)
[provision] Færdig. Modul 1-5 er nu opsat traditionelt/imperativt på denne server.
$ echo $?
0
```
Bemærk `ufw`s egen "Skipping adding existing rule", endnu et lag af idempotens-tjek oven i
scriptets egne, denne gang leveret af selve værktøjet. Verificeret bagefter: firewall stadig aktiv,
`sudo ufw status verbose` uændret, og vigtigst, `monitor.log` viser reelle, adskilte cron-kørsler 5
minutter fra hinanden (`13:40:02` og `13:45:02`), et direkte, tidsstemplet bevis på at cron-jobbet
faktisk kører i baggrunden, ikke kun at opsætningskommandoen lykkedes.

**`healthcheck.sh`-krav (opgave 3):** Opfyldt ved direkte genbrug af det **identiske, uændrede**
script fra NixOS-siden, se modul 5 ovenfor for det fulde, kørte output. Det er selv beviset for
rapportens påstand: scriptet har ingen NixOS-specifik afhængighed.

**Samlet tid, modul 6 (selve udvidelsen + gentestning):** ca. 35 sekunder ren udførelsestid.

## Opsummering, alle seks moduler

| Modul | Kommandoer/trin | Ren udførelsestid | Uventede fund |
|---|---|---|---|
| 1 | 8 + 2 (sudo-install) | 27 + 42 sek | Manglende `sudo`-pakke |
| 2 | 3 + ACL-trin | ~60 sek | Manglende `acl`-pakke (symmetrisk med NixOS) |
| 3 | ~10 | ~45 sek | `useradd -G`/`-g`-gruppekollision |
| 4 | 7 | 32 sek | Ingen |
| 5 | 4 + pakkeinstallation | ~40 sek | Manglende `cron`; **`auth.log` findes ikke uden `rsyslog`**, rettet i selve rapporten |
| 6 | (script skrevet + gentestet) | ~35 sek | Ingen nye, `ufw`s egen idempotens bekræftet |

**Samlet ren udførelsestid, alle seks moduler:** ca. 280 sekunder (~4,5 minut), eksklusiv research,
fejlfinding og skrivetid, som ikke er sammenlignelig på tværs af platforme på samme måde.
**Fem uventede fund** undervejs, tre af dem manglende pakker på en minimal installation
(`sudo`, `acl`, `cron`), én reel Unix-administrationsfælde (gruppekollision), og én der direkte
rettede en unøjagtig påstand i selve rapporten (`auth.log`).
