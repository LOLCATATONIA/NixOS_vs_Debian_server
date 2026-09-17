# Plan: Manglende officielle hærdningsstandarder for NixOS

## Mål

Undersøg og dokumentér konkret, hvad status er for CIS Benchmarks/DISA STIGs/OpenSCAP-profiler for
NixOS sammenlignet med Debian/RHEL, som en ærlig, konkret ulempe i tesen.

## Hvorfor det er værd at gøre

Sammenligningstabellen nævner allerede "Mindre modent end for Debian/RHEL" under
"Hærdningsøkosystem (CIS/STIG)", men det er en vag påstand uden konkret substans. For en
organisation med compliance-krav (fx ISO 27001, som allerede nævnes andetsteds i projektet) er
fraværet af en navngiven, auditerbar standard en reel, konkret forretningsmæssig ulempe, ikke kun
en teknisk detalje. At underbygge den konkret gør ulempe-siden af tesen lige så solid som
fordel-siden.

## Trin

1. Bekræft/afkræft: findes der en officiel CIS Benchmark for NixOS? (Forventning: nej.)
2. Undersøg om der findes uofficielle/community-drevne hærdningsguides eller -moduler for NixOS
   (fx søg efter "nixos hardening", relevante flake-inputs eller NixOS-moduler i nixpkgs selv, som
   `security.*`-optioner der eksplicit refererer til CIS/STIG-kontrolpunkter).
3. Sammenlign med hvor modent økosystemet er for Debian/Ubuntu (officiel CIS Benchmark findes,
   `ubuntu-cis`/`ansible-lockdown`-projekter osv.), som en direkte kontrast.
4. Vurder om NOGLE af opgavens egne seks moduler reelt dækker konkrete CIS-kontrolpunkter, og nævn
   i så fald hvilke, som en delvis modvægt (dvs. selvom der ikke findes en formel NixOS-benchmark,
   er de underliggende sikkerhedsprincipper stadig demonstrerbart opfyldt).
5. Skriv en kort, kildehenvisende sektion (ikke bare en påstand) til brug i tesen.

## Estimeret indsats

Lav til middel, ren research.

## Åbne spørgsmål

- Skal vi selv forsøge at mappe et par af opgavens seks moduler til specifikke, navngivne
  CIS-kontrolpunkter, som en lille demonstration af "principperne er der, blot ikke en formel
  certificering"? Kunne være en stærk, konkret pointe, men kræver at finde og læse den relevante
  del af en offentligt tilgængelig CIS-benchmark.
