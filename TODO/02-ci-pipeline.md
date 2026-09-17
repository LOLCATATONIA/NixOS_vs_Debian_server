# Plan: CI-pipeline (GitHub Actions)

## Mål

`nix flake check` og `shellcheck scripts/*.sh` kører automatisk på hvert push til `main`.

## Hvorfor det er værd at gøre

Et portefølje-repo uden CI ser i dag ufærdigt ud for enhver, der har arbejdet professionelt med
infrastruktur. Men den reelle pointe, der skal frem i dokumentationen, er ikke "CI er god skik"
generisk (det gør Debian-shops med Ansible+Molecule også), det er at Nix' evalueringsfase fanger en
hel klasse af fejl statisk, FØR noget rammer en maskine, fx den lockout-forhindrende assertion, vi
selv ramte i modul 3. Det er argumentet, der skal fremhæves.

## Den elegante detalje

Hvis testene fra `01-nixos-tests.md` registreres som `checks` i `flake.nix`, kører `nix flake check`
dem automatisk. CI-pipelinen bliver derfor bare: `nix flake check` (fanger BÅDE eval-fejl og
VM-testene) + `shellcheck`. Ét mekanisme, ikke to adskilte. Værd at fremhæve som et bevidst
designvalg i dokumentationen.

## Reel risiko at afklare tidligt

GitHub Actions' Linux-runners understøtter i dag KVM, men det skal verificeres direkte med en
triviel testkørsel, før vi bygger en hel workflow-fil ovenpå antagelsen. Uden KVM falder QEMU
tilbage til software-emulering, hvilket kan gøre VM-testene meget langsomme eller få dem til at
time out i CI.

## Trin

1. Lav `.github/workflows/ci.yml` med to jobs: `flake-check` (`nix flake check`, kræver
   `nix-command flakes`-eksperimentelle features aktiveret) og `shellcheck` (kør på alle filer i
   `scripts/`).
2. Brug en etableret Nix-installations-action (fx `DeterminateSystems/nix-installer-action` eller
   `cachix/install-nix-action`), pinnet til en specifik version, ikke `@main`.
3. Verificér KVM-tilgængelighed som første, isolerede skridt, før `01-nixos-tests.md`s tests
   forbindes til denne pipeline.
4. Overvej caching (GitHub Actions' indbyggede `actions/cache`, eller Cachix) hvis VM-testene gør
   pipelinen mærkbart langsom.
5. Tilføj et CI-status-badge til `README.md`.

## Rækkefølge ift. andre planer

Afhænger af `01-nixos-tests.md` for den fulde `nix flake check`-integration, men `shellcheck`-jobbet
kan laves uafhængigt og først, som en hurtig, lav-risiko sejr.

## Estimeret indsats

Lav til middel, forudsat KVM virker uden problemer i CI-miljøet.

## Åbne spørgsmål

- Skal pipelinen også køre på pull requests, eller kun på push til `main`? Givet det er et
  solo-repo med direkte pushes, er push-til-main formentlig tilstrækkeligt.
