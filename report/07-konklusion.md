# Konklusion: Er NixOS fremtidens sikrere valg?

Opgaven foreslog Debian eller Ubuntu Server. Rapporten har i stedet brugt NixOS til at undersøge et
åbent spørgsmål: giver den deklarative tilgang reelle sikkerhedsmæssige fordele over den
traditionelle, imperative arbejdsgang, eller er forskellen kosmetisk? Svaret, baseret på seks
moduler og en reel A/B-sammenligning mod en faktisk Debian-VM, er hverken et ukvalificeret ja eller
et "det kommer an på behovet". Det er nedenfor forsøgt som en konkret stillingtagen, med evidensen
navngivet, ikke kun påstået.

## Fordele, med konkret evidens

**Konfigurationsdrift bliver synlig, i stedet for at kunne gemme sig.** `00-tilgang.md`s "Samlet
billede" viser at Debian-sidens seks moduler er spredt over mindst otte forskellige filer og
kommandotyper, hver redigerbar for sig, uden noget der repræsenterer hele systemets tilstand som én
genskabelig enhed. NixOS' `verify-deploy.sh` (modul 6) kan derfor stille et spørgsmål, Debian-siden
strukturelt ikke kan besvare: "stemmer det kørende system overens med det, der er erklæret?" Der
findes bevidst intet Debian-modstykke til det script, ikke fordi det ville være svært at skrive, men
fordi der ikke findes nogen deklareret facitliste at holde en traditionel server op imod.

**Reproducerbarhed, faktisk efterprøvet med et diff, ikke kun antaget.** `nix build --rebuild`
tvinger en ægte genbygning og sammenligner selv output-hashen (`00-tilgang.md`). Konklusionen er
bevidst afgrænset: den gælder den deklarerede systemtilstand, ikke det færdige diskimage som
artefakt (`mkfs.ext4`s tilfældige UUID gør det artefakt ikke-deterministisk). Den afgrænsning gør
selve påstanden mere troværdig, ikke mindre, fordi dens grænser er kendte og testede.

**Sudo-reglers sikre migration, demonstreret live.** Modul 3 viste at `security.sudo.extraRules` kan
udvides additivt (en ny regel tilføjes ved siden af den gamle, den gamle fjernes først når den nye
er bekræftet), så en sti i den ene, hvidlistede sudo-kommando kunne ændres uden at `admin` på noget
tidspunkt manglede en gyldig kommando at falde tilbage på. Den tilsvarende operation på Debian, en
direkte `visudo`-redigering, har ingen sådan mellemtilstand.

**Idempotens er en egenskab af værktøjet, ikke noget man selv skal bevise.** Debians
`provision.sh` (modul 6) forsøger idempotens ved at indbygge et tjek i hver enkelt funktion, og
fejlede reelt én gang undervejs (`visudo -c` manglede efter senere sudoers-tilføjelser).
`nixos-rebuild switch` er idempotent for hele systemtilstanden, uden at nogen skal huske at skrive
det tjek ind.

**Den direkte A/B-sammenligning viser en reel, målt forskel i friktion.** En fuld, manuel
genskabelse af modul 1-6 på den faktiske Debian-VM tog cirka 280 sekunders ren udførelsestid og
afslørede undervejs fem uventede fund, tre manglende pakker på en minimal installation (`sudo`,
`acl`, `cron`), én klassisk Unix-gruppekollision (`useradd -G` vs. `-g`), og én der direkte rettede
en unøjagtig påstand i selve rapporten (`/var/log/auth.log` findes ikke uden `rsyslog`). NixOS-siden
udtrykker den samme sluttilstand som én, allerede skrevet `nixos-rebuild switch`, uden
pakkeopdagelse undervejs, fordi hele afhængighedstræet allerede er en del af den deklarerede
konfiguration.

**Samme effektive sikkerhedspolitik, markant mindre genereret kompleksitet.** Modul 4 viser at
`ufw`s genererede nftables-ruleset er 386 linjer over 69 chains, mod NixOS' 33 linjer over 4 chains,
for præcis samme `drop`-standardpolitik og samme ene tilladte kilde. Årsagen er arkitektonisk, ikke
et sikkerhedsproblem: `ufw` er reelt en iptables-regelgenerator, oversat gennem `iptables-nft` til
nftables, og bærer 15+ års iptables-designarv med sig (adskilte IPv4/IPv6-skabeloner, fast
kæde-staging), mens NixOS' `nftables`-modul er skrevet direkte til nftables uden den bagage. Mindre
genereret regelværk at holde styr på, hvis noget nogensinde skal fejlsøges direkte i output'et.

