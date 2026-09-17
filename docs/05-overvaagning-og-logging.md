# Modul 5: System monitoring og logging

*Se [`00-tilgang.md`](00-tilgang.md) for den overordnede begrundelse for valg af NixOS.*

## Formål

At kunne opdage unormal aktivitet, ressourceproblemer og potentielle sikkerhedshændelser, før de
udvikler sig til reelle problemer.

## Sikkerhedsmæssig relevans

"Du kan ikke opdage det, du ikke logger." System- og sikkerhedslogs er ofte det første sted, en
analytiker kigger efter tegn på uautoriserede loginforsøg. Automatiseret overvågning af ressourcer
kan afsløre både driftsproblemer og ondsindet aktivitet.

## Design

I modsætning til modul 3's sudoers.d eller modul 4's ufw er der ingen strukturel konflikt mellem
NixOS og traditionel cron — NixOS understøtter cron som en almindelig, førsteklasses service
(`services.cron`). Der er derfor ingen NixOS-oversættelse at argumentere for her; opgaven løses
direkte som beskrevet.

- **Cron-job** (`nixos/modules/monitoring.nix`): kører `/etc/scripts/monitor.sh` hvert 5. minut som
  root.
- **`scripts/monitor.sh`**: logger CPU-, disk- og hukommelsesforbrug til `/var/log/monitor.log`, og
  skriver en `ALERT`-linje hvis en tærskelværdi overskrides.
- **Logrotation**: `services.logrotate` roterer `/var/log/monitor.log` dagligt, beholder 7 dage,
  komprimerer. journald roterer allerede sin egen journal automatisk — men det dækker ikke en
  almindelig flad fil, vores eget script selv skriver til.

## Verifikation af logrotation

Konfigurationen er ikke kun deklareret — den er bekræftet aktiv på den kørende server:

```
$ systemctl list-timers logrotate.timer
NEXT                         LEFT UNIT            ACTIVATES
Mon 2026-09-14 12:00:00 UTC 23min logrotate.timer logrotate.service

$ cat /etc/logrotate.conf
...
"/var/log/monitor.log" {
  compress
  daily
  missingok
  notifempty
  rotate 7
}
```

## Tærskelværdier (opgave 4)

| Metric | Tærskel | Begrundelse |
|---|---|---|
| Diskforbrug (`/`) | > 85% | Et fyldt filsystem kan forårsage tjenestenedbrud og er et kendt symptom på et angreb (fx et logfyldt system eller data fra en kompromitteret proces) |
| Hukommelsesforbrug | > 90% | Unormalt højt hukommelsesforbrug kan indikere en runaway-proces eller misbrug af systemet (fx crypto-mining) |

## Evidens: uddrag af den genererede logfil

Overvågningsscriptet kørt af cron hvert 5. minut, verificeret ved faktisk at vente på to reelle
cron-kørsler (ikke en manuel testkørsel):

```
$ cat /var/log/monitor.log
2026-09-14 11:20:02 CPU=0% DISK=56% MEM=8%
2026-09-14 11:25:02 CPU=0% DISK=56% MEM=8%
```

Ingen `ALERT`-linjer, hvilket er korrekt — hverken disk- (56%) eller hukommelsesforbrug (8%)
overstiger de definerede tærskler.

**Verifikation af selve alarm-logikken:** Ovenstående beviser kun, at scriptet logger korrekt, når
*ingen* tærskel er overskredet — den vigtigste gren af koden (selve alarmeringen) er derved
uafprøvet. At faktisk fylde disken eller hukommelsen 85-90% op på en levende server for at teste
dette er hverken praktisk eller forsvarligt. I stedet testes alarm-logikken isoleret: en kopi af
scriptet med tærsklerne midlertidigt sat til 0% og logfilen omdirigeret til en testfil (ingen
ændring af den rigtige konfiguration eller logfil):

```
$ sed -e 's/DISK_THRESHOLD=85/DISK_THRESHOLD=0/' -e 's/MEM_THRESHOLD=90/MEM_THRESHOLD=0/' \
      -e 's#/var/log/monitor.log#/tmp/test-monitor.log#' /etc/scripts/monitor.sh > /tmp/test-monitor.sh
$ /tmp/test-monitor.sh && cat /tmp/test-monitor.log
2026-09-14 11:36:30 CPU=0% DISK=56% MEM=8%
2026-09-14 11:36:30 ALERT: diskforbrug 56% overstiger taerskel paa 0%
2026-09-14 11:36:30 ALERT: hukommelsesforbrug 8% overstiger taerskel paa 0%
```

Begge alarm-grene udløses og formateres korrekt.

(Outputtet ovenfor er en ægte capture fra dengang scriptets tekststrenge stadig var
ASCII-translittereret, `taerskel`/`paa` i stedet for `tærskel`/`på`, se modul 6's addendum om
hvorfor det senere blev ændret til rigtig UTF-8. Transskriptet er bevidst ikke rettet i
efterspilstid, det er en faktisk kørsel, ikke et opdateret eksempel.)

## Opgave 3: Identifikation af mislykkede loginforsøg

NixOS bruger udelukkende `journald` — der findes ikke en separat `/var/log/auth.log`-fil som på
Debian/Ubuntu. Ækvivalenten er `journalctl -u sshd`.

**Fremkaldt eksempel** (forsøgt login som `admin` med `developer`s SSH-nøgle):

```
$ ssh -i ~/.ssh/linux101_developer_ed25519 admin@192.168.122.10
admin@192.168.122.10: Permission denied (publickey).
```

**Tilsvarende log-linje i `journalctl -u sshd`:**

```
Sep 14 11:26:16 linux101-srv sshd-session[809]: Connection closed by authenticating user admin 192.168.122.1 port 44368 [preauth]
```

**Hvordan et unormalt mønster ville se ud:** Et enkelt afvist forsøg fra den kendte, godkendte
kilde-IP (`192.168.122.1`) er forventeligt (fx en forkert nøgle brugt ved en fejltagelse). Et
*unormalt* mønster ville derimod vise sig som:

- **Mange gentagne `[preauth]`-afvisninger på kort tid** for samme eller forskellige brugernavne —
  tegn på automatiseret brute-forcing.
- **Forsøg fra en anden kilde-IP end `192.168.122.1`** ville slet ikke nå frem til sshd overhovedet
  og ville i stedet ses i firewall-loggen/kilde-IP-reglen fra modul 4 (pakken droppes, før sshd
  nogensinde ser forbindelsen) — et endnu tidligere og stærkere signal end en sshd-logline.
- **Gentagne forsøg på at logge ind som `root`** — særligt interessant her, fordi det beviser at
  nogen enten ikke kender serverens hærdning (modul 1: root-login er deaktiveret) eller aktivt
  afprøver kendte standardkonti.

## Dokumentationskrav for modulet — opsummering

- Uddrag af logfil: se ovenfor.
- Beskrivelse af unormalt mønster i loginforsøg: se ovenfor.
