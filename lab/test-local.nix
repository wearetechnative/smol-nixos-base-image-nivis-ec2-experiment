# Gate 1 (BRIEFING §8.3): boot a system variant under the NixOS test driver
# and run the §3 verification contract against it over SSH from a second node.
#
# The contract is executed by `lab/verify.sh`, the same script gate 2 runs on
# EC2, so the two gates can never drift apart.
{
  pkgs,
  lib,
  name,
  systemModules,
}:
let
  sshKeys = import (pkgs.path + "/nixos/tests/ssh-keys.nix") pkgs;
  net = import ./test-support/net.nix { inherit pkgs lib; };
  verifyScript = ./verify.sh;
  staticCurl = pkgs.pkgsStatic.curl;
in
pkgs.testers.runNixOSTest {
  name = "smol-verify-${name}";

  # The test driver otherwise hands each node a prebuilt `pkgs`, which makes
  # `nixpkgs.overlays` an error rather than a merge. Several smol strategies
  # install overlays from inside `config`, so gate 1 has to let the module
  # system instantiate nixpkgs per node, exactly as the flake does.
  node.pkgsReadOnly = false;

  # The flake hands this to every variant through `specialArgs`; the test
  # driver builds its nodes itself, so it has to hand over the same thing or
  # `modules/smol/wrappers-without-propagation.nix` looks for it in
  # `_module.args` and the evaluation recurses. Experiment 66.
  node.specialArgs.smolWrappersPatched = import ./wrappers-patch.nix pkgs;

  nodes = {
    target =
      { ... }:
      {
        imports = systemModules ++ [
          ./test-support/qemu.nix
          net.targetNetwork
        ];

        # amazon-image.nix pins an empty hostname; the test driver needs the
        # node name so the client can reach it.
        networking.hostName = lib.mkForce "target";

        # Stands in for the key EC2 injects from instance metadata. Gate 1
        # cannot prove the injection path; gate 2 does (verify.sh check 1).
        users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilEd25519PublicKey ];

        services.openssh = {
          enable = true;
          settings.PermitRootLogin = lib.mkForce "prohibit-password";
        };

        networking.firewall.allowedTCPPorts = [ 22 ];
      };

    client =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.openssh ];
      };

    gateway = net.gateway;
  };

  testScript = ''
    start_all()

    gateway.wait_for_unit("nginx.service")
    gateway.wait_for_unit("dnsmasq.service")
    gateway.wait_for_unit("chronyd.service")

    target.wait_for_unit("multi-user.target")
    target.wait_for_open_port(22)
    client.wait_for_unit("multi-user.target")

    client.succeed("mkdir -p ~/.ssh")
    client.succeed(
        "cat ${sshKeys.snakeOilEd25519PrivateKey} > ~/.ssh/id_ed25519"
    )
    client.succeed("chmod 600 ~/.ssh/id_ed25519")

    ssh = (
        "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-o ConnectTimeout=30 -i ~/.ssh/id_ed25519 root@target"
    )

    scp = (
        "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
        "-i ~/.ssh/id_ed25519"
    )

    def verify(label):
        # The image never ships curl; the harness pushes a static one, exactly
        # as lab/deploy-ec2.sh does for gate 2.
        client.succeed(
            f"{scp} ${staticCurl}/bin/curl root@target:/tmp/smol-curl"
        )
        out = client.succeed(
            f"{ssh} 'VERIFY_ENV=qemu VERIFY_TRACK=appliance "
            f"VERIFY_HTTPS_URL=${net.url} sh -s' < ${verifyScript}"
        )
        print(f"=== verify contract ({label}) ===")
        print(out)
        return out

    with subtest("key-based ssh login works"):
        client.succeed(f"{ssh} true")

    with subtest("verification contract passes on first boot"):
        verify("first boot")

    with subtest("the instance survives a reboot and passes again"):
        target.shutdown()
        target.start()
        target.wait_for_unit("multi-user.target")
        target.wait_for_open_port(22)
        verify("after reboot")
  '';
}
