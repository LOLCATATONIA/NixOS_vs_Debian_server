# Plan: Sammenlign backup-strategi mellem Debian og NixOS

**Status: kun en formodning indtil videre, kræver reel research før konklusionen kan stå i
syntesen.** Opstået som en naturlig forlængelse af `guide.md`s "Hvis noget går grueligt galt: fuld
genopbygning"-afsnit.

## Hypotese, endnu ikke efterprøvet

NixOS deler i praksis "backup" op i to adskilte problemer: den *deklarerede* konfiguration er
allerede reelt sikkerhedskopieret, bare ved at ligge i git (kan genskabes fuldstændigt fra
`flake.nix`/`flake.lock`), så det eneste der reelt kræver traditionel backup er *ægte,
ikke-deklareret data* (fx indholdet i `/srv/projekt`). Debian har ingen tilsvarende indbygget
adskillelse, konfiguration og data ligger side om side som almindelige filer i det samme
filsystem, uden nogen strukturel markør for hvad der er "genskabeligt" og hvad der ikke er.

## Hvorfor det er værd at undersøge

Matcher projektets egen metode: en påstand, der lyder plausibel, men endnu ikke er testet.
Hænger naturligt sammen med `09-reproducerbarhedstest.md` og `10-disaster-recovery-maaling.md`,
tre forskellige vinkler på samme underliggende spørgsmål: hvad er den reelle, minimale mængde
tilstand, der ikke kan genskabes fra kilden alene?

## Research, før noget konkluderes

1. **Identificér præcist, hvad der IKKE kan genskabes fra hver platforms kilde alene.** For
   NixOS: gennemgå `flake.nix`/`nixos/modules/*.nix` og find alt, der ikke er deklareret, men som
   findes på den kørende VM (fx `/srv/projekt`s indhold, `monitor.log`, brugerdata). For Debian:
   samme øvelse mod `08-debian-provision.sh`.
2. **Test SSH-værtsnøglerne specifikt, muligvis den mest interessante enkeltdel.** Er NixOS-VM'ens
   SSH-værtsnøgle deklareret nogen steder, eller genereres den ved første boot, præcis som
   `mkfs.ext4`s tilfældige filsystem-UUID (allerede dokumenteret som ikke-reproducerbar i
   `09-reproducerbarhedstest.md`)? Efterprøv direkte: byg `.#qcow` to gange, sammenlign
   værtsnøglerne. Hvis de IKKE er identiske, er det et vigtigt, ærligt modstykke til hypotesen,
   selv NixOS' "alt er deklareret"-model har mindst én reel undtagelse.
3. **Undersøg om der findes et navngivet, etableret NixOS-mønster for netop denne adskillelse.**
   Fx `impermanence`-mønsteret (root-filsystem som `tmpfs`, kun eksplicit whitelistede stier
   overlever en genstart), som gør adskillelsen mellem "genskabeligt" og "skal sikkerhedskopieres"
   til en håndgribelig, teknisk mekanisme i stedet for kun en arkitektonisk pointe. Vurdér om det
   er relevant at nævne som perspektivering, uden nødvendigvis selv at implementere det.
4. **Overvej det traditionelle Debian-perspektiv retfærdigt.** Værktøjer som `rsync`, `tar`,
   `BorgBackup` eller `Bacula` løser reelt det samme problem (kun sikkerhedskopiér det, der har
   ændret sig/ikke kan genskabes andetsteds), blot uden en indbygget, sproglig adskillelse mellem
   "konfiguration" og "data". Er det en reel ulempe, eller blot en anden, lige så gyldig løsning på
   samme problem? Undgå at konkludere for hurtigt til NixOS' fordel.

## Estimeret indsats

Middel til høj, ren research (trin 1, 3, 4) er overkommelig, men trin 2 (den faktiske
værtsnøgle-test) kræver en ny `.qcow`-bygning og sammenligning, samme mønster som
`09-reproducerbarhedstest.md`.

## Åbne spørgsmål

- Skal konklusionen kun være kategorisering/analyse, eller skal det demonstreres konkret med et
  faktisk backup-værktøj kørt mod begge VM'er?
- Er dette for stort et sidespor givet den resterende tid, eller er værtsnøgle-testen (trin 2)
  alene interessant nok til at stå alene, uafhængigt af de større, mere tidskrævende trin?
