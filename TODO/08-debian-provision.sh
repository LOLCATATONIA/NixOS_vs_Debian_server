#!/usr/bin/env bash
# Modul 1-5 (Debian-siden af A/B-sammenligningen): traditionel, imperativ opsætning af
# admin/developer/guest, SSH-hærdning, den delte projektmappe med gruppe- og ACL-styring,
# firewall (modul 4), og overvågning/logrotation (modul 5).
#
# Dette script er skrevet EFTER at have udført og målt hvert trin manuelt (se
# TODO/08-resultater-modul1-6.md for de faktiske tider og fejl undervejs). Det fanger den
# rækkefølge, der reelt virkede, inklusiv rettelserne for de uventede fund undervejs
# (manglende `sudo`/`acl`/`ufw`/`cron`-pakker, `useradd -G`/`-g`-kollisionen, manglende
# `rsyslog` (se modul 5-rapporten)).
#
# Forudsætning: `monitor.sh` (fra scripts/) ligger i samme mappe som dette script.
#
# Køres som root PÅ SERVEREN (ikke via SSH med sudo, da admin bevidst er password-låst,
# ligesom på NixOS-siden, og derfor ikke kan sudo'e uden en forudgående NOPASSWD-regel).
#
# Idempotens: forsøgt, men ufuldstændigt, i modsætning til NixOS-siden. Hver funktion
# tjekker om dens eget mål allerede er opnået, men der er ingen samlet garanti for at hele
# scriptet kan køres igen uden bivirkninger (fx overskriver det SSH-nøgler ubetinget). Det er
# selv en sammenligningspointe: at gøre traditionelle scripts fuldt idempotente kræver
# eksplicit arbejde, det er ikke en egenskab man får gratis, sådan som `nixos-rebuild
# switch` giver det på NixOS-siden.
set -euo pipefail

readonly ADMIN_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBivhCT4qYudF8Tfadk32dKE7IgSU/y6y7pK2SmckCEw admin@debian-comparison"
readonly DEVELOPER_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKNmFmwIgBG9buyO2oVZcCe8HZ+9weaE/Ih6SZqdqERA developer@debian-comparison"
readonly GUEST_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJI+CAz9SnqURD0/Ld4gIUfJqeznrycLd9HHbs1nlCq guest@debian-comparison"

log() {
  echo "[provision] $*"
}

ensure_package() {
  local pkg="$1"
  if ! dpkg -s "$pkg" &>/dev/null; then
    log "Installerer manglende pakke: $pkg (ikke en del af en minimal Debian-installation)"
    apt-get install -y -qq "$pkg"
  fi
}

setup_admin() {
  if ! id admin &>/dev/null; then
    log "Opretter admin-bruger (modul 1)"
    useradd -m -s /bin/bash -G sudo admin
    passwd -l admin
  fi
  install -d -m 700 -o admin -g admin /home/admin/.ssh
  echo "$ADMIN_KEY" > /home/admin/.ssh/authorized_keys
  chmod 600 /home/admin/.ssh/authorized_keys
  chown admin:admin /home/admin/.ssh/authorized_keys
}

harden_ssh() {
  log "Deaktiverer root-login og password-auth (modul 1)"
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart sshd
}

setup_admin_sudo() {
  # Granulær sudo, bygget op i takt med det konkrete behov opstod under selve arbejdet,
  # i modsætning til NixOS-sidens fra-start-deklarerede security.sudo.extraRules.
  cat > /etc/sudoers.d/admin <<'EOF'
admin ALL=(ALL) NOPASSWD: /usr/bin/mkdir, /usr/bin/chown, /usr/bin/chmod, /usr/sbin/setfacl, /usr/bin/getfacl
admin ALL=(ALL) NOPASSWD: /usr/sbin/groupadd, /usr/sbin/usermod, /usr/sbin/useradd
admin ALL=(ALL:ALL) NOPASSWD: /usr/bin/setfacl, /usr/bin/getfacl, /usr/bin/ls, /usr/bin/touch
EOF
  chmod 440 /etc/sudoers.d/admin
  visudo -c
}

setup_shared_project_folder() {
  log "Opretter delt projektmappe med gruppe-rettigheder (modul 2)"
  mkdir -p /srv/projekt
  chown admin:projekt /srv/projekt
  chmod 2770 /srv/projekt
}

