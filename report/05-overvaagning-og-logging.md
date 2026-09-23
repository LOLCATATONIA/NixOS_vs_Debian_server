# Modul 5: System monitoring og logging

## Formål

At kunne opdage unormal aktivitet, ressourceproblemer og potentielle sikkerhedshændelser, før de
udvikler sig til reelle problemer.

## Sikkerhedsmæssig relevans

"Du kan ikke opdage det, du ikke logger." System- og sikkerhedslogs er ofte det første sted, en
analytiker kigger efter tegn på uautoriserede loginforsøg.

## Sammenligning: traditionel tilgang vs. NixOS

| Opgave | Traditionel løsning | NixOS-løsning |
|---|---|---|
| Cron-baseret overvågning | `crontab -e`, script i `/usr/local/bin` | `services.cron.systemCronJobs`, ingen strukturel forskel. NixOS understøtter cron som en almindelig service |
| Logrotation | `/etc/logrotate.d/monitor` | `services.logrotate.settings."/var/log/monitor.log"` |
| Fejlede loginforsøg | `journalctl -u ssh` (ikke `/var/log/auth.log`, se note nedenfor) | `journalctl -u sshd` |

**Rettelse, verificeret direkte på en frisk Debian-installation:** `/var/log/auth.log` findes ikke
automatisk. Det kræver `rsyslog`, som ikke er en del af en minimal installation. En moderne, minimal
Debian-server bruger, ligesom NixOS, udelukkende `journald` som standard, indtil `rsyslog` eksplicit
installeres. Forskellen mellem platformene ligger derfor ikke i *om* `journald` bruges, begge gør,
men i at NixOS aldrig kan ende med en separat `auth.log`, da `rsyslog` ikke er en mulighed at
tilføje ved et uheld eller en vane, mens Debian kan udvides til begge dele afhængigt af hvad der er
installeret.

## Design

- **Cron-job**: kører `/etc/scripts/monitor.sh` hvert 5. minut som root.
- **`scripts/monitor.sh`**: logger CPU-, disk- og hukommelsesforbrug til `/var/log/monitor.log`.
- **Logrotation**: dagligt, 7 dages historik, komprimeret.

## Tærskelværdier

| Metric | Tærskel | Begrundelse |
|---|---|---|
| Diskforbrug (`/`) | > 85% | Et fyldt filsystem kan forårsage tjenestenedbrud og er et kendt symptom på et angreb |
| Hukommelsesforbrug | > 90% | Kan indikere en runaway-proces eller misbrug (fx crypto-mining) |

## Evidens: uddrag af logfilen

```
$ cat /var/log/monitor.log
2026-09-14 11:20:02 CPU=0% DISK=56% MEM=8%
2026-09-14 11:25:02 CPU=0% DISK=56% MEM=8%
```

**Logrotation, bekræftet aktiv:**

```
$ systemctl list-timers logrotate.timer
NEXT                         LEFT UNIT            ACTIVATES
Mon 2026-09-14 12:00:00 UTC 23min logrotate.timer logrotate.service
```

## Identifikation af mislykkede loginforsøg

**Fremkaldt eksempel** (forsøgt login med forkert nøgle):

```
$ ssh -i ~/.ssh/linux101_developer_ed25519 -p 2222 admin@192.168.122.10
admin@192.168.122.10: Permission denied (publickey).
```

**Tilsvarende log-linje:**

```
$ journalctl -u sshd
Sep 23 11:28:03 nixos-comparison sshd-session[1440]: Connection closed by authenticating user admin 192.168.122.1 port 38252 [preauth]
```

**Hvordan et unormalt mønster ville se ud:** Mange gentagne `[preauth]`-afvisninger på kort tid for
samme eller forskellige brugernavne tyder på automatiseret brute-forcing. Forsøg fra en anden
kilde-IP end `192.168.122.1` ville slet ikke nå sshd (blokeret af firewallen, modul 4). Gentagne
forsøg på at logge ind som `root` ville vise, at nogen afprøver kendte standardkonti på trods af at
root-login er deaktiveret (modul 1).

## Delkonklusion

Modul 5 er et af de mest symmetriske i rapporten: cron, logrotation og `journald` fungerer stort
set ens på begge platforme, og NixOS' fordel her er organisatorisk (samlet i én fil) snarere end
arkitektonisk. Den mest lærerige erfaring kom, da en oprindelig antagelse om at Debian bruger
`/var/log/auth.log` viste sig at være forkert på en frisk, minimal installation uden `rsyslog`, en
fejl der først blev fanget ved faktisk at teste på den rigtige Debian-VM, ikke ved at antage
kendskab til platformen. Den reelle, mere subtile forskel ligger derfor ikke i hvilke værktøjer der
bruges, men i at NixOS strukturelt ikke *kan* ende med en separat `auth.log` ved et uheld eller en
vane, mens Debian kan udvides til begge dele afhængigt af hvad der installeres senere.
