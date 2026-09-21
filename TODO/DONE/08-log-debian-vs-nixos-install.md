# Log: Debian-installation vs. NixOS-installation, forskelle og fejlsøgning

Løbende notat til `08-debian-ab-sammenligning.md`. Ikke rapport-materiale endnu, kun rå
observationer og research, mens vi får en fair Debian-opsætning til at virke.

## Strukturel forskel, allerede tydelig, uafhængigt af om installationen lykkes

NixOS-siden har **intet installationstrin overhovedet**, adskilt fra selve konfigurationen:

```
nix build .#qcow            # bygger et FÆRDIGT, fuldt konfigureret image i én kommando
virt-install --import ...   # importerer det færdige image, ingen installer kører
```

Debian kræver, uanset hvilken metode man vælger, mindst to adskilte faser: (1) få en bootbar
base-OS på disken (installer, eller et importeret image), (2) konfigurér den derefter. Der findes
intet Debian-værktøj, der producerer et "færdigt, hærdet system" i ét trin, før første opstart, uden
enten at bruge et tredjepartsværktøj (`virt-builder`, `packer`) eller at forudkonfigurere ting, der
reelt hører til modul 1-6's tællende arbejde.

## Forkastet: `virt-builder`/cloud-init til at forudkonfigurere brugere/SSH

Overvejet og forkastet igen: begge ville bage en admin-bruger og SSH-nøgle ind i imaget *før* boot,
hvilket reelt ville udføre en del af modul 1's opgave ("opret en ikke-root administratorbruger",
"kun nøglebaseret SSH") som et engangs-byggetrin, ikke som talt, manuelt arbejde. Det ville
kunstigt gøre Debian-sidens modul 1 lettere end den reelt er, og dermed skævvride sammenligningen.
Den fair tilgang: en helt almindelig installation, der kun efterlader en root-konto med
adgangskode (præcis den tilstand en frisk Debian-installation normalt giver), og så udføre alle seks
moduler i hånden derfra.

## Forsøg 1 (preseed + netinst-ISO): boot-loop, under fejlsøgning

**Kommando (forkortet):**
```
virt-install --location debian-13.7.0-amd64-netinst.iso --initrd-inject=preseed.cfg \
  --extra-args "auto=true priority=critical console=ttyS0" \
  --disk path=...,size=8,format=qcow2 \
  --graphics none --console pty,target_type=serial --os-variant generic
```

**Observation:** Efter installationen (partitionering, pakkeinstallation, `grub-installer` ser ud
til at være gennemført, GRUB finder en "Debian GNU/Linux"-boot-post) gentager konsollen
`Booting 'Debian GNU/Linux'` hurtigt i træk, uden nogensinde at komme videre. Dette blev kun
observeret via korte (15-30 sekunders) tilkoblinger til den serielle konsol, ikke ét sammenhængende,
langt log, så selve hændelsesforløbet (når GRUB overdrager til kernen, hvad kernen evt. selv
printer) er endnu ikke set direkte.

**Bekræftet, isoleret faktor:** `virt-install` uden eksplicit disk-bus vælger `bus="ide"` for
`--os-variant generic` (verificeret med `--print-xml`, ingen VM oprettet). NixOS-siden (og mit andet
forsøg) bruger eksplicit `bus="virtio"`. Ikke nødvendigvis roden til loopet (IDE er velunderstøttet
og bør ikke i sig selv forhindre boot), men en reel inkonsekvens, der bør rettes for at holde
sammenligningen på lige fod, og for at eliminere én variabel før videre fejlsøgning.

**Mest sandsynlige hypoteser til boot-loopet, ikke endeligt bekræftet:**

1. `console=ttyS0` blev kun sat på selve installer-kernens kommandolinje (`--extra-args`), ikke
   videreført til det FÆRDIGE, installerede systems GRUB/kerne-opsætning via preseed. Manglende
   direktiv: `d-i debian-installer/add-kernel-opts string console=ttyS0,115200n8`.
2. En reel crash/genstarts-løkke (kernen fejler at montere rod-filsystemet, eller panicker straks
   efter GRUB, og libvirts standard `on_crash=restart` genstarter hele VM'en, hvilket ville se
   præcis sådan ud: samme GRUB-skærm, gentaget hurtigt).
