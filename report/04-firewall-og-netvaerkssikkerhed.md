# Modul 4: Firewall og netværkssikkerhed

## Formål

At reducere serverens angrebsflade til et minimum ved kun at tillade den netværkstrafik, der er
strengt nødvendig for systemets funktion.

## Sikkerhedsmæssig relevans

Firewall-konfiguration er en direkte anvendelse af "default deny"-princippet. En veldokumenteret
firewall-konfiguration er ofte det første, en sikkerhedsrevisor eller pentester kigger på ved en
systemgennemgang.

## Sammenligning: traditionel tilgang vs. NixOS

Samme tre opgaver (default-deny, kun nødvendige porte åbne, kilde-IP-begrænsning), side om side:

::: {.compare}
::: {.compare-side}
#### Traditionel: fire `ufw`-kommandoer

```bash
# tillad kun SSH fra værtens egen adresse
$ sudo ufw allow from 192.168.122.1 to any port 2222 proto tcp
# blokér alt andet indgående som udgangspunkt
$ sudo ufw default deny incoming
$ sudo ufw default allow outgoing
$ sudo ufw enable
```

(Bevidst **ingen** separat `ufw allow 2222/tcp`, den ville tillade porten fra *alle* kilder og
dermed underminere kilde-IP-reglen ovenfor, samme faldgrube som NixOS-sidens `openFirewall`,
beskrevet i noten nedenfor. Kommandorækkefølgen her er den faktisk testede.)
:::
::: {.compare-side}
#### NixOS: én deklareret blok

```nix
# nixos/modules/firewall.nix
networking.firewall.enable = true;
networking.firewall.backend = "nftables";
services.openssh.ports = [ 2222 ];
services.openssh.openFirewall = false;  # se note nedenfor
networking.firewall.extraInputRules = ''
  ip saddr 192.168.122.1 tcp dport 2222 accept
'';
```
:::
:::

**Note:** `services.openssh.openFirewall` er sand som standard og åbner porten for *alle* kilder,
uafhængigt af `extraInputRules`. Årsagen er at `allowedTCPPorts` er en liste-type: bidrag fra
forskellige moduler lægges sammen i stedet for at overskrive hinanden. `openFirewall = false;` er
derfor nødvendig, for at kilde-IP-begrænsningen reelt får effekt.

## Design

- **Default deny**: al indgående trafik blokeres, medmindre eksplicit tilladt.
- **SSH flyttet til port 2222** (ikke standardport 22): reducerer støj fra automatiserede
  scanninger, men er *ikke* i sig selv en sikkerhedskontrol. De reelle beskyttelser er nøglebaseret
  auth, ingen root-login, og kilde-IP-begrænsningen.
- **SSH begrænset til `192.168.122.1`**: værtens egen adresse på libvirts NAT-bro. Et enkelt
  `/32`-interval er stadig et defineret interval, blot af størrelse 1. Da VM'en udelukkende
  administreres fra denne ene maskine, ville et bredere interval tillade kilder, der aldrig reelt
  skal have adgang.
- **Ingen andre porte åbnes:** der er bevidst ikke opsat en demo-webservice udelukkende for at
  udfylde portbegrundelsestabellen.

## Portbegrundelsestabel

| Port | Protokol | Tjeneste | Begrundelse | Risiko |
|---|---|---|---|---|
| 2222 | TCP | SSH (flyttet fra 22) | Eneste administrative adgangsvej til serveren | Fjernkodeudførelse ved kompromitteret nøgle. Afbødes af nøglebaseret auth, ingen root-login og kilde-IP-begrænsning |

## Eksport af de aktive firewall-regler

```
$ sudo nft list ruleset
table inet nixos-fw {
	chain rpfilter {
		type filter hook prerouting priority mangle + 10; policy drop;
		meta nfproto ipv4 udp sport . udp dport { 67 . 68, 68 . 67 } accept comment "DHCPv4 client/server"
		fib saddr . mark check exists accept
		jump rpfilter-allow
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
		icmpv6 type != { nd-redirect, 139 } accept
		ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
		ip saddr 192.168.122.1 tcp dport 2222 accept
		udp sport 53 accept
	}
}
```

Politikken er `drop` (default deny). Kun loopback, etablerede/relaterede forbindelser, ICMP, DHCP,
og SSH fra præcis `192.168.122.1` accepteres eksplicit.

**Verifikation** (forsøgt fra en ikke-godkendt kilde-IP på samme undernet):

```
# -b: bind forbindelsen til en anden lokal adresse, for at simulere en uautoriseret kilde
$ ssh -p 2222 -b 192.168.122.99 admin@192.168.122.10 'hostname'
ssh: connect to host 192.168.122.10 port 2222: Connection timed out

$ ssh -p 2222 admin@192.168.122.10 'hostname'   # fra 192.168.122.1 (tilladt)
nixos-comparison
```

## Delkonklusion

Begge platforme lander på samme sikre slutresultat: default deny, kun SSH åbent, og kun fra
værtens egen adresse. Modul 4 er dog det sted i projektet, hvor NixOS' egne abstraktioner skabte
mest reel fejlsøgning: `services.openssh.openFirewall`s standardværdi lægger sig oveni en eksplicit
kilde-IP-regel i stedet for at blive overskrevet af den (fordi porte-lister merges på tværs af
moduler), og en separat, streng `rpfilter`-kæde (reverse-path-filtrering, en anti-spoofing-kontrol
der afviser trafik, hvis svarruten ikke matcher den forventede) blokerede DNS-svar helt uden om
selve input-kæden, længe efter den tilsyneladende rigtige regel var sat. Ingen af de to fejl var synlige
ved at læse konfigurationen alene, begge krævede faktisk at teste adgangen fra en anden kilde-IP og
fejlsøge live. Oplevelsen modsiger dermed en for simpel fortælling om at "deklarativt er
gennemsigtigt": NixOS' lag af sammenlagte standardværdier kan skjule fejl lige så effektivt som
Debians spredte konfigurationsfiler, blot af en anden art.
