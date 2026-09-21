# Plan: Empirisk hærdningsaudit (CIS/STIG-tilnærmelse) af begge VM'er

**Status: åbent, ikke undersøgt endnu.** Opstået fra en gennemgang af `NixOS_CIS.md` (ekstern
research), hvis centrale påstande er verificeret via uafhængige kilder (se nedenfor), men som endnu
ikke er testet **empirisk mod vores egne to VM'er**. Rapportens nuværende "Hærdningsøkosystem
(CIS/STIG)"-række er en generel, sekundær påstand, ikke et resultat af at have kørt noget som helst
mod `linux101-srv`/`debian-comparison`.

## Baggrund, allerede verificeret (sekundær research, ikke egen test)

- CIS udgiver en officiel, distributionsuafhængig **"Distribution Independent Linux" benchmark
  (v2.0.0, 2019)**, med Level 1/2-profiler til server/workstation. Ingen NixOS-specifik oversættelse
  findes, men princippet dækker enhver Linux-distro.
- NixOS fjernede selv sin indbyggede `profiles.hardened`/`linux_hardened`-kerne i **26.05**, med den
  eksplicitte begrundelse at den manglede en konsistent baseline og introducerede uventet breakage —
  bekræftet i de officielle release notes.
- Et 2015-GitHub-issue (`NixOS/nixpkgs#11790`) om CIS-benchmarking af NixOS er stadig åbent, og
  nævner allerede dengang at SELinux-afhængige kontroller ikke er anvendelige på NixOS.
- To reelle, aktive community-/statslige hærdningsprojekter findes (`nix-mineral`, alpha; SécurixOS
  fra det franske DINUM, ANSSI-baseret, med rigtige udgivelser op til v0.11-beta2) — hærdning sker
  altså faktisk på NixOS, blot ikke udtrykt som en CIS/STIG-profil.

## Hvorfor det er værd at gøre nu

Hele projektets metode er at teste, ikke antage. Vi har nu en solidt underbygget, men **kun
sekundær** konklusion om hærdningsøkosystemet. Det er den eneste større sammenligningspåstand i
rapporten, der udelukkende hviler på andres research, ikke på noget kørt mod vores egne VM'er. En
faktisk audit ville enten bekræfte, nuancere eller direkte modsige den nuværende antagelse — alle tre
udfald er brugbare, jf. projektets egen regel om at være ærlig, hvis noget ikke bekræftes.

## Trin

1. **Vælg værktøj:** `lynis` (har eksplicit NixOS-genkendelse, pakket i nixpkgs, ingen
   distro-specifik profil nødvendig) som primært værktøj. Overvej `dev-sec/cis-dil-benchmark`
   (InSpec-profil for CIS DIL 2.0.0) som sekundært forsøg, med forventning om at en del kontroller
   fejler/er "not applicable" pga. forskellig implementeringsmodel (kendt, dokumenteret begrænsning,
   ikke en overraskelse hvis det sker).
2. **Kør mod NixOS-siden:** tilføj `lynis` til `environment.systemPackages` (midlertidigt, eller i en
   dedikeret audit-gren), `nixos-rebuild switch`, kør `lynis audit system`, gem det fulde output.
3. **Kør samme værktøj mod Debian-siden** (`apt install lynis`, samme kommando), for en reel,
   side-om-side sammenligning på samme værktøj — ikke kun to forskellige økosystemers påstande om
   sig selv.
4. **Sammenlign konkret:** hvilke kontroller består/fejler på hver platform, og *hvorfor* — skeln
   eksplicit mellem "reelt usikker konfiguration" og "værktøjet kender ikke NixOS' model" (fx
   forventer et bestemt stinavn eller en pakke-manager-kommando, der ikke findes på NixOS). Denne
   skelnen er selve pointen fra `NixOS_CIS.md`, og skal bevises, ikke kun gentages.
5. **Opdatér rapporten** med det faktiske resultat (score, konkrete fund, den kvalificerede
   konklusion), i stedet for den nuværende generelle tabelrække.

## Estimeret indsats

Middel. Lynis-installation og -kørsel er hurtig (under en time inkl. begge VM'er), men at
gennemgå og korrekt klassificere hvert fund (reelt problem vs. værktøjs-blind-vinkel) tager tid og
kræver omtanke, samme type arbejde som `DONE/08-resultater-modul1-6.md`.

## Åbne spørgsmål

- Er Lynis nok alene, eller bør `cis-dil-benchmark`-forsøget også gennemføres, selvom det er
  forældet (sidst opdateret 2022)? Et mislykket forsøg er stadig et dokumenterbart resultat.
- Skal denne audit også forholde sig til SELinux/AppArmor-gabet konkret (fx ved at forsøge at
  aktivere AppArmor på NixOS-siden og se hvor langt det rækker), eller er det for stort et sidespor?
- Hvor i rapporten hører resultatet bedst hjemme — som en udvidelse af `00-tilgang.md`s tabelrække,
  eller som sit eget lille afsnit, givet at det er et cross-cutting fund, ikke ét modul?
