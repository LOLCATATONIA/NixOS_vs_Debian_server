# Adgangsguide: linux101-srv

**Vigtigst at forstå:** Alle kommandoer i dette dokument køres på ét af to steder, aldrig blandet.
Hver kommando nedenfor er mærket `[vært]` eller `[vm]`.

**Den mest almindelige fejl er at køre en `[vært]`-kommando, mens man allerede er logget ind på
VM'en**, fx `ssh -i ~/.ssh/linux101_ed25519 -p 2222 admin@192.168.122.10` inde fra VM'en selv. Det
fejler altid med *"Identity file ... not accessible: No such file or directory"* efterfulgt af
*"Permission denied (publickey)"*, fordi den private nøgle bevidst kun findes på værten, aldrig på
gæsten (hvis VM'en nogensinde blev kompromitteret, skal en angriber ikke kunne bruge den til at
hoppe videre til værten). At SSH'e til VM'en fra VM'en selv vil ALDRIG virke, uanset hvad, fordi
nøglen slet ikke er der. Dette er ikke en fejl i opsætningen, det er et tegn på at kommandoen blev
kørt det forkerte sted.

**Sådan tjekker du hvor du er, uden at skulle læse prompten:** Kør denne ene kommando, uanset hvor
du er:

```bash
hostname
```

- Svarer den `cachyos-x8664`: du er på **værten**. `[vært]`-kommandoer kan køres direkte.
- Svarer den `linux101-srv`: du er på **VM'en**. Kør `exit` for at komme tilbage til værten, før
  du kører en `[vært]`-kommando.

**Hvis du er i tvivl om, hvor mange niveauer du er "inde", eller `exit` ikke ser ud til at virke:**
Spring det hele over, og åbn i stedet et helt nyt terminalvindue. Et nyt vindue starter altid på
værten, garanteret, uden at skulle regne ud hvor det forrige endte.

## SSH ind på serveren

**Ingen af brugerne har en adgangskode.** Det er ikke en mangel, det er bevidst (modul 1):
`admin`, `developer` og `guest` har slet ikke noget adgangskode-felt sat, og `root` er eksplicit
låst (`hashedPassword = "!"`). Den eneste gyldige legitimation er SSH-nøglerne nedenfor. Der er
derfor intet at slå op eller huske, kun hvilken nøglefil der hører til hvilken bruger.

**[vært]**

```bash
ssh -i ~/.ssh/linux101_ed25519 -p 2222 admin@192.168.122.10
```

- Nøgle: `~/.ssh/linux101_ed25519` (findes kun på værten)
- Port: `2222`, ikke standard-port 22 (se modul 4)
- Virker kun fra denne vært, firewallen accepterer udelukkende SSH fra `192.168.122.1`

Andre rollekonti, hvis der er brug for dem (samme mønster, andet nøglenavn):

```bash
ssh -i ~/.ssh/linux101_developer_ed25519 -p 2222 developer@192.168.122.10
ssh -i ~/.ssh/linux101_guest_ed25519 -p 2222 guest@192.168.122.10
```

## VM-status og livscyklus

**[vært]**

```bash
sudo virsh list --all           # se om VM'en kører
sudo virsh start linux101-srv   # start den, hvis den er slukket
sudo virsh shutdown linux101-srv  # ordentlig nedlukning
```

## Fejlfinding

**"Identity file ... not accessible" og/eller "Permission denied (publickey)" med det samme, ingen
prompt om password:** Kør `hostname` (se øverst i dette dokument). Svarer den `linux101-srv`, blev
kommandoen kørt inde fra VM'en i stedet for fra værten, den mest almindelige årsag til netop denne
fejl.

**"No route to host":** VM'en er sandsynligvis slukket (sker fx efter en genstart af værten).
Bekræft og start den:

```bash
# [vært]
sudo virsh list --all           # State: shut off?
sudo virsh start linux101-srv
```

VM'en er sat til autostart sammen med libvirt (`virsh autostart linux101-srv`), så dette burde
normalt ikke ske efter en genstart af værten fremover, men kan stadig forekomme hvis VM'en er
slukket manuelt.

**SSH hænger, eller kan slet ikke forbinde, men VM'en kører ifølge `virsh list`:**
`known_hosts`-indgangen kan være forældet (sker efter genopbygning af VM'en fra bunden):

```bash
# [vært]
ssh-keygen -R '[192.168.122.10]:2222'
```

**Prøv derefter at oprette forbindelse igen.** Den vil bede om at bekræfte værtens nøgle-fingeraftryk
igen (normalt, ikke en fejl).

## Når du er logget ind (`[vm]`)

- `sudo -l` viser præcis hvad `admin` må gøre som root, bevidst meget snævert (modul 3).
- Firewall-status: `sudo nft list ruleset`.
- Healthcheck: `~/linux101-config/scripts/healthcheck.sh`.
- Drift-tjek (stemmer den kørende konfiguration overens med det deklarerede?):
  `~/linux101-config/scripts/verify-deploy.sh`.

## Deploy en konfigurationsændring

Konfigurationskilden ligger i **repoet på værten**. Ændringer skal kopieres til VM'en og aktiveres
der, det er ikke automatisk.

**[vært]**, kopiér ændringerne over:

```bash
scp -i ~/.ssh/linux101_ed25519 -P 2222 -r flake.nix flake.lock nixos scripts \
  admin@192.168.122.10:~/linux101-config/
```

**[vm]**, aktivér dem (log ind først, se ovenfor):

```bash
sudo nixos-rebuild switch --flake ~/linux101-config
```

Dette er den eneste `nixos-rebuild`-kommando, `admin` har lov til at køre som root, jf. de
granulære sudo-regler fra modul 3.

## Hvis noget går grueligt galt: fuld genopbygning

**[vært]**, sletter og genskaber VM'en helt fra bunden ud fra `flake.nix`. Idempotent, kan køres
igen og igen:

```bash
./scripts/setup.sh
```

Bemærk: al imperativ tilstand, der ikke er en del af den deklarerede konfiguration (fx testfilerne i
`/srv/projekt` fra modul 2's demonstration), forsvinder ved en fuld genopbygning og skal genskabes
manuelt, hvis den ønskes igen.