## Ulemper, ærligt underbygget

**Et ekstra fejlfindingslag, ikke et erstattende.** Flere af projektets egne fund krævede forståelse
af både almindelig Linux-fejlfinding og Nix' eget evalueringslag: modul 3's sudo-regel, der *så*
korrekt ud i `sudo -l` men fejlede ved et faktisk deploy, fordi den forsøgte at forudsige
`nixos-rebuild`s interne kommandoindpakning; det uventede `#`-tegn i en flake-reference, der stille
afkorter en sudoers-linje; og modul 4's `openFirewall`-standardværdi, der lægger sig oveni en
eksplicit regel i stedet for at blive overskrevet, plus en separat `rpfilter`-kæde, der blokerede
DNS-svar uden om selve input-kæden. Ingen af disse var synlige ved at læse konfigurationen alene,
alle krævede faktisk at teste og fejlsøge live. Den deklarative tilgang fjerner ikke fejl, den
flytter dem.

**NixOS vinder ikke alle steder, og bør ikke antages at gøre det.** Modul 2 er det tydeligste
modeksempel: ACL-baseret adgangsstyring (`setfacl`/`getfacl`) er byte for byte identisk på begge
platforme, fordi NixOS bevidst ikke gør datafil-rettigheder deklarative. Debian-sidens `provision.sh`
var i øvrigt ikke systematisk sværere at skrive end at bruge NixOS, blot ramt af andre typer fejl
(manglende pakker, en Unix-gruppekollision) end Nix-sidens (evalueringsfejl, modul-sammenlægning).

**Det stive, bogstavelige sudo-eksakt-match har en reel omkostning, ikke kun en teoretisk.** Modul 3
viste at `admin` på den hærdede NixOS-VM ikke har noget nødspor, hvis en kommando afviger bare en
smule fra den præcise, hvidlistede streng, hverken en adgangskode eller en root-fallback. Debian,
med samme neutraliserede `wheel`/`sudo`-gruppe-mekanisme, beholder stadig `root`-konsoladgang som
et reelt, brugbart nødspor. Sikkerheden ved at fjerne det nødspor er reel, men den er ikke gratis.

**Bemandings- og videnrisiko.** Dette punkt er ikke testet empirisk i dette projekt, det kan det
ikke være med én person og to VM'er, men det er en reel driftsmæssig faktor, ikke kun en
indlæringskurve for én udvikler: markant færre sysadmins kender Nix' sprog og mentale model end
kender `apt`/`systemctl`/`sudoers`, hvilket er en reel risiko ved overdragelse, oncall-vagter og
rekruttering til en driftsorganisation, uafhængigt af hvor tekniske fordele NixOS i øvrigt har.

## Samlet vurdering

Evidensen samlet peger ikke på at NixOS er universelt bedre, men på at dens fordele er reelle og
mest værd, når prisen for konfigurationsdrift er høj, og dens ulemper er reelle og mest tunge, når
organisationens bindende begrænsning er tilgængelig viden, ikke teknisk kapacitet.

**NixOS er det stærkere valg for:** en organisation, hvor det at kunne bevise, hvad der reelt kører,
og hvorfor, vejer tungere end at kunne rekruttere bredt til driften, typisk compliance-tunge eller
sikkerhedskritiske miljøer, hvor `verify-deploy.sh`s spørgsmål ("stemmer det kørende system overens
med det erklærede?") reelt stilles jævnligt, og hvor et team allerede har eller kan investere i
Nix-kompetence som en varig del af driftsorganisationen, ikke en engangsindsats.

**Den traditionelle tilgang er stadig at foretrække for:** en organisation, hvor bemanding og
tilgængelig viden er den bindende begrænsning, hvor arbejdet i praksis domineres af opgaver, der er
reelt værktøjs-identiske uanset platform (modul 2 er beviset på at dette forekommer, ikke kun en
teoretisk mulighed), eller hvor et team ikke kan absorbere det ekstra Nix-evalueringslag oven i
almindelig Linux-drift uden at det går ud over leveringshastighed på kort sigt.

Den ærligste, enkeltstående konklusion er derfor: NixOS' sikkerhedsmæssige fordele er ikke en myte,
tre af dem (drift-synlighed, efterprøvet reproducerbarhed, og en dokumenteret, sikker vej gennem en
ellers stiv sudo-model) er direkte demonstreret i dette projekt, ikke kun påstået. Men de fordele
købes med et reelt, ikke-teoretisk ekstra fejlfindingslag og en bemandingsrisiko, som en
sikkerhedsvurdering, der kun ser på arkitektur, let overser.
