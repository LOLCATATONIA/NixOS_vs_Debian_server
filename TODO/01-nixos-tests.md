# Plan: Deklarative NixOS-tests (`pkgs.nixosTest`)

## Mål

Erstat/supplér manuelt fangede beviser (screenshots, terminal-transskripter) med automatiske,
deklarative tests, der selv bygger en midlertidig VM fra `configuration.nix` og asserterer
konkrete sikkerhedsegenskaber.

## Hvorfor det er værd at gøre

Beviser at sikkerhedsegenskaber kan udtrykkes som kode i samme sprog som selve konfigurationen,
i modsætning til compliance-værktøjer der er klistret ovenpå en traditionel opsætning (fx
InSpec/OpenSCAP for Debian). Det er det stærkeste konkrete "NixOS gør noget strukturelt anderledes"
-argument i hele projektet, og meget få ansøgere kender til denne del af Nix-økosystemet.

**Den strukturelle pointe, ikke kun en bekvemmelighed:** På Debian findes ingen indbygget vej til
at teste konfigurationen direkte. Man må ty til et helt separat værktøj (typisk Ansible +
Molecule), med sit eget sprog og sin egen repræsentation af "ønsket tilstand", som skal
vedligeholdes manuelt i sync med den rigtige konfiguration, to kilder til sandhed, der kan glide fra
hinanden. På NixOS er testen og konfigurationen bogstaveligt talt samme fil (`configuration.nix`
importeres direkte ind i testen). Det er forskellen mellem "kan opnås med ekstra, adskilt værktøj"
og "er indbygget i selve platformen".

## Vigtig arkitektonisk pointe (skal med i dokumentationen)

`pkgs.nixosTest` bygger sin egen midlertidige VM direkte fra `configuration.nix`, via QEMU i Nix'
build-sandbox. Det er IKKE den samme håndbyggede libvirt-VM (`linux101-srv`), vi har arbejdet med
resten af projektet. Det er en pointe, ikke en svaghed: testene beviser at *selve deklarationen* er
korrekt og reproducerbar, uafhængig af den specifikke maskine. De erstatter derfor ikke de manuelle
beviser i rapporten, de supplerer dem, medmindre vi bevidst beslutter at omskrive rapportens
bevisførelse til udelukkende at pege på testene.

## Omfang (foreslået, ikke alle 6 moduler)

Prioritér de egenskaber, der er nemmest at overse manuelt, men nemme at assertere automatisk, og
som allerede overlapper med `healthcheck.sh`:

1. SSH kun tilgængelig på port 2222 (ikke 22).
2. SSH kun tilgængeligt fra godkendt kilde-IP (`192.168.122.1`), afvist fra andre.
3. Root-login afvist, selv med gyldig nøgle.
4. Password-autentifikation afvist.
5. Ingen brugere med UID 0 udover root.
6. (Stretch) Firewall default-deny: ingen andre porte svarer.

## Trin

1. Verificér først at KVM/nested virtualisering er tilgængelig lokalt (den er, vi har allerede en
   fungerende Nix-opsætning), og få ÉN triviel test til at køre og bestå, før flere tilføjes.
2. Skriv testene i `tests/*.nix`, importér `configuration.nix` direkte (ikke en kopi).
3. Registrér dem som `checks.x86_64-linux.<navn>` i `flake.nix`, så `nix flake check` kører dem
   automatisk, lokalt, uden behov for en separat CI-pipeline.
4. Dokumentér i `docs/` (nyt modul eller tilføjelse til modul 4/6): hvad testene beviser, hvordan de
   køres lokalt (`nix flake check` eller `nix build .#checks.x86_64-linux.<navn>`), og eksempel på
   både en bestået og en bevidst fejlende test (for at bevise at testene faktisk fanger noget, samme
   metode som resten af projektet).

## Rækkefølge ift. andre planer

Uafhængig af de øvrige planer, kan gennemføres når som helst i ugen.

## Estimeret indsats

Middel. Selve test-DSL'en (Python-baseret `testScript`) er ny syntaks at lære, men konceptuelt
ligetil givet vi allerede kender `configuration.nix` godt.

## Åbne spørgsmål

- Skal testene også dække modul 2/3 (ACL, sudo-granularitet)? Sværere at assertere maskinelt end
  netværks-/firewall-egenskaber, kræver mere omtanke.
