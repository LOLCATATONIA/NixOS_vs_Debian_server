# Modul 5: System monitoring og logging
# Se docs/05-overvaagning-og-logging.md for begrundelse og evidens.
{ ... }:
{
  # cron er valgt direkte, uden NixOS-oversættelse — i modsætning til fx modul 3's
  # sudoers.d eller modul 4's ufw, er der ingen strukturel konflikt mellem NixOS og
  # traditionel cron: NixOS understøtter cron som en almindelig, førsteklasses service.
  services.cron.enable = true;
  services.cron.systemCronJobs = [
    "*/5 * * * * root /etc/scripts/monitor.sh"
  ];

  environment.etc."scripts/monitor.sh" = {
    source = ../../scripts/monitor.sh;
    mode = "0755";
  };

  # Logrotation for overvågningsscriptets logfil. journald roterer allerede sin egen
  # journal automatisk (SystemMaxUse m.fl.) — men det dækker ikke en almindelig flad
  # fil, vores eget script selv skriver til, som derfor har brug for sin egen
  # logrotate-regel for ikke at vokse ukontrolleret.
  services.logrotate.enable = true;
  services.logrotate.settings."/var/log/monitor.log" = {
    frequency = "daily";
    rotate = 7;
    compress = true;
    missingok = true;
    notifempty = true;
  };
}
