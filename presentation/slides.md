---
theme: default
title: 'Debian vs. NixOS: sat på prøve'
info: |
  ## Debian vs. NixOS
  En komparativ gennemgang af en deklarativ og en traditionel, imperativ server-opsætning.
class: text-center
transition: fade
mdc: true
---

# Debian vs. NixOS
## *Fra kommandoer til erklæringer*

<v-click>

<div class="text-sm text-pink-400 -rotate-6 inline-block mt-2 ml-[263px]">
(semi-guddommelige befalinger)
</div>

</v-click>

<!--
Vi fik at vide: brug Debian eller Ubuntu. Jeg brugte NixOS i stedet, og byggede en rigtig
Debian-VM ved siden af, så jeg kunne teste om det faktisk er et bedre valg, i stedet for bare
at påstå det.
-->

---
layout: two-cols
---

# Imperativt

En rutebeskrivelse:

> "Drej til venstre.
> Kør 2 km.
> Drej til højre."

Følger du ét forkert trin,
ender du forkert. <br>Intet i beskrivelsen
fortæller dig det.

<v-click at="1">

<div class="flex items-center gap-3 mt-4">
<img src="/car-manual.svg" class="h-16" />
    <span><b>Du kører bilen.</b></span>
</div>


</v-click>

::right::

# Deklarativt

En destination:

> "Hertil."

Bilen regner selv ruten ud, kører den
<br>og kan til enhver tid
tjekke om den er nået frem.

<v-click at="1">

<div class="flex items-center gap-3 mt-4">
<img src="/car-self-driving.svg" class="h-16" />
<span><b>Bilen finder selv vej.</b></span>
</div>



</v-click>

<!--
Først en hurtig afklaring, for det meste af det jeg viser, hænger på denne forskel.

Forestil jer to biler. Imperativt er at køre selv: drej til venstre, kør 2 kilometer, drej til
højre. Følger du ét forkert trin, ender du forkert, og intet i selve rutebeskrivelsen fortæller
dig det. Deklarativt er en selvkørende bil: du taster en destination ind, bilen kører den, du
beskriver HVOR du vil hen, ikke HVORDAN man kommer derhen. Vigtigt: bilen teleporterer ikke, den
kører stadig en ægte rute, bare selv, og den kan til enhver tid tjekke om den faktisk er nået
frem.
-->

---
layout: two-cols
---

# Debian (imperativt)

```bash
$ apt install fastfetch
```

<img src="/debian-install-demo.gif" class="rounded-lg mt-2" style="width: 100%" />

Gør disse ting.

::right::

# NixOS (deklarativt)

```nix
environment.systemPackages =
  [ ... fastfetch ];
```

<img src="/nixos-rebuild-demo.gif" class="rounded-lg mt-2" style="width: 100%" />

Dette skal være sandt.

