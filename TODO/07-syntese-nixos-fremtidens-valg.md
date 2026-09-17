# Plan: Det samlende afsnit — "Er NixOS fremtidens sikrere valg?"

## Mål

Et nyt, eksplicit kapitel/afsnit i rapporten (ikke kun spredt ud over de seks moduler), der samler
hele projektets erfaring til et egentligt, afbalanceret svar på spørgsmålet, med respekt for at
argumentet skal underbygge fordelagtigheden OG ærligt adressere ulemperne.

## Hvorfor det er værd at gøre

Dette er selve kernen i porteføljeværdien: ikke "vi fulgte en opgavebeskrivelse", men "vi undersøgte
et reelt, åbent spørgsmål med en metodisk, evidensbaseret tilgang, og nåede frem til en nuanceret
konklusion". Det er det afsnit, en arbejdsgiver rent faktisk vil læse først.

## Indhold, skal trække på resten af ugens arbejde

**Fordele, med konkret evidens (ikke kun påstande):**
- Deklarativ verifikation som kode (`01-nixos-tests.md`), sikkerhedsegenskaber udtrykt i samme
  sprog som konfigurationen.
- Statisk fejlfangst ved evaluering (`02-ci-pipeline.md`), fanger en klasse af fejl før deploy.
- Konfigurationsdrift/-uigennemsigtighed som reel sikkerhedsrisiko, dokumenteret ved et ægte,
  levet eksempel (`03-case-study-dns-ufw.md`), hvor fejlen lå i den traditionelle, imperative
  ufw-opsætning, ikke i NixOS.
- De originale seks moduler egne sammenligningstabeller (reproducerbarhed, rollback, atomare
  generationer, `flake.lock`).

**Ulemper, ærligt og konkret underbygget:**
- Patch-hastighed, med et faktisk efterprøvet eksempel (`04-cve-patch-latency.md`), ikke kun en
  antagelse.
- Manglende officielle hærdningsstandarder/compliance-certificering (`05-hardening-standards-gap.md`).
- Secrets-håndtering kræver ekstra værktøj og viden (`06-secrets-management.md`).
- Bemandings-/videns-risiko: færre sysadmins kender NixOS, hvilket er en reel driftsmæssig risiko
  ved overdragelse, oncall og rekruttering, ikke kun en indlæringskurve for én person. (Ny pointe,
  ingen separat plan nødvendig, skrives direkte i syntesen.)
- Et ekstra fejlfindingslag: flere af projektets egne fund (sudoers-scoping, lockout-assertion i
  modul 3, DNS/ufw-sagaen) krævede forståelse af BÅDE almindelig Linux-fejlfinding OG Nix' eget lag
  (derivations, generationer, evaluering). Ærlig omkostning, selvom egen erfaring viser gevinsten
  (rollback, reproducerbarhed) typisk opvejede den. (Ny pointe, ingen separat plan nødvendig.)

**Konklusion:** Skal være en reel, nuanceret stillingtagen, ikke en konfliktfri "det kommer an på
behovet"-udvanding. Overvej at formulere det som: for hvilken type organisation/scenarie er NixOS
det bedre valg, og for hvilken er den traditionelle tilgang stadig at foretrække, baseret på den
indsamlede evidens.

## Rækkefølge

Skrives SIDST, efter planerne `01`-`06` er gennemført eller i det mindste undersøgt, siden dette
afsnit er syntesen af dem, ikke en uafhængig opgave.

## Estimeret indsats

Middel til høj, dette er skrivearbejde der kræver at veje og formulere en reel konklusion, ikke
bare liste punkter op.
