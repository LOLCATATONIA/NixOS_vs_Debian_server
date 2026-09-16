# Overordnet tilgang og metodevalg

Dette afsnit beskriver de overordnede metodevalg for opgaven, som gælder på tværs af alle seks
moduler. De enkelte modul-dokumenter (`01-vm-og-netvaerk.md`–`06-shell-og-bash-scripting.md`)
henviser tilbage til dette afsnit frem for at gentage begrundelsen hver gang.

## Valg af styresystem: NixOS frem for Debian/Ubuntu

Opgavebeskrivelsen foreslår Debian eller Ubuntu Server som udgangspunkt. Vi har fået accept fra
underviser til i stedet at bruge **NixOS**, under forudsætning af at vi for hvert modul eksplicit
argumenterer for fordele og ulemper ved den deklarative tilgang sammenlignet med den traditionelle,
imperative arbejdsgang som opgaven er skrevet ud fra.

### Fordele ved NixOS i en sikkerhedskontekst

- **Deklarativ, versionsstyret konfiguration.** Hele systemets tilstand ligger i `configuration.nix`
  (opdelt i moduler, se nedenfor) og kan versionsstyres i git. Der er ingen "usynlig" konfiguration,
  som er lavet manuelt og ikke dokumenteret.
- **Atomare opgraderinger og rollback.** Hver `nixos-rebuild switch` opretter en ny, selvstændig
  "generation" i bootloaderen. En fejlkonfiguration kan rulles tilbage ved simpelt reboot, uden risiko
  for en systemtilstand med delvist gennemførte ændringer.
- **Reproducerbarhed.** To maskiner bygget fra samme flake er funktionelt identiske. Det gør det muligt
  at bevise, at den kørende server rent faktisk svarer til den godkendte, dokumenterede konfiguration —
  i stedet for at skulle tro på det.
- **Immutable `/nix/store`.** Installerede pakker ligger i et skrivebeskyttet, indholdsadresseret lager.
  Vedvarende manipulation af systembinærer er markant sværere at skjule end på et system med et
  traditionelt, muterbart filsystem for pakker.
- **Hærdet kernel-profil indbygget.** NixOS tilbyder `linuxPackages_hardened` og en række
  sikkerhedsorienterede sysctl-indstillinger som simple, deklarative tilvalg.

### Ulemper og risici ved NixOS

- **Patch-hastighed.** Debian har et dedikeret sikkerhedsteam med et separat, hurtigt
  patch-flow (`debian-security`) uafhængigt af den almindelige pakke-cyklus. Sikkerhedsrettelser i
  Nixpkgs kræver typisk en fuld genopbygning via kanal/flake-pipelinen, hvilket historisk har givet
  længere responstid på akutte CVE'er.
- **Modenhed af hærdningsøkosystemet.** CIS Benchmarks, DISA STIG'er og de fleste praktiske
  hærdningsguides er skrevet med Debian/RHEL-familien som forudsætning (`/etc/sudoers.d/`,
  `/etc/ssh/sshd_config`, standard `auth.log`). Vi kan derfor ikke læne os op ad samme mængde
  velafprøvet praksis.
- **Mismatch med opgavens imperative arbejdsgange.** Flere af opgavens delopgaver og
  dokumentationskrav (håndredigering af `/etc/sudoers.d/`, `ufw status verbose`, bash-scripts der
  selv ændrer systemkonfiguration) er skrevet ud fra en imperativ arbejdsgang, som NixOS'
  deklarative model direkte modarbejder. Dette håndteres eksplicit i det enkelte modul frem for at
  blive underslået.
- **Læringskurve.** Nix-sproget er en ekstra ting at lære oven i selve Linux-stoffet. Vi har vurderet,
  at den ekstra investering er acceptabel, fordi opgavens formål — at kunne begrunde *hvorfor* en
  konfiguration er sikker — understøttes mindst lige så godt af den deklarative model.

### Konklusion

NixOS er valgt, fordi de arkitektoniske fordele (reproducerbarhed, atomare rollbacks, umuliggørelse
af konfigurationsdrift) er direkte relevante sikkerhedsegenskaber, og fordi opgaven selv lægger vægt
på automatisering og "scriptet, ikke klikket sammen". Hvor NixOS' model afviger fra opgavens
forventede arbejdsgang (særligt modul 3, 4 og 6), dokumenterer vi eksplicit hvad forskellen er, og
hvorfor vi vurderer den deklarative løsning som ligeværdig eller stærkere.

## Teknisk arkitektur: opbygning og drift af VM'en

Værtsmaskinen kører CachyOS (Arch-baseret) med KVM-understøttelse verificeret (`/dev/kvm` til stede,
AMD `svm`-flag aktivt). Arbejdet er struktureret i tre faser for at adskille *hvordan VM'en først
skabes* fra *hvordan den løbende ændres*, og for at undgå at låse os selv ude undervejs.

### Fase 1 — Bootstrap (skabelse af VM'en)

Nix pakkehåndteringen installeres på CachyOS-værten (Determinate Systems-installeren). Et disk-image
(qcow2) bygges direkte fra en `flake.nix` med `nixos-generators`, og importeres i libvirt med
`virt-install --import`.

