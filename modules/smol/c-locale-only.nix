{ config, lib, ... }:
let
  cfg = config.smol.cLocaleOnly;
in
{
  options.smol.cLocaleOnly.enable = lib.mkEnableOption ''
    building the locale archive with `C.UTF-8` alone.

    `glibc-locales-2.44-25` is 2.93 MiB and every unit on the machine
    references it, because NixOS puts `LOCALE_ARCHIVE` in systemd's
    manager environment. The archive is built from
    `i18n.supportedLocales`, which defaults to `C.UTF-8` plus the default
    locale, and the default locale is `en_US.UTF-8`.

    Nothing here reads a message catalogue. The appliance has no
    documentation (#10), no interactive tools beyond a shell, and
    `lab/verify.sh` compares bytes rather than translated strings.
    `C.UTF-8` is what the contract's `LANG` already is in practice, and it
    sorts and compares the way a script expects.

    Measured saving (appliance track, EC2): 2.46 MiB closure, ledger #73.
    The image read 6.00 MiB *larger*, which is the VHD's rounding and not
    a regression: see `GOTCHAS.md`, "The image is its contents".
    Trade-offs: a login shell gets `C.UTF-8`, so program messages are
    English and collation is byte order rather than locale-aware. Anything
    that formats numbers or dates for a human in another language is
    wrong on this image, and nothing on it does.
    Requires: nothing.
    Source: siraben, backlog item `s7`
  '';

  config = lib.mkIf cfg.enable {
    i18n.defaultLocale = lib.mkForce "C.UTF-8";
    i18n.supportedLocales = lib.mkForce [ "C.UTF-8/UTF-8" ];
  };
}
