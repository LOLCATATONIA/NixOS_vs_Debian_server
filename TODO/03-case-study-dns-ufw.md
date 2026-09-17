# Plan: Fremhæv DNS/ufw-fejlfindingen som en synlig case-story

## Mål

Løft den allerede dokumenterede DNS/ufw-fejlfinding (`docs/04-firewall-og-netvaerkssikkerhed.md`,
Addendum 2) fra at være begravet i den interne logbog til at være synligt fremhævet et sted, en
arbejdsgiver/interviewer rent faktisk ser.

## Hvorfor det er værd at gøre

Dette er det bedste konkrete beviseksempel for hele projektets tese, ikke kun en god anekdote:
selve fejlen lå i værtens traditionelle, imperativt opbyggede `ufw` (regler tilføjet ad hoc over
tid via enkeltstående kommandoer, ingen samlet oversigt), mens den deklarative NixOS-side
(`firewall.nix`) var korrekt hele vejen igennem. Det er en direkte, levet illustration af projektets
eget argument fra `00-tilgang.md`s "Samlet billede"-afsnit: konfigurationsdrift/uigennemsigtighed
som en reel sikkerhedsomkostning, ikke kun en teoretisk pointe. Det er også præcis den slags
"fortæl om en svær bug du løste"-materiale, en teknisk interviewer leder efter.

Indholdet findes allerede, dette er næsten gratis at gøre, det mangler bare at blive fremhævet et
sted synligt.

## Trin

1. Skriv en kort, selvstændig version af historien (kortere end `docs`-addendummet, som er skrevet
   til intern logbogsbrug): symptom → indsnævring af problemet → rodårsag → fix → hvad det beviser
   om deklarativ vs. imperativ konfiguration.
2. Placér den synligt: enten som en fremhævet sektion øverst i `README.md` ("Highlights"), eller som
   et separat afsnit på `index.html` (GitHub Pages-siden) med et direkte link fra README'en. Undgå
   at duplikere hele addendummet, link i stedet til `docs/04` for det fulde forløb.
3. Skriv den i en stil, der giver mening for en læser UDEN forudgående kontekst om projektet (i
   modsætning til `docs`-versionen, som forudsætter man har læst resten af modul 4).

## Estimeret indsats

Lav. Ren skrive-/redigeringsopgave, ingen ny teknisk research.

## Åbne spørgsmål

- Skal den skrives på dansk (som resten af projektet) eller engelsk (hvis målgruppen for
  porteføljen inkluderer ikke-danske arbejdsgivere)?