**Begrundelse:** Hele vejen fra tekstfil i git til en kørende, netværkstilgængelig server er dermed
én reproducerbar kommandosekvens uden interaktive eller manuelle trin. Dette er vores stærkeste konkrete
bevis for modul 1's krav om "et rent, kontrolleret og reproducerbart udgangspunkt": VM'en kan slettes
og genskabes identisk fra samme flake, hvilket vi demonstrerer i modul 1's dokumentation.

### Fase 2 — Iteration (løbende ændringer, modul 2-6)

Ændringer foretages ved at redigere `.nix`-filerne på værten, kopiere flake-kilden til VM'en
(`scp -r flake.nix flake.lock nixos admin@<vm-ip>:~/linux101-config/`), og derefter køre
`sudo nixos-rebuild switch --flake ~/linux101-config` **lokalt på VM'en** via SSH.

**Begrundelse:** Dette er samme grundmekanisme som produktionsværktøjer som `deploy-rs` og `colmena`
bruger til deklarativ serverdrift. Hver ændring i systemet bliver et diskret, gennemgåeligt diff i en
konfigurationsfil i stedet for en huskeliste af manuelt udførte shell-kommandoer — hvilket i sig selv
opfylder en del af opgavens dokumentationskrav "af sig selv".

**Arkitektur-revision (modul 4):** Oprindeligt brugte vi `nixos-rebuild switch --target-host
admin@<vm-ip> --elevate=sudo` fra værten, som pusher en færdigbygget konfiguration til VM'en via
`nix-copy-closure` og aktiverer den eksternt. Det krævede `nix.settings.trusted-users = [ "admin" ]`
på VM'en (da root-SSH er deaktiveret, kan man ikke bruge `root@` til at omgå signaturkrav) — men
mekanismen viste sig grundlæggende skrøbelig: `nixos-rebuild-ng` aktiverer en ny konfiguration
eksternt via flere separate, internt indpakkede sudo-kald (bl.a. et `nix-env --set` kald indpakket i
`/bin/sh -c '...'`), som var upraktiske at whitelfoste præcist i sudoers — et forsøg så korrekt ud i
`sudo -l`, men fejlede ved et ægte efterfølgende deploy. Vi droppede derfor `--target-host` helt til
fordel for ovenstående: kopiér kilden, kør værktøjet lokalt under ét enkelt, fast sudo-kald. Det
gjorde `trusted-users`-indstillingen overflødig (fjernet igen fra `nixos/configuration.nix`) og
kræver kun én simpel, stabil sudoers-regel i stedet for flere skrøbelige.

### Fase 3 — Sikkerhedsnet

Før en risikabel ændring (firewall-regler, sudo-rettigheder) sendes til den rigtige VM, testes den
først lokalt med `nixos-rebuild build-vm`, som bygger en midlertidig, isoleret QEMU-instans fra den
kandiderede konfiguration uden at røre den rigtige VM's disk.

**Begrundelse:** En fejl i firewall- eller SSH-konfiguration kan i værste fald låse os ude af den
eneste VM, vi arbejder i. Denne fase er en billig forsikring mod at skulle rette fejlen via
libvirt-konsollen.

### Ressourcetildeling

VM'en tildeles 2 vCPU, 3-4 GB RAM og 20 GB disk (qcow2), hvilket er rigeligt givet værtens
tilgængelige ressourcer (14 GB RAM, 268 GB fri diskplads).

## Repo-struktur

```
Linux_101/
├── docs/
│   ├── 00-tilgang.md                          (dette dokument — overordnet metodevalg)
│   ├── 01-vm-og-netvaerk.md                   (modul 1)
│   ├── 02-filsystem-og-adgangskontrol.md      (modul 2)
│   ├── 03-brugere-og-grupper.md               (modul 3)
│   ├── 04-firewall-og-netvaerkssikkerhed.md   (modul 4)
│   ├── 05-overvaagning-og-logging.md          (modul 5)
│   └── 06-shell-og-bash-scripting.md          (modul 6)
├── flake.nix                  (pinner nixpkgs, definerer VM'ens nixosConfiguration + qcow-build)
├── nixos/
│   ├── configuration.nix      (importerer modulerne nedenfor)
│   ├── hardware-vm.nix        (disk/bootloader-profil for nixos-rebuild switch, se modul 1)
│   └── modules/
│       ├── network.nix        (modul 1: hostname, statisk IP, sshd)
│       ├── users.nix          (modul 1/3: admin-bruger, sudo — udbygges i modul 3)
│       ├── filesystem.nix     (modul 2: delt mappe, ACL-demo-bruger)
│       ├── firewall.nix       (modul 4: networking.firewall)
│       └── monitoring.nix     (modul 5: logrotate/journald, overvågning)
└── scripts/
    ├── setup.sh               (modul 6 — idempotent VM-bootstrap, kørt på værten)
    ├── healthcheck.sh         (modul 6 — almindeligt bash, uændret relevant på NixOS)
    └── verify-deploy.sh       (modul 6 — se argumentation i 06-shell-og-bash-scripting.md)
```

Ved aflevering samles alle filer i `docs/` til ét dokument. Da filnavnene er nummereret, sorterer et
simpelt wildcard korrekt i modulrækkefølge. Kommandoen køres fra `docs/`-mappen (ikke fra
repo-roden), så relative billedstier til `screenshots/` kan resolves korrekt af pandoc:
`cd docs && pandoc *.md -o ../aflevering.odt --toc`.
