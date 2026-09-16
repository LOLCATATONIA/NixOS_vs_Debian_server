# Modul 1: VM-opsætning og netværk
#
# Statisk IP og hostname, samt SSH hærdet til udelukkende nøglebaseret login med
# root-login deaktiveret. Se docs/01-vm-og-netvaerk.md for sikkerhedsbegrundelse.
{ ... }:
{
  networking.hostName = "linux101-srv";

  # Deterministisk interfacenavn (eth0) i stedet for PCI-baseret predictable naming
  # (fx enp1s0/ens3) — VM'en har kun ét NIC, så der er ingen tvetydighed at undgå,
  # og det gør konfigurationen uafhængig af hvordan QEMU/libvirt enumererer PCI-bussen.
  networking.usePredictableInterfaceNames = false;

  networking.useDHCP = false;
  networking.interfaces.eth0.ipv4.addresses = [{
    address = "192.168.122.10";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.122.1";
  networking.nameservers = [ "192.168.122.1" ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
