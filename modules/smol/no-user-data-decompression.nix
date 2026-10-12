{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.smol.noUserDataDecompression;

  fetcher = pkgs.runCommand "ec2-metadata-fetcher-no-decompress.sh" { } ''
    substitute ${pkgs.path}/nixos/modules/virtualisation/ec2-metadata-fetcher.sh $out \
      --replace-fail \
        ' && try_decompress "$metaDir/user-data"' \
        ""
  '';
in
{
  options.smol.noUserDataDecompression.enable = lib.mkEnableOption ''
    dropping user-data decompression from `fetch-ec2-metadata.service`.

    That service is what makes contract check 1 pass: it fetches the SSH key
    from instance metadata. It also fetches user-data and, if it is
    compressed, decompresses it, which is why its PATH carries `file`,
    `bzip2`, `gzip`, `lzip`, `xz` and `zstd`. `file-5.48` alone is 10.54 MiB
    of libmagic.

    Nothing consumes user-data on this image. `smol.noAmazonInit` removed the
    service that did, in experiment 4, so the fetched file has had no reader
    for forty-five experiments.

    The call is patched out of the upstream script rather than the tools
    being quietly removed from the PATH, so a user-data payload cannot
    produce a half-working fetcher later.

    `path` is set with `mkForce`, which also discards the default service
    path `nixos/lib/systemd-lib.nix` contributes with `mkAfter`, so that
    list is restated here. Experiment 50's first attempt forced the path to
    `curl` alone; gate 1 passed and the instance failed to boot on
    `mkdir: command not found`.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: user-data is still fetched to `/etc/ec2-metadata/user-data`
    and is left exactly as delivered. Anything added later that reads it has
    to handle its own decompression.
    Requires: nothing, but it only makes sense with `smol.noAmazonInit`,
    which is what made user-data unread in the first place.
    Source: found by lab, exp #50, after `smol.noEditor` removed only one of
    `file`'s two holders
  '';

  options.smol.noUserDataDecompression.curl = lib.mkOption {
    type = lib.types.package;
    default = pkgs.curl;
    defaultText = lib.literalExpression "pkgs.curl";
    description = ''
      The curl that goes on `fetch-ec2-metadata.service`'s path.

      It is an option because this module is the only place in the image
      that references curl, so it is the only place a different build of it
      can be installed. `smol.slimCurl` sets it to a curl without GSSAPI
      and without IDN. Both modules forcing the path instead would merge
      their two lists rather than conflict, and the unit would carry both
      curls.
    '';
  };

  config = lib.mkIf cfg.enable {
    systemd.services.fetch-ec2-metadata = {
      path = lib.mkForce [
        cfg.curl
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        config.systemd.package
      ];
      script = lib.mkForce (builtins.readFile fetcher);
    };

    system.forbiddenDependenciesRegexes = [ "-file-[0-9]" ];
  };
}
