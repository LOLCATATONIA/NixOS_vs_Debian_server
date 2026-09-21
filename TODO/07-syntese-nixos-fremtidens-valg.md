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
- Konfigurationsdrift/-uigennemsigtighed som reel sikkerhedsrisiko, dokumenteret ved et ægte,
  levet eksempel (`03-case-study-dns-ufw.md`), hvor fejlen lå i den traditionelle, imperative
  ufw-opsætning, ikke i NixOS.
- Reproducerbarhed, faktisk efterprøvet med et diff, ikke kun påstået (`DONE/09-reproducerbarhedstest.md`).
- Hurtig, målt gendannelsestid som konkret RTO-tal (`10-disaster-recovery-maaling.md`).
- Den direkte A/B-sammenligning mod en faktisk Debian-opsætning (`DONE/08-debian-ab-sammenligning.md`),
  hvor det er relevant, dvs. der hvor NixOS-vejen faktisk viste sig hurtigere/mere robust.
- De originale seks moduler egne sammenligningstabeller (reproducerbarhed, rollback, atomare
  generationer, `flake.lock`).

**Ulemper, ærligt og konkret underbygget:**
- Patch-hastighed, med et faktisk efterprøvet eksempel (`04-cve-patch-latency.md`), ikke kun en
  antagelse.
- Steder hvor A/B-sammenligningen (`DONE/08-debian-ab-sammenligning.md`) reelt viste Debian-vejen som
  lige så hurtig eller nemmere, vær ærlig om dem, det styrker troværdigheden af resten.
- Bemandings-/videns-risiko: færre sysadmins kender NixOS, hvilket er en reel driftsmæssig risiko
  ved overdragelse, oncall og rekruttering, ikke kun en indlæringskurve for én person. (Ingen
  separat plan, skrives direkte i syntesen.)
- Et ekstra fejlfindingslag: flere af projektets egne fund (sudoers-scoping, lockout-assertion i
  modul 3, DNS/ufw-sagaen) krævede forståelse af BÅDE almindelig Linux-fejlfinding OG Nix' eget lag
  (derivations, generationer, evaluering). Ærlig omkostning, selvom egen erfaring viser gevinsten
  (rollback, reproducerbarhed) typisk opvejede den. (Ingen separat plan.)

**Konklusion:** Skal være en reel, nuanceret stillingtagen, ikke en konfliktfri "det kommer an på
behovet"-udvanding. Overvej at formulere det som: for hvilken type organisation/scenarie er NixOS
det bedre valg, og for hvilken er den traditionelle tilgang stadig at foretrække, baseret på den
indsamlede evidens.

## Rækkefølge

Skrives SIDST, efter planerne `01`, `03`, `04`, `08`, `09` og `10` er gennemført eller i det mindste
undersøgt, siden dette afsnit er syntesen af dem, ikke en uafhængig opgave.

## Estimeret indsats

Middel til høj, dette er skrivearbejde der kræver at veje og formulere en reel konklusion, ikke
bare liste punkter op.
