# Modul 4: Firewall og netværkssikkerhed
#
# Default-deny for al indgående trafik. Kun SSH åbnes, og kun fra værtens egen adresse
# på libvirts NAT-netværk — ikke fra hele undernettet. Se
# docs/04-firewall-og-netvaerkssikkerhed.md for fuld begrundelse og portbegrundelsestabel.
{ ... }:
{
  networking.firewall.enable = true; # eksplicit, selvom det er NixOS' standardværdi

  # KRITISK: NixOS' firewall bruger som standard en iptables-baseret backend, hvor
  # `extraInputRules` (nftables-syntaks) INGEN effekt har — noget vi først opdagede ved
  # faktisk at teste kilde-IP-begrænsningen (se docs/04-firewall-og-netvaerkssikkerhed.md).
  # Denne linje skifter eksplicit til den native nftables-backend, som er en forudsætning
  # for at `extraInputRules` nedenfor overhovedet bliver anvendt.
  networking.firewall.backend = "nftables";

  # Nødvendig følgevirkning af ovenstående: networking.nat's iptables-modul indsætter
  # ubetinget en oprydnings-kommando i networking.firewall.extraCommands, medmindre
  # networking.nftables.enable er sat — hvilket direkte kolliderer med
  # nftables-backendens egen assertion om, at extraCommands skal være tom. Vi bruger
  # ikke networking.nat til noget (NAT håndteres af værtens libvirt, ikke af gæsten),
  # så dette er en ren aktivering af den korrekte, konsistente nftables-vej.
  networking.nftables.enable = true;

  # SSH flyttes væk fra standardporten 22. Dette er IKKE en reel sikkerhedsforanstaltning
  # i sig selv (security through obscurity) — det reducerer udelukkende støj fra
  # automatiserede, opportunistiske scanninger mod port 22. De reelle beskyttelser
  # (nøglebaseret auth, ingen root-login, kilde-IP-begrænsning nedenfor) er uændrede.
  services.openssh.ports = [ 2222 ];

  # KRITISK: services.openssh's egen "openFirewall"-indstilling er som DEFAULT sand og
  # tilføjer automatisk sin(e) port(e) til networking.firewall.allowedTCPPorts. Da
  # allowedTCPPorts er en LISTE-type, MERGES bidrag fra alle moduler — en eksplicit
  # `allowedTCPPorts = [ ]` andetsteds i konfigurationen overskriver IKKE dette bidrag,
  # den lægges blot oveni. Dette opdagede vi først ved faktisk at teste adgang fra en
  # ikke-godkendt kilde-IP (se docs/04-firewall-og-netvaerkssikkerhed.md) — uden
  # `openFirewall = false` her ville port 2222 reelt være åben for alle, uanset
  # kilde-IP-reglen nedenfor.
  services.openssh.openFirewall = false;

  # SSH åbnes bevidst IKKE via networking.firewall.allowedTCPPorts, da det ville tillade
  # adgang fra enhver kilde. I stedet en rå nftables-regel, der kun tillader trafik fra
  # 192.168.122.1 — det er libvirts NAT-gateway-adresse, som i praksis ER værtsmaskinens
  # egen adresse på virbr0. Enhver anden maskine, der måtte blive tilføjet til dette
  # virtuelle netværk senere, vil IKKE kunne nå SSH, selvom den er på samme undernet.
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.122.1 tcp dport 2222 accept
    udp sport 53 accept
  '';

  # Opdaget under modul 5: DNS-opslag fra gæsten fik aldrig svar (selv fra 8.8.8.8
  # direkte), selvom ICMP og TCP/SSH virkede fint — og selv efter at have tilføjet
  # `udp sport 53 accept` ovenfor. Årsagen lå slet ikke i input/input-allow-kæderne:
  # NixOS' firewall opsætter en separat "rpfilter"-kæde (streng reverse-path-filtering,
  # RFC 3704) hooket ved prerouting med sin egen "policy drop" — pakker afvist her når
  # de allerede FØR de når input-kæden. Streng rpfilter er en velkendt kilde til
  # problemer i NAT'ede/virtualiserede netværk (som libvirts NAT-bro), fordi
  # returtrafik ikke altid matcher den forventede rute lige så entydigt som på et
  # fysisk netværk. Løsningen er NixOS' dedikerede indstilling for netop dette:
  networking.firewall.checkReversePath = "loose";
  # "loose" (svarer til Linux' rp_filter=2) kræver blot at en rute til kilde-adressen
  # findes via ET ELLER ANDET interface, ikke nødvendigvis det pakken ankom på — stadig
  # en reel anti-spoofing-kontrol, blot ikke så streng at den fejler i denne topologi.
  # `udp sport 53 accept`-reglen ovenfor beholdes som ekstra, eksplicit dokumentation
  # af hensigten (tillad DNS-svar), selvom den isoleret set ikke var nok til at løse
  # problemet — den egentlige årsag var rpfilter, ikke input-allow-kæden.

  # Ingen andre porte åbnes. Der er bevidst IKKE opsat en demo-webservice blot for at
  # have flere linjer i portbegrundelsestabellen — det ville være at introducere
  # unødvendig angrebsflade for dokumentationens skyld, hvilket modarbejder selve
  # formålet med modulet.
  networking.firewall.allowedTCPPorts = [ ];
}
