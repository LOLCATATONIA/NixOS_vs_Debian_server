# Plan: Reel A/B-sammenligning mod en faktisk Debian-VM

## Mål

Genopsæt alle seks moduler manuelt på en rigtig Debian-server (den platform, opgaven oprindeligt
foreslog), og mål forskellen konkret i stedet for kun teoretisk. Dette er selve eksperimentet, hele
tesen ("er NixOS fremtidens sikrere valg?") reelt spørger om.

## Hvorfor det er værd at gøre

Alt andet i projektet indtil nu er enten (a) en teoretisk sammenligningstabel, eller (b) evidens fra
NixOS-siden alene. Denne opgave er den eneste, der reelt genererer et A/B-datapunkt: samme seks
opgaver, to platforme, målt likt. Det er den stærkeste tænkelige evidens for tesen, men også den
dyreste post på listen.

## Trin

1. Opsæt en ny, ren Debian-VM (samme værtsplatform, QEMU/KVM via libvirt, samme ressourcer som
   `linux101-srv`, for at holde sammenligningen fair).
2. Gennemfør modul 1-6 manuelt, imperativt, præcis som opgavebeskrivelsen oprindeligt lægger op til
   (installer, `useradd`, redigér `sshd_config`, `ufw`, `crontab`, egne bash-scripts).
3. Log undervejs, for hvert modul: antal kommandoer kørt, antal filer redigeret/oprettet, tid brugt,
   og eventuelle fejl/gentagne forsøg undervejs (vær ærlig, også når Debian-vejen er nem).
4. Efter begge platforme er færdige, lav en direkte sammenligningstabel: samme metrikker, side om
   side, med konkrete tal, ikke kun kvalitative udsagn.
5. Vær åben for at resultatet kan være blandet, nogle moduler kan vise sig lige nemme eller
   nemmere på Debian. Det er et validt og mere troværdigt resultat end en tese, der vinder på alle
   punkter.

## Rækkefølge ift. andre planer

Bør ske sideløbende med eller efter `09-reproducerbarhedstest.md` og
`10-disaster-recovery-maaling.md` (som kan udføres på den eksisterende NixOS-VM uden ekstra
opsætning), og fodrer direkte ind i `07-syntese-nixos-fremtidens-valg.md`.

## Estimeret indsats

Høj. Dette er reelt at gennemføre en stor del af den oprindelige opgave en gang til, på en anden
platform. Overvej at afgrænse til de moduler, hvor forskellen forventes størst (fx modul 3 og 4,
bruger/sudo-granularitet og firewall), hvis en uge ikke rækker til alle seks.

## Åbne spørgsmål

- Skal ALLE seks moduler gentages på Debian, eller et udvalgt, repræsentativt undersæt, givet
  tidsbegrænsningen?
- Skal Debian-opsætningen også dokumenteres i `docs/`/`report/`, eller kun bruges internt til at
  generere sammenligningstallene til syntese-afsnittet?
