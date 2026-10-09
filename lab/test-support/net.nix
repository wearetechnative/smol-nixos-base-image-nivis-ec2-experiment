# A gateway node for gate 1, so the local gate can prove the things a bare
# NixOS test network cannot: name resolution through a real resolver, an
# HTTPS request validated against a CA, and NTP synchronisation.
#
# Without this the three network checks of the contract could only be skipped
# locally, and a strategy that breaks resolved, dhcpcd or the CA bundle would
# get all the way to gate 2 before anyone noticed.
{ pkgs, lib }:
let
  domain = "smol-gate.test";

  ca = pkgs.runCommand "smol-test-ca" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p $out
    openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
      -subj "/CN=${domain}" \
      -addext "subjectAltName=DNS:${domain}" \
      -keyout $out/key.pem -out $out/cert.pem
  '';
in
{
  inherit domain ca;

  url = "https://${domain}/nix-cache-info";

  gateway =
    { config, ... }:
    {
      # Authoritative for the test domain only, so the target has to do real
      # resolution instead of reading the driver's /etc/hosts.
      services.dnsmasq = {
        enable = true;
        settings = {
          address = "/${domain}/${config.networking.primaryIPAddress}";
          bind-interfaces = true;
          listen-address = [
            "127.0.0.1"
            config.networking.primaryIPAddress
          ];
        };
      };

      services.nginx = {
        enable = true;
        virtualHosts.${domain} = {
          addSSL = true;
          sslCertificate = "${ca}/cert.pem";
          sslCertificateKey = "${ca}/key.pem";
          locations."/nix-cache-info".return = ''200 "StoreDir: /nix/store\n"'';
        };
      };

      services.chrony = {
        enable = true;
        extraConfig = ''
          allow all
          local stratum 10
        '';
      };

      networking.firewall.allowedTCPPorts = [
        53
        443
      ];
      networking.firewall.allowedUDPPorts = [
        53
        123
      ];
    };

  # Applied to the target node: point it at the gateway for DNS and time, and
  # trust the test CA. Nothing here papers over a broken client stack; if a
  # strategy removes the resolver, the CA machinery or the time client, these
  # checks fail exactly as they would on EC2.
  targetNetwork =
    { nodes, ... }:
    let
      gw = nodes.gateway.networking.primaryIPAddress;
    in
    {
      networking.nameservers = lib.mkForce [ gw ];
      networking.timeServers = lib.mkForce [ gw ];
      security.pki.certificateFiles = [ "${ca}/cert.pem" ];
    };
}
