# Modul 4: Firewall og netværkssikkerhed

*Se [`00-tilgang.md`](00-tilgang.md) for den overordnede begrundelse for valg af NixOS.*

## Formål

At reducere serverens angrebsflade til et minimum ved kun at tillade den netværkstrafik, der er
strengt nødvendig for systemets funktion.

## Sikkerhedsmæssig relevans

Firewall-konfiguration er en direkte anvendelse af "default deny"-princippet. En veldokumenteret
firewall-konfiguration er ofte det første, en sikkerhedsrevisor eller pentester kigger på ved en
systemgennemgang — og som dette modul viste i praksis, er det også let at *tro* man har en korrekt
konfiguration, uden faktisk at have testet den mod en reel, ikke-godkendt kilde.

## Design

- **Default deny**: `networking.firewall.enable = true;` — al indgående trafik blokeres, medmindre
  eksplicit tilladt.
- **SSH flyttet til port 2222** (ikke standardport 22) — jf. opgavens eget forslag.
- **SSH begrænset til én kilde-IP**: `192.168.122.1`, som er værtens egen adresse på libvirts
  NAT-bro (`virbr0`). Ingen anden maskine på samme undernet kan nå SSH, selv hvis en sådan
  tilføjes senere.

  *Ift. opgavetekstens ordlyd* ("begræns til et defineret IP-interval, hvis scenariet tillader
  det"): et enkelt `/32`-værtsinterval er stadig et defineret, eksplicit interval — blot af
  størrelse 1. Vi vurderer at scenariet ikke blot *tillader* denne afgrænsning, men aktivt
  foreskriver den: VM'en administreres udelukkende fra denne ene værtsmaskine, så et bredere
  interval (fx hele `192.168.122.0/24`) ville tillade kilder, der aldrig reelt skal have adgang —
  hvilket ville være i strid med selve "default deny, kun det nødvendige"-princippet, opgaven
  bygger på.
- **Ingen andre porte åbnes.** Der er *bevidst* ikke opsat en demo-webservice, selvom opgaven
  nævner det som en mulighed ("evt. en simpel webservice"). At tilføje en tjeneste udelukkende for
  at have flere linjer i portbegrundelsestabellen ville introducere unødvendig angrebsflade — det
  modarbejder selve formålet med modulet. Et enkelt, velbegrundet punkt er en stærkere
  demonstration af "minimal angrebsflade" end et opdigtet eksempel.

**Ærlig begrænsning:** At flytte SSH væk fra port 22 er *security through obscurity* — det
forhindrer intet i sig selv, det reducerer udelukkende støj fra automatiserede,
opportunistiske scanninger. De reelle beskyttelser er nøglebaseret autentifikation, ingen
root-login (modul 1), og kilde-IP-begrænsningen ovenfor. Vi fremhæver denne sondring eksplicit for
ikke at oversælge en svag kontrol som en stærk en.

## Portbegrundelsestabel

| Port | Protokol | Tjeneste | Begrundelse | Risiko |
|---|---|---|---|---|
| 2222 | TCP | SSH (flyttet fra 22) | Eneste administrative adgangsvej til serveren | Fjernkodeudførelse ved kompromitteret nøgle eller sårbarhed i sshd — afbødet af nøglebaseret auth, ingen root-login, og kilde-IP-begrænsning |

## Tre reelle fejl fundet ved at teste, ikke kun konfigurere

Denne sektion er usædvanligt lang for et NixOS-modul, fordi arbejdet her direkte demonstrerede en
central pointe: **en firewall-konfiguration, der ser rigtig ud, er ikke det samme som en, der
virker.** Alle tre fejl blev fundet ved faktisk at forsøge at omgå reglerne — ikke ved at læse
konfigurationen og antage den var korrekt.

### Fejl 1: `services.openssh.openFirewall` åbnede porten for alle alligevel

Første forsøg satte `networking.firewall.allowedTCPPorts = [ ];` og en kilde-begrænset
`extraInputRules`-regel. En test fra en sekundær IP-adresse (`192.168.122.99`, tilføjet midlertidigt
på `virbr0`) burde være blevet afvist — men blev accepteret:

```
$ ssh -i ~/.ssh/linux101_ed25519 -p 2222 -b 192.168.122.99 admin@192.168.122.10 'hostname'
linux101-srv
```

Årsagen: `services.openssh.openFirewall` er **sand som standard** og tilføjer automatisk sin port
til `networking.firewall.allowedTCPPorts`. Da denne indstilling er en *liste*-type, **merges**
bidrag fra alle moduler — vores eksplicitte `allowedTCPPorts = [ ]` andetsteds overskriver ikke
dette bidrag, den lægges blot oveni. Løsning: `services.openssh.openFirewall = false;`.

### Fejl 2: `extraInputRules` havde slet ingen effekt (forkert backend)

Efter rettelse af fejl 1 var *ingen* forbindelser mulige — end ikke fra den godkendte kilde-IP.
Undersøgelse af NixOS' kildekode (`nixos/modules/services/networking/firewall-nftables.nix`) viste,
at `networking.firewall.extraInputRules` kun har effekt, når
`networking.firewall.backend == "nftables"` — og standardværdien er den ældre,
iptables-baserede backend. Vores regel blev altså *stiltiende ignoreret* under hele det første
forsøg; den eneste grund til at *noget* virkede dengang var `openssh`'s automatisk åbnede,
kilde-ubegrænsede port (fejl 1). Løsning: `networking.firewall.backend = "nftables";`.

### Fejl 3: Kolliderende assertion fra `networking.nat`

Med `backend = "nftables"` satte, fejlede selve bygningen med:

```
Failed assertions:
- extraCommands is incompatible with the nftables based firewall: ...
  ip46tables -w -t nat -D PREROUTING -j nixos-nat-pre ...
```

`networking.nat`'s iptables-implementering indsætter **ubetinget** en oprydningskommando i
`networking.firewall.extraCommands` — uafhængigt af om NAT overhovedet er aktiveret — medmindre
`networking.nftables.enable = true` er sat. Løsning: tilføjet denne indstilling. Vi bruger ikke
`networking.nat` til noget (NAT håndteres af værtens libvirt, ikke af gæsten), så dette er en ren
sideeffekt-rettelse.

**Efter alle tre rettelser**, verificeret med den samme metode (sekundær kilde-IP):

```
$ ssh -i ~/.ssh/linux101_ed25519 -p 2222 admin@192.168.122.10 'hostname'      # fra 192.168.122.1
linux101-srv

$ ssh -i ~/.ssh/linux101_ed25519 -p 22 admin@192.168.122.10 'hostname'       # gammel port
ssh: connect to host 192.168.122.10 port 22: Connection timed out

$ ssh -i ~/.ssh/linux101_ed25519 -p 2222 -b 192.168.122.99 admin@192.168.122.10 'hostname'  # forkert kilde
ssh: connect to host 192.168.122.10 port 2222: Connection timed out
```

## Eksport af de aktive firewall-regler

Fuld output fra `sudo nft list ruleset`, kørt direkte på den kørende server (ikke uddrag fra
byggeartefaktet — dette er selve pointen med `nft list ruleset`-sudo-reglen fra forrige afsnit):

```
$ sudo nft list ruleset
table inet nixos-fw {
	set temp-ports {
		type inet_proto . inet_service
		flags interval
		comment "Temporarily opened ports"
	}

	chain rpfilter {
		type filter hook prerouting priority mangle + 10; policy drop;
		meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept comment "DHCPv4 client/server"
		fib saddr . mark check exists accept
		jump rpfilter-allow
	}

	chain rpfilter-allow {
	}

	chain input {
		type filter hook input priority filter; policy drop;
		iifname "lo" accept comment "trusted interfaces"
		icmpv6 type echo-reply accept
		ct state vmap { invalid : drop, established : accept, related : accept, new : jump input-allow, untracked : jump input-allow }
	}

	chain input-allow {
		meta l4proto . th dport @temp-ports accept
		icmp type echo-request accept comment "allow ping"
		icmpv6 type != { nd-redirect, 139 } accept comment "Accept all ICMPv6 messages except redirects and node information queries (type 139).  See RFC 4890, section 4.4."
		ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
		ip saddr 192.168.122.1 tcp dport 2222 accept
	}
}
```

Politikken er `drop` (default deny) for både `rpfilter`- og `input`-kæden. Kun trafik fra loopback,
etablerede/relaterede forbindelser, ICMP (ping og standard IPv6-vedligeholdelse), DHCP-klienttrafik,
og SSH fra præcis `192.168.122.1` accepteres eksplicit — alt andet rammer default-deny-politikken.

## En sidefordel: `nft list ruleset` som ny, begrundet sudo-regel

For at kunne dokumentere ovenstående uden fuld root-adgang tilføjede vi
`/run/current-system/sw/bin/nft list ruleset` til `admin`s granulære sudo-regler (modul 3) — endnu
et eksempel på, at nye regler tilføjes, når et konkret, dokumenteret behov opstår, ikke på forhånd.

## Addendum (opdaget under modul 5): uløst DNS-begrænsning, og hvordan vi håndterede den

Da modul 5 introducerede nye pakker (`cron`, `logrotate`), forsøgte vi at deploye ændringen med
vores etablerede lokale `sudo nixos-rebuild switch`-metode — og opdagede, at VM'en ikke kan slå DNS
op (`cache.nixos.org` kunne ikke resolves), selvom ICMP og vores eksplicitte TCP/SSH-regel begge
virker fint. Vi undersøgte tre hypoteser i rækkefølge:

1. `udp sport 53 accept` tilføjet til `extraInputRules` — ingen effekt.
2. `networking.firewall.checkReversePath = "loose"` (løsere reverse-path-filtering, en kendt
   NixOS-indstilling for netop NAT'ede/virtualiserede netværk) — heller ingen effekt; den genererede
   `rpfilter`-kæde ændrede sig ikke synligt.
3. Direkte test mod en helt ekstern resolver (`8.8.8.8`) gav samme fejl som mod libvirts egen
   `dnsmasq` — udelukker at problemet er specifikt for libvirts DNS-forwarder.

**Konklusion på daværende tidspunkt:** Vi kunne ikke inden for modul 5's rammer identificere den
præcise årsag til, at UDP request/reply (men ikke ICMP eller TCP) ikke fik svar retur til gæsten.
Fremfor at bruge uforholdsmæssigt meget tid på at fejlsøge en lavniveau netværksmekanisme, der lå
uden for det daværende moduls pensum, accepterede vi det som en driftsmæssig begrænsning. Den blev
senere, under modul 6-arbejdet, faktisk identificeret og løst, se addendummet nedenfor.

**Praktisk konsekvens for vores eget deploy-workflow, mens begrænsningen stod ved magt:** Når en
konfigurationsændring krævede nye pakker (som modul 5 gjorde), byggede og hentede vi disse på
**værten** (som har fungerende internetadgang) via `nix build .#qcow`, og hele diskimaget blev
genskabt og genimporteret i libvirt, det etablerede "slet og genskab fra flake"-mønster fra modul 1.
Dette mønster er stadig det mest robuste for større ændringer, uafhængigt af DNS-fixet nedenfor.

## Addendum 2 (opdaget under modul 6): den faktiske årsag til DNS/egress-begrænsningen

Under modul 6-arbejdet installerede vi `tealdeer` (en `tldr`-klient) direkte i `configuration.nix`
som et scenarie til at øve incremental pakke-tilføjelse. Det tvang os til for alvor at diagnosticere
DNS-begrænsningen fra addendummet ovenfor, i stedet for blot at bygge om på værten, og det afslørede
at den oprindelige konklusion ("uløst, accepteret begrænsning") var forhastet: årsagen lå slet ikke
i NixOS' gæste-side-konfiguration, som addendummet ovenfor bruger langt de fleste kræfter på.

**Nye observationer, som indsnævrede problemet:**

- `ping 8.8.8.8` fra gæsten virker (rå IP-routing/NAT til internettet fungerer).
- `dig github.com @192.168.122.1` virker fint, når kommandoen køres **fra værten selv**.
- Den samme forespørgsel fra **gæsten** til samme adresse (`192.168.122.1:53`) fik intet svar.

Det tredje punkt var nøglen: en forespørgsel fra værten til sin egen adresse (`192.168.122.1`)
løses internt via loopback i kernen og rammer aldrig værtens rigtige `INPUT`-filtrering. En
forespørgsel fra gæsten ankommer derimod reelt udefra, via `virbr0`, og rammer filtreringen for
alvor. De to test så ens ud, men afprøvede reelt to forskellige kodeveje i kernen.

**Rodårsag:** Værten kører `ufw` (traditionel, imperativ firewall-administration, i skarp kontrast
til NixOS' deklarative `firewall.nix` på gæsten). `ufw` er implementeret oven på `iptables-nft` og
opretter sine egne `INPUT`- og `FORWARD`-basiskæder i en helt separat nftables-tabel
(`table ip filter`) end libvirts egen `table ip libvirt_network`. Begge tabellers kæder er hooket på
samme punkt (`hook input`/`hook forward`, samme prioritet), og nftables evaluerer dem uafhængigt af
hinanden: et `accept` i libvirts tabel forhindrer IKKE et efterfølgende `drop` i `ufw`s tabel.

- `ufw`'s `INPUT`-kæde har `policy drop` og indeholdt ingen regel for port 53 på `virbr0`. Gæstens
  DNS-forespørgsler, adresseret direkte til værten (`192.168.122.1`), faldt igennem alle `ufw`s
  brugerdefinerede regler og ramte standardpolitikken: drop.
- `ufw`'s `FORWARD`-kæde har også `policy drop`, og tillod kun ICMP og allerede etablerede
  forbindelser, ikke nye TCP/UDP-forbindelser. Det forklarer hvorfor `ping` (ICMP) virkede, mens en
  frisk TCP-forbindelse (som `tldr --update`s HTTPS-download) blev afvist, selvom libvirts egen
  `guest_output`-kæde tillod præcis den samme trafik.

**Fix (to `ufw`-regler, på værten, ikke i NixOS-konfigurationen):**

```bash
sudo ufw allow in on virbr0 to any port 53 proto udp
sudo ufw allow in on virbr0 to any port 53 proto tcp
sudo ufw route allow in on virbr0
```

**Verificeret end-to-end** efter fixet: `getent hosts github.com` resolver korrekt fra gæsten, og
`tldr --update` gennemfører en fuld HTTPS-download og cache-opdatering uden fejl.

**Hvorfor stod dette ikke i NixOS-konfigurationen?** Fordi det ikke var en fejl der. Gæstens egen
firewall (`firewall.nix`, inklusiv `checkReversePath = "loose"` fra addendummet ovenfor) var korrekt
hele tiden. Fejlen lå i et helt separat filter-lag: værtens egen, imperativt administrerede `ufw`,
opbygget over tid via enkeltstående `ufw allow`-kommandoer uden et samlet overblik over det
virtuelle netværks-interface. Det er selve pointen med dette modul i praksis: en deklarativ,
ét-sted-defineret firewall er til at overskue i sin helhed; en traditionel, imperativt vedligeholdt
firewall (her: værtens `ufw`, ikke engang en del af selve forsøgsopstillingen) kan sagtens gemme på
en blind vinkel, selv når den ikke er det, man aktivt fejlsøger.

**Konsekvens:** Begrænsningen i addendummet ovenfor er nu rettet på netværksniveau. Det etablerede
"byg på værten, importér på ny"-mønster forbliver den mest robuste metode til større ændringer, men
en enkelt ny pakke kan nu også installeres med den oprindeligt tiltænkte lokale
`sudo nixos-rebuild switch --flake ~/linux101-config` direkte på gæsten, uden en fuld genopbygning.

## Arkitektur-revision: opgivelse af `--target-host`

Under arbejdet med dette modul stødte vi desuden på en alvorlig, uafhængig svaghed i vores
deploy-mekanisme fra modul 3 (den fjernstyrede `nixos-rebuild --target-host`), samt en
sudoers-escaping-fejl (`#`-tegnet i `--flake sti#attribut` bliver tolket som kommentar-markør i
sudoers). Begge er dokumenteret i detalje i [`00-tilgang.md`](00-tilgang.md), da de vedrører hele
projektets tekniske arkitektur, ikke kun dette modul.
