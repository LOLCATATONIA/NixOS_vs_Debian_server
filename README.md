# Linux 101: NixOS vs. Debian

Design, hærdning og overvågning af en Linux-server, implementeret deklarativt i NixOS
(i stedet for det foreslåede Debian/Ubuntu), med løbende sammenligning mellem de to
tilgange i hvert modul.

**[Læs rapporten](https://lolcatatonia.github.io/NixOS_vs_Debian_server/)**

## Struktur

| Mappe | Indhold |
|---|---|
| `report/` | Rapporten (kildefiler + byggescripts til `.html` og `.odt`) |
| `docs/` | Uddybende teknisk logbog: fejl, fund og beslutninger undervejs |
| `nixos/` | Den deklarative serverkonfiguration (`configuration.nix` + moduler) |
| `scripts/` | Driftsscripts: opsætning, healthcheck, overvågning, driftsverifikation |
| `flake.nix` / `flake.lock` | Reproducerbar definition af hele VM'en |