3. En fejl i selve den genererede `grub.cfg` (fx en sti-fejl fra partman/grub-installer-samspillet),
   der får GRUB til at fejle boot-kommandoen og falde tilbage til menuen med `GRUB_TIMEOUT=0`,
   hvilket ville skabe en løkke udelukkende inde i GRUB, uden at kernen nogensinde involveres.

## Den faktiske rodårsag (fundet, bekræftet, rettet)

Efter flere blindgyder (STP-forsinkelse, QEMU virtio-net-regression, NIC-model, disk-bus, en ren
netværksgenstart, alle testet og alle udelukket), pegede en direkte erindring om DNS-sagen i
`docs/04`s Addendum 2 på den rigtige forklaring: **værtens `ufw` blokerede det, hele tiden.**

`sudo nft list ruleset` viste at `ufw-user-input` kun havde regler for UDP/TCP port 53 (DNS, tilføjet
under den tidligere sag), ingen regel for UDP port 67 (DHCP-serverporten). Enhver DHCPDISCOVER fra en
gæst på `virbr0` blev derfor stille droppet af `ufw`s default-deny `INPUT`-politik, før den nogensinde
nåede `dnsmasq`. Det forklarer hvorfor hverken NIC-model, disk-bus eller en netværksgenstart gjorde
nogen forskel: ingen af de ændringer rører `ufw` overhovedet. Nøjagtig samme arkitektoniske blinde
vinkel som DNS-sagen, blot en anden port.

**Fix (identisk mønster som DNS-fixet):**
```bash
sudo ufw allow in on virbr0 to any port 67 proto udp
```

**Verificeret direkte** på den allerede installerede Debian-VM, uden at geninstallere: `dhcpcd -t 15
-1 ens2` fik øjeblikkeligt et tilbud og en lease (`192.168.122.85`, 3600 sekunder), hvor det før
fejlede i det uendelige. VM'en blev derefter genstartet for at rydde test-leasen og vende tilbage til
den rene, statiske konfiguration fra selve installationen.

**Denne fejlfindingssaga er selv værdifuldt materiale til `03-case-study-dns-ufw.md`**: det er ikke
kun ét tilfælde af den traditionelle, imperativt opbyggede firewalls blinde vinkel, det er det
*samme* mønster, der rammer igen, på en anden protokol, i samme session, dagen efter DNS-sagen blev
løst. At samme blinde vinkel nåede at ramme igen så hurtigt er et stærkere argument end en
enkeltstående hændelse.

**Sidegevinst, Forsøg 1's boot-loop er nu indirekte forklaret:** Forsøg 1 (før konsol-videreførsel
blev tilføjet til preseed'en) endte i det uforklarede GRUB-loop beskrevet ovenfor. Den endelige,
vellykkede installation brugte samme `d-i debian-installer/add-kernel-opts string
console=ttyS0,115200n8`-rettelse (hypotese 1) og bootede rent, ingen loop, via en normal GRUB-menu
og videre til login. Det er ikke et vandtæt bevis (flere ting ændrede sig samtidig), men det
understøtter hypotese 1 som den sandsynlige forklaring på det oprindelige loop, adskilt fra den
senere `ufw`-relaterede DHCP-fejl.

## Den endelige, fungerende base-installation

Da selve DHCP-vejen var ustabil under fejlfindingen (før `ufw`-fixet blev fundet), blev
base-installationen gennemført med en **statisk IP i selve preseed'en** (`192.168.122.50`) i stedet
for DHCP, som en omgåelse der ikke går ud over sammenligningens fairness: modul 1 kræver alligevel en
statisk IP som en manuel opgave. VM'en kører nu, boot-testet, på præcis NixOS-VM'ens
`bus=virtio`/`model=virtio`/`--import`-lignende slutkonfiguration (selvom selve installationen brugte
`--location`, ikke `--import`, det gør ingen forskel for det færdige, kørende system).

Root-adgang: seriel konsol (`virsh console debian-comparison`), bruger `root`, adgangskode
`comparison-temp-pw`. SSH virker endnu ikke (Debians standard tillader ikke root-login med
adgangskode over SSH), det er præcis den tilstand modul 1's opgaver adresserer.
