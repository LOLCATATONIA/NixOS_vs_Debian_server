# Linux 101: NixOS vs. Debian

Design, hærdning og overvågning af en Linux-server, implementeret deklarativt i NixOS
(i stedet for det foreslåede Debian/Ubuntu), med løbende sammenligning mellem de to
tilgange i hvert modul.

**[Læs rapporten](https://lolcatatonia.github.io/NixOS_vs_Debian_server/)**
**[Driftsguide til begge VM'er](https://lolcatatonia.github.io/NixOS_vs_Debian_server/guide.html)**

## Struktur

| Mappe | Indhold |
|---|---|
| `report/` | Rapporten (kildefiler + byggescript til `index.html`) |
| `docs/` | Uddybende teknisk logbog: fejl, fund og beslutninger undervejs |
| `nixos/` | Den deklarative serverkonfiguration (`configuration.nix` + moduler) |
| `scripts/` | Driftsscripts: opsætning, healthcheck, overvågning, driftsverifikation |
| `TODO/` | Planer og resultater for det udvidede sammenligningsarbejde (NixOS vs. Debian) |
| `guide.md` / `guide.html` | Driftsguide til begge VM'er, side om side |
| `flake.nix` / `flake.lock` | Reproducerbar definition af NixOS-VM'en |
