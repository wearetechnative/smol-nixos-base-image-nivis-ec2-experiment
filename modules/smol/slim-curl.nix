{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.smol.slimCurl;
in
{
  options.smol.slimCurl.enable = lib.mkEnableOption ''
    building curl without GSSAPI, at every place in the image that
    references it.

    curl is kept: `fetch-ec2-metadata.service` uses it to read the instance
    metadata, which is contract check 1. `krb5-1.22.2-lib`, 2.80 MiB of
    Kerberos, comes with it for SPNEGO and Negotiate authentication. The
    metadata service talks to `169.254.169.254` over plain HTTP with no
    authentication at all.

    Three places reference curl, and all three have to move together or the
    stock build stays and krb5 with it:

    | referrer | how it is reached |
    | -------- | ----------------- |
    | `fetch-ec2-metadata.service` | `smol.noUserDataDecompression.curl` |
    | `systemd-261.3` | `systemd-imdsd` and `systemd-report` link libcurl through `libsystemd-shared`, whatever `withRemote` and `withImportd` say |
    | `amazon-ec2-utils-2.2.0` | its NVMe helper scripts call curl |

    This is three `override` calls and not a `nixpkgs.overlays` entry on
    curl itself. An overlay rebuilds everything that takes curl as a build
    input, and LLVM links libcurl for debuginfod, so it rebuilds clang,
    mesa and QEMU behind it. Experiment 57 ran for three hours that way.
    See `GOTCHAS.md`.

    `libidn2` and `libunistring` stay whatever curl does: glibc references
    libidn2 for IDN in `getaddrinfo`, so `idnSupport` is left alone here.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: no Kerberos or Negotiate authentication from curl, from
    `systemd-imdsd`, or from the EC2 NVMe scripts. Nothing here
    authenticates to a KDC.
    Requires: `smol.noUserDataDecompression`, which owns the unit's path.
    Source: found by lab, exp #58, backlog item `e23`
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.smol.noUserDataDecompression.enable;
        message = ''
          smol.slimCurl replaces curl on fetch-ec2-metadata.service's path,
          and smol.noUserDataDecompression is what sets that path. Without
          it the unit keeps the stock path and this module saves nothing
          while appearing to work.
        '';
      }
    ];

    smol.noUserDataDecompression.curl = pkgs.curl.override { gssSupport = false; };

    # `curl` itself is deliberately not overlaid: the two consumers are, and
    # `final.curl` inside the overlay is still the stock attribute, so
    # `final.curl.override` here and `pkgs.curl.override` above evaluate to
    # the same derivation and the lab builds one curl rather than a world.
    nixpkgs.overlays = [
      (final: prev: {
        systemd = prev.systemd.override {
          curl = final.curl.override { gssSupport = false; };
        };
        amazon-ec2-utils = prev.amazon-ec2-utils.override {
          curl = final.curl.override { gssSupport = false; };
        };
      })
    ];

    system.forbiddenDependenciesRegexes = [ "-krb5-" ];
  };
}
