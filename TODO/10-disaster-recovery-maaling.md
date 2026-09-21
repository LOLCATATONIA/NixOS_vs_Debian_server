# Plan: Mål disaster recovery-tid (RTO) konkret

## Mål

Tag reelt tid på en fuld genopbygning af `linux101-srv` fra bunden (`./scripts/setup.sh`), og
rapportér det som en konkret RTO-metrik (Recovery Time Objective), i stedet for kun at påstå
"hurtig gendannelse" som en fordel.

## Hvorfor det er værd at gøre

Modul 1 og 6 påstår begge, direkte eller indirekte, at det "slet og genskab fra flake"-mønster er
en reel driftsmæssig fordel. Et konkret tidstal gør den påstand langt stærkere, og er billigt at
producere, da scriptet allerede findes og er testet flere gange gennem projektet.

**Den strukturelle pointe bag tallet:** RTO-forskellen er ikke bare "NixOS er hurtigere", den er en
konsekvens af en evne, opgavens egen foreslåede "vanilla" Debian-arbejdsgang (installer, `useradd`,
redigér filer manuelt) slet ikke har indbygget. Der findes intet i en almindelig Debian-opsætning,
der svarer til "genskab hele systemet fra bunden med én kommando", det kræver at man selv bygger og
vedligeholder den infrastruktur (Ansible-roller, Packer-images), hvilket er et helt separat projekt
oven på selve serveropsætningen. Formulér derfor RTO-tallet som konsekvensen af en manglende evne i
den traditionelle arbejdsgang, ikke kun som et tal, der tilfældigvis er lavere.

## Trin

1. Kør `time ./scripts/setup.sh` fra en kold start (VM'en må gerne allerede eksistere, scriptet
   river den ned og genopbygger den, som allerede demonstreret i modul 6).
2. Opdel tiden i faser, hvis muligt (byg af diskimage vs. import/opstart i libvirt), for at vise
   hvor tiden reelt går hen, ikke kun et samlet tal.
3. Sammenlign (kvalitativt, medmindre `DONE/08-debian-ab-sammenligning.md` gennemføres) med hvor lang tid
   en tilsvarende manuel Debian-genopsætning ville tage, baseret på erfaringen fra de seks moduler.
4. Dokumentér som et konkret RTO-tal i syntese-afsnittet (`07`), med den fulde terminal-output som
   bevis, samme stil som resten af projektet.

## Rækkefølge ift. andre planer

Meget billig at udføre uafhængigt af de andre planer. Bliver stærkere, hvis den kan sammenlignes
direkte med et tilsvarende Debian-tal fra `DONE/08-debian-ab-sammenligning.md`.

## Estimeret indsats

Lav. Scriptet findes allerede og er verificeret at virke.

## Åbne spørgsmål

- Skal målingen gentages flere gange for at få et gennemsnit/udsving, eller er én kørsel
  tilstrækkelig som et illustrativt datapunkt?