<!--
Begge optagelser er ægte, live mod vores egne VM'er, ikke simuleret, samme opgave, samme
pakke (fastfetch, ikke installeret på nogen af VM'erne forinden), for en reelt fair
sammenligning. Debian-siden kører kommandoen direkte. NixOS-siden redigerer først selve
opskriften (nano, tilføjer linjen), og lader derefter nixos-rebuild switch gøre den sand.
Samme slutresultat, forskellig vej derhen, det er selve pointen.

Konkret, i vores projekt: Debian-siden skriver "apt install fastfetch", gør det direkte.
NixOS-siden skriver "environment.systemPackages = [ ... fastfetch ]" i selve opskriften,
og lader rebuild-processen gøre resten.

Og er det så sort magi? Nej. Det er en afhængighedsgraf, lidt ligesom en Makefile, bare for
hele styresystemet. Hver bid af konfigurationen får et unikt id ud fra præcis dens input, og
bygges isoleret. Samme input giver altid samme resultat. Det er et byggesystem, ikke gætteri.
-->

---

# Hvor bor konfigurationen?

| Modul | <v-click at="1">Traditionelt spredt over</v-click> | <v-click at="2">Samlet i NixOS</v-click> |
|---|---|---|
| 1: Netværk og SSH | <v-click at="1">`/etc/{hostname,network/interfaces,ssh/sshd_config}`</v-click> | <v-click at="2">`network.nix`</v-click> |
| 2: Filsystem | <v-click at="1">`mkdir`/`chown`/`chmod` kommandoer</v-click> | <v-click at="2">`filesystem.nix`</v-click> |
| 1+3: Brugere | <v-click at="1">`/etc/{passwd,shadow,group}`</v-click> | <v-click at="2">`users.nix`</v-click> |
| 3: Sudo | <v-click at="1">`/etc/sudoers.d/admin`</v-click> | <v-click at="2">`users.nix`</v-click> |
| 4: Firewall | <v-click at="1">`ufw allow`/`default deny`/`default allow`/`enable`</v-click> | <v-click at="2">`firewall.nix`</v-click> |
| 5: Overvågning | <v-click at="1">crontab + script + logrotate</v-click> | <v-click at="2">`monitoring.nix`</v-click> |

<v-click at="3">

NixOS bryder med selve Filesystem Hierarchy Standard,
`/bin` og `/usr/lib` er reelt tomme.

</v-click>

<!--
Endnu et eksempel på at deklarativt betyder noget bredere end bare konfiguration. Denne tabel
viser hele projektets seks moduler, traditionelt spredt over mindst otte forskellige filer og
kommandotyper. Samlet i NixOS i fem modulfiler, importeret af én configuration.nix.

Og det går dybere end selve filerne. NixOS bryder med selve mappestrukturen, Filesystem Hierarchy
Standard. /bin og /usr/lib er reelt tomme.
-->

---

# Alt samlet ét sted: configuration.nix

```nix
{ config, pkgs, ... }:
{
  imports = [
    ./modules/network.nix
    ./modules/users.nix
    ./modules/filesystem.nix
    ./modules/firewall.nix
    ./modules/monitoring.nix
  ];

  system.stateVersion = "24.05";

  environment.systemPackages = with pkgs; [
    vim git acl tealdeer fastfetch
  ];
}
```

Ikke et script, der køres trin for trin, men et samlet svar på: **hvad er denne server?**

Hver linje i `imports` er én af filerne fra forrige slide. 

NixOS **genberegner** systemet fra denne opskrift, hver gang. Alt, der ikke står i den,
forsvinder ved næste genopbygning. **Konfigurationsdrift bliver umulig.**

<!--
Tabellen lige før viste fem modulfiler, network.nix, filesystem.nix, users.nix, firewall.nix,
monitoring.nix, men ikke hvad der faktisk binder dem sammen. Det gør denne fil, configuration.nix,
den rigtige, uændrede fra vores eget projekt. Imports-listen er bogstaveligt talt tabellens højre
kolonne. Resten af filen erklærer resten af systemets tilstand, hvilken version af NixOS, og
hvilke pakker der skal være installeret. Det er ikke et script, der bliver kørt, det er en
beskrivelse af, hvad serveren skal være.

Og fordi det er en opskrift, og ikke en gemt tilstand, bliver systemet ikke gendannet, det bliver
GENBEREGNET fra denne fil, hver eneste gang. Enhver ændring, der ikke står heri, forsvinder ved
næste genopbygning, ikke fordi den blev rullet tilbage, men fordi den aldrig var en del af planen.
Konfigurationsdrift, systemet der gradvist afviger fra det, det burde være, bliver strukturelt
umuligt.
-->

---

## Hele NixOS-systemet genskabt fra bunden, på < 15 sekunder:

 <br>

<img src="/full-rebuild-demo.gif" class="rounded-lg mx-auto" style="max-width: 90%" />

<!--
Det I lige så, var en ægte, live kørsel af
./scripts/setup.sh, river VM'en ned, bygger et nyt diskimage fra flake.nix, og starter en
frisk VM, noget der slet ikke findes et Debian-modstykke til her. Videoen er afspillet i
halv hastighed for læsbarhed, de 15 sekunder er den ægte, direkte målte kørselstid, ikke
videoens forløbne tid. Værd at nævne: dette er den hurtige vej, fordi NixOS allerede havde
bygget præcis denne konfiguration tidligere, en helt frisk bygning (fx efter en reel
kodeændring) tager omkring et minut, stadig langt hurtigere end en Debian-installation,
fordi Nix henter præ-byggede pakker fra en cache i stedet for at kompilere fra kildekode.
-->

---

# Og hashen efter en tvunget genbygning

<img src="/rebuild-proof-demo.gif" class="rounded-lg mx-auto" style="max-width: 90%" />

<v-click>

Byg den samme opskrift forfra, uafhængigt, og resultatet er **matematisk identisk**, ned til
sidste byte. <br> Ikke "det ligner det gamle", et **bevis** på at det er præcis det samme.

</v-click>

<v-click>

**Debian har intet modstykke.** Dennes installation er en række *handlinger*, ikke et verificerbart slutresultat.

</v-click>

<!--
Her er den skarpe test: byg konfigurationen forfra, og sammenlign hashen med den forrige
bygning.

Byte for byte den samme. Ingen snapshot kan bevise det om sig selv, et snapshot er en kopi, ikke
et bevis på at kopien er rigtig. Og forsvandt hele VM'en i morgen, mister vi ikke opskriften. Den
ligger i git, uafhængig af den maskine der er væk.

 Debian: Gentager man installationen i morgen, får man noget, der
*ligner* originalen, men pakkeversioner, tidsstempler og rækkefølge kan alle variere undervejs.
Der findes intet indbygget tjek, der kan bevise det er byte for byte det samme.
-->

---

# Intet bliver nogensinde overskrevet

Og det gælder for hver tidligere genopbygning denne session har lavet, stadig intakt og
nummereret, live mod vores VM:

<img src="/generations-demo.gif" class="rounded-lg mx-auto mt-2" style="max-width: 95%" />

<!--
Og det stopper ikke ved den seneste konfiguration. Hver eneste genopbygning denne session har
lavet, er stadig intakt og nummereret, det er en generation. Her er listen, live mod vores VM.
-->

---
layout: center
---

# Mens jeg skrev rapporten

<img src="/dawo-article.jpg" class="rounded-lg mx-auto" style="max-width: 85%" />

<!--
Og det er ikke bare mig der siger det. The Register, 28. september, mens jeg sad og skrev på
rapporten.
-->

---
layout: center
---

# Hvorfor netop NixOS?

<style>
.slidev-vclick-target.slidev-vclick-prior { opacity: 1 !important; }
</style>

<v-click>

<p><strong>Reproducerbarhed og verificerbarhed, ikke bare "det er Linux".</strong> <span style="color: rgba(255,255,255,0.5)">NixOS' funktionelle, immutable pakkemodel betyder at man kan bevise at hver eneste maskine i flåden kører præcis den godkendte, auditerede konfiguration, byte for byte.</span></p>

</v-click>

<v-click>

<p><strong>Digital suverænitet, ikke bare "open source".</strong> <span style="color: rgba(255,255,255,0.5)">Sagen er udløst af at amerikanske sanktioner afskar ICC's anklager fra Microsoft-adgang. Man vil ikke bare undgå Microsoft, man vil kunne bevise overfor sig selv og offentligheden at systemet gør præcis det, det siger.</span></p>

</v-click>

<v-click>

<p><strong>Modularitet.</strong> <span style="color: rgba(255,255,255,0.5)">Otte kommuner deler samme base og tilpasser til individuelle behov, ved at lægge lokal konfiguration oven på, uden at forke hele systemet. </span></p>

</v-click>

<!--
Kilder (egen research, ikke artiklen selv): sagen startede da amerikanske sanktioner mod ICC's
anklager afskar vedkommendes Microsoft-adgang, det gjorde suverænitetsspørgsmålet akut.
-->

---
layout: center
class: text-center
---

# Spørgsmål?

<!--
Forbered: "er det her ikke bare et snapshot?", svar: nej, et snapshot gemmer hvad der VAR der,
inklusive enhver glemt, udokumenteret rettelse, for evigt. NixOS genberegner i stedet systemet
fra opskriften hver gang, så kun det, der faktisk står i den, overlever en genopbygning.

Sandsynligt opfølgende spørgsmål: "hvorfor ikke bare Ansible/Puppet på Debian?", svar: stadig
imperative værktøjer oven på en imperativ base, ingen build-tids-verifikation, intet forhindrer
en manuel ændring værktøjet aldrig ser.
-->