setup_developer_and_guest() {
  if ! getent group guest &>/dev/null; then
    groupadd guest
  fi
  if ! id developer &>/dev/null; then
    log "Opretter developer-bruger (modul 3), medlem af projekt-gruppen"
    useradd -m -s /bin/bash -G projekt developer
    passwd -l developer
  fi
  if ! id guest &>/dev/null; then
    # -g (primær gruppe), IKKE -G (sekundær): useradd forsøger ellers selv at oprette en
    # privat gruppe "guest", som allerede findes, og fejler.
    log "Opretter guest-bruger (modul 3), primær gruppe guest"
    useradd -m -s /bin/bash -g guest guest
    passwd -l guest
  fi
  for u in developer guest; do
    install -d -m 700 -o "$u" -g "$u" "/home/$u/.ssh"
  done
  echo "$DEVELOPER_KEY" > /home/developer/.ssh/authorized_keys
  echo "$GUEST_KEY" > /home/guest/.ssh/authorized_keys
  chmod 600 /home/developer/.ssh/authorized_keys /home/guest/.ssh/authorized_keys
  chown developer:developer /home/developer/.ssh/authorized_keys
  chown guest:guest /home/guest/.ssh/authorized_keys
}

setup_guest_acl() {
  log "Giver guest-gruppen læseadgang via ACL, ingen skriveadgang (modul 3)"
  setfacl -m g:guest:rx /srv/projekt
  if compgen -G "/srv/projekt/*" > /dev/null; then
    setfacl -m g:guest:r /srv/projekt/*
  fi
}

setup_firewall() {
  log "Konfigurerer ufw: default-deny, kun SSH på 2222 fra værten (modul 4)"
  sed -i 's/^#\?Port .*/Port 2222/' /etc/ssh/sshd_config
  grep -q '^Port' /etc/ssh/sshd_config || echo "Port 2222" >> /etc/ssh/sshd_config
  ufw allow from 192.168.122.1 to any port 2222 proto tcp
  ufw default deny incoming
  ufw default allow outgoing
  systemctl restart sshd
  ufw --force enable
}

setup_monitoring() {
  log "Sætter overvågningsscript op via cron og logrotate (modul 5)"
  mkdir -p /etc/scripts
  cp "$(dirname "${BASH_SOURCE[0]}")/monitor.sh" /etc/scripts/monitor.sh
  chmod +x /etc/scripts/monitor.sh
  if ! crontab -l 2>/dev/null | grep -qF '/etc/scripts/monitor.sh'; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * /etc/scripts/monitor.sh") | crontab -
  fi
  cat > /etc/logrotate.d/monitor <<'EOF'
/var/log/monitor.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
}

setup_sudo_documentation_rules() {
  # Tilføjet i takt med at modul 4/5's dokumentationskrav gjorde det nødvendigt, samme
  # granulære filosofi som modul 2/3's regler ovenfor.
  if ! grep -q "nft list ruleset" /etc/sudoers.d/admin 2>/dev/null; then
    echo "admin ALL=(ALL) NOPASSWD: /usr/sbin/nft list ruleset" >> /etc/sudoers.d/admin
  fi
  if ! grep -q "ufw status verbose" /etc/sudoers.d/admin 2>/dev/null; then
    echo "admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status verbose" >> /etc/sudoers.d/admin
  fi
  # visudo -c blev kun kørt efter den FØRSTE sudoers-skrivning i setup_admin_sudo, ikke
  # efter disse senere tilføjelser. Uden dette tjek her kunne en tastefejl i en append
  # ovenfor stille og roligt gøre hele /etc/sudoers.d/admin ugyldig, uden at scriptet
  # nogensinde ville opdage det.
  visudo -c
}

main() {
  apt-get update -qq
  ensure_package sudo
  ensure_package acl
  ensure_package ufw
  ensure_package cron
  setup_admin
  harden_ssh
  setup_admin_sudo
  setup_shared_project_folder
  setup_developer_and_guest
  setup_guest_acl
  setup_firewall
  setup_monitoring
  setup_sudo_documentation_rules
  log "Færdig. Modul 1-5 er nu opsat traditionelt/imperativt på denne server."
}

main "$@"
