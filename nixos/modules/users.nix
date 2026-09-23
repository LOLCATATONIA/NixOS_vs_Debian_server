# Modul 1: ikke-root administratorbruger, nøglebaseret SSH.
# Modul 3: fuld rollestruktur (admin/developer/guest) og granulære sudo-regler.
#
# users.mutableUsers = false betyder at brugere/adgangskoder udelukkende styres
# gennem denne fil — der er ingen "usermod"/"passwd" der kan foretages på den
# kørende server uden at det bliver overskrevet ved næste nixos-rebuild switch.
{ ... }:
{
  users.mutableUsers = false;

  # "developer"-rollens skriveadgang til /srv/projekt kommer fra medlemskab af den
  # "projekt"-gruppe, der allerede blev oprettet i modul 2 (nixos/modules/filesystem.nix)
  # — der oprettes bevidst ikke en ny, overlappende gruppe med samme rettigheder.
  # "guest"-rollen får sin egen gruppe, som gives læse-only adgang via en ACL-entry
  # på /srv/projekt (se docs/03-brugere-og-grupper.md), i stedet for gruppe-rettigheder,
  # så den grundlæggende ejer/gruppe-model for mappen (fra modul 2) forbliver uændret.
  users.groups.guest = {};

  users.users.admin = {
    isNormalUser = true;
    # NixOS' egen sikkerhedstjek kræver, at mindst én wheel-bruger har en adgangskode
    # eller SSH-nøgle (for at undgå at man låser sig selv ude). Medlemskabet alene
    # giver IKKE bred sudo-adgang: security.sudo.wheelNeedsPassword forbliver på sin
    # standardværdi (true), og admin har ingen adgangskode — så almindelig
    # wheel-baseret sudo er reelt uopnåeligt. Den eneste faktiske adgang admin har,
    # kommer fra de eksplicitte NOPASSWD-regler i security.sudo.extraRules nedenfor.
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHupSaXzaaZhiibHIOcnZSQFpdKunrKH02flhEA42bMc admin@nixos-comparison"
    ];
  };

  users.users.developer = {
    isNormalUser = true;
    extraGroups = [ "projekt" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDTL0tYEtwJO7F+5EqFGff+scV5BlrpYuANIeKIOiMF9 developer@nixos-comparison"
    ];
  };

  users.users.guest = {
    isNormalUser = true;
    extraGroups = [ "guest" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIISipJZzxE6vbgn+yy/Rhdpv4TINo56LGNLNGVDUVpxO guest@nixos-comparison"
    ];
  };

  # root har ingen gyldig adgangskode overhovedet — udover at PermitRootLogin=no i
  # sshd_config, er det derved heller ikke muligt at logge ind som root med
  # adgangskode via konsollen (forsvar i dybden).
  users.users.root.hashedPassword = "!";

  # Granulær sudo (modul 3, opgave 3): admin er nominelt i "wheel" (se begrundelse
  # ovenfor), men det giver ingen ubegrænset sudo-adgang i praksis. I stedet gives
  # NOPASSWD-adgang til udelukkende de kommandoer, der reelt er nødvendige lige nu:
  #  - nixos-rebuild: se ARKITEKTUR-REVISION nedenfor.
  #  - systemctl restart sshd: et enkelt, snævert afgrænset driftseksempel — ikke
  #    generel systemctl-adgang.
  #  - chmod g+s /srv/projekt: opdaget som et konkret behov under selve modul 3-arbejdet
  #    (ikke givet på forhånd). Kernen nægter en ikke-privilegeret proces at sætte
  #    setgid-biten på en mappe, den ikke selv er medlem af gruppen for (her: admin er
  #    ejer af /srv/projekt, men ikke medlem af "projekt"-gruppen) — chmod(2) afviser
  #    det stille, uden fejl. Det ramte os i praksis: `setfacl` (kørt som admin, ikke
  #    root) synkroniserer ACL-masken via samme mekanisme og nulstillede derved
  #    setgid-biten som en bivirkning. Løsningen er denne præcise, snævre kommando —
  #    ikke generel chmod-adgang.
  # Yderligere regler tilføjes først når et konkret behov opstår, i stedet for at
  # blive givet på forhånd.
  #
  # ARKITEKTUR-REVISION (modul 4): De oprindelige to regler herfra (en wildcard-regel
  # for switch-to-configuration, samt en for nixos-rebuild-ng's interne, indpakkede
  # nix-env-kald) var forsøg på at give adgang til de PRÆCISE underliggende kommandoer,
  # som `nixos-rebuild switch --target-host` bruger internt til fjern-aktivering. Det
  # holdt ikke: nix-env-kaldets nøjagtige indpakning (en argv-værdi med indlejrede
  # mellemrum og anførselstegn) matchede sudoers' kommando-sammenligning ustabilt og
  # fejlede ved næste reelle deploy, uden at vi kunne se det på forhånd — kun
  # `sudo -l` så korrekt ud, men et ægte deploy-forsøg beviste at reglen reelt ikke
  # virkede. I stedet gives sudo-adgang til selve VÆRKTØJET, kørt LOKALT på VM'en med
  # én fast, fuldt kvalificeret kommando — en langt mere robust grænseflade end at
  # forsøge at forudsige et eksternt værktøjs interne implementeringsdetaljer.
  #
  # BEMÆRK: `#`-tegnet er sudoers' kommentar-markør. `--flake sti#attribut`-syntaksen
  # (som ellers er helt normal for Nix) ville derfor stille afkorte HELE resten af
  # linjen i den genererede sudoers-fil — inklusive alle efterfølgende kommandoer i
  # denne liste. Opdaget ved at tjekke `sudo -l` grundigt efter deployment, ikke kun
  # ved at antage reglen var korrekt. Løsningen er at udelade `#attribut` helt:
  # nixos-rebuild vælger automatisk den nixosConfiguration, hvis navn matcher
  # maskinens hostname (her: "nixos-comparison") — verificeret direkte før denne regel
  # blev sat.
  security.sudo.extraRules = [
    {
      users = [ "admin" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch --flake /home/admin/linux101-config";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart sshd.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/chmod g+s /srv/projekt";
          options = [ "NOPASSWD" ];
        }
        {
          # Modul 4: admin skal kunne se firewall-status uden fuld root — nødvendigt
          # for at kunne opfylde modul 4's dokumentationskrav (og senere modul 6's
          # healthcheck.sh) uden at åbne generel netværks-administrationsadgang.
          command = "/run/current-system/sw/bin/nft list ruleset";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
