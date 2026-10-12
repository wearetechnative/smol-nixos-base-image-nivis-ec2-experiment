{ config, lib, ... }:
let
  cfg = config.smol.slimCurl;
in
{
  options.smol.slimCurl.enable = lib.mkEnableOption ''
    building `curl` without GSSAPI and without internationalised domain
    names.

    `curl` is kept: `fetch-ec2-metadata.service` uses it to read the
    instance metadata, which is contract check 1. Two libraries come with
    it that nothing here needs:

    | package | why curl links it | MiB |
    | ------- | ----------------- | --- |
    | `krb5-1.22.2-lib` | `gssSupport`, for SPNEGO and Negotiate auth | 2.80 |
    | `libunistring-1.4.2` | through `libidn2`, for IDN hostnames | 1.99 |

    The metadata service talks to `169.254.169.254` over plain HTTP with no
    authentication, and the verification contract's HTTPS check uses a
    static curl the harness pushes rather than this one.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: this curl cannot do Kerberos or Negotiate authentication,
    and it cannot resolve a hostname with non-ASCII characters. Both would
    matter to a general-purpose machine and neither has a caller here.
    Requires: nothing.
    Source: found by lab, exp #57, backlog item `e23`
  '';

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        curl = prev.curl.override {
          gssSupport = false;
          idnSupport = false;
        };
      })
    ];

    system.forbiddenDependenciesRegexes = [
      "-krb5-"
      "-libunistring-"
    ];
  };
}
