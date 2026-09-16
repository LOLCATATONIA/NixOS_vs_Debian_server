# Modul 2: Filsystemet og adgangskontrol
#
# Delt projektmappe styret via gruppe-rettigheder (ikke chmod 777), samt en
# ekstra bruger til at demonstrere ACL-baseret, afgrænset adgang (opgave 4).
# Se docs/02-filsystem-og-adgangskontrol.md for sikkerhedsbegrundelse og evidens.
{ ... }:
{
  users.groups.projekt = {};

  # setgid (mode 2770): nye filer/mapper oprettet i /srv/projekt arver automatisk
  # gruppen "projekt", i stedet for skaberens primære gruppe. Uden setgid ville
  # medlemmer let komme til at oprette filer, som resten af gruppen ikke kan tilgå.
  systemd.tmpfiles.rules = [
    "d /srv/projekt 2770 admin projekt -"
  ];

  # Bruger til demonstration af ACL (modul 2, opgave 4): en "revisor" skal midlertidigt
  # kunne læse i /srv/projekt uden at blive medlem af projekt-gruppen. Ingen adgangskode
  # og intet shell-login nødvendigt — testet dengang (modul 2) via `sudo -u revisor` fra
  # admin. BEMÆRK: efter modul 3's granulære sudo kan admin ikke længere impersonere
  # andre brugere via `sudo -u` (kun de eksplicit whitelistede kommandoer virker), så
  # denne specifikke testmetode er ikke længere brugbar — se docs/03-brugere-og-grupper.md.
  users.users.revisor = {
    isNormalUser = true;
    hashedPassword = "!";
  };
}
