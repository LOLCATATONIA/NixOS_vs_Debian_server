# Plan: Secrets-håndtering, en ærlig gap-analyse

## Mål

Dokumentér en konkret, reel svaghed ved den nuværende opsætning (ingen hemmeligheder er
nødvendige i dette projekt, men det ville blive et problem i en virkelig udrulning), og hvordan
NixOS-økosystemet reelt løser det.

## Hvorfor det er værd at gøre

`/nix/store` er læsbart for alle systemets brugere by design (indholdsadresseret lager, ikke
adgangsstyret som traditionelle filer). At lægge en hemmelighed (adgangskode, API-nøgle,
TLS-privatnøgle) direkte i en `.nix`-fil ville betyde, at den havner i klartekst i
`/nix/store`, læsbar af enhver lokal bruger, og desuden i `flake.lock`-historikken i git. Det er en
kendt, dokumenteret faldgrube for nye NixOS-brugere, og en reel ulempe sammenlignet med traditionel
secrets-håndtering (fx en fil i `/etc` med `chmod 600`), som er mere "indbygget" i den vante
arbejdsgang uden ekstra værktøj.

## Trin

1. Undersøg og beskriv kort de to primære community-løsninger: `agenix` (SSH-nøglebaseret
   kryptering, integreret i NixOS-moduler) og `sops-nix` (baseret på Mozilla SOPS, understøtter
   flere nøgle-backends).
2. Vurder om det er realistisk at demonstrere ÉN af dem konkret i den resterende uge (fx kryptere en
   triviel testhemmelighed med `agenix` og vise at den korrekt dekrypteres ved
   `nixos-rebuild switch`, uden at ligge i klartekst i `/nix/store`), eller om det er nok at
   dokumentere gap'et og løsningen teoretisk, givet at projektet reelt ikke har brug for hemmeligheder
   endnu.
3. Skriv en kort sektion, der ærligt indrømmer at dette IKKE er løst i den nuværende opsætning
   (fordi der ikke var behov for det), men viser at der findes en moden, veletableret vej til at
   løse det, hvis/når behovet opstår.

## Estimeret indsats

Lav (kun dokumentation) til middel (hvis en faktisk `agenix`-demonstration inkluderes).

## Åbne spørgsmål

- Er en faktisk demonstration det værd, eller er en velskrevet, ærlig gap-beskrivelse tilstrækkelig
  givet den begrænsede tid? En demonstration er stærkere bevis, men kræver ekstra opsætning
  (SSH-nøgler til `agenix`, en `secrets.nix`, osv.) for noget, projektet reelt ikke har brug for.
