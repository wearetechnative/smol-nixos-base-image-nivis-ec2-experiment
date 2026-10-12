{ config, lib, ... }:
let
  cfg = config.smol.noX11;
in
{
  options.smol.noX11.enable = lib.mkEnableOption ''
    removing the X11 and font support a headless appliance carries by
    default. Three unrelated defaults put it there:

    | what | why it is there | MiB |
    | ---- | --------------- | --- |
    | `xauth-1.1.5` and the five `libX*` it needs | `security.pam.services.su.forwardXAuth`, set by `programs/shadow.nix`, which puts `pam_xauth.so` in `/etc/pam.d/su` | 6.46 |
    | `libx11` again | dbus built with `x11Support`, for the X11 autolaunch transport | shared with the row above |
    | `fontconfig-2.18.3` and its etc entry | `fonts.fontconfig.enable`, on by default | 1.16 |

    `pam_xauth` copies the caller's X cookie when switching user. There is
    no X server here, no DISPLAY and no graphical session; `su` is reached
    only over SSH, and X11 forwarding is off in sshd. dbus autolaunch needs
    an X display to attach the session bus to and so cannot fire either.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: `su` stops forwarding X cookies, and no program can find a
    font through fontconfig. Both matter the moment this image grows a
    display, and nothing in the contract touches either.
    Requires: nothing.
    Source: found by lab, exp #55, from `FLOOR.md`'s referrer table
  '';

  config = lib.mkIf cfg.enable {
    security.pam.services.su.forwardXAuth = lib.mkForce false;

    fonts.fontconfig.enable = false;

    nixpkgs.overlays = [
      (final: prev: {
        dbus = prev.dbus.override { x11Support = false; };
      })
    ];

    system.forbiddenDependenciesRegexes = [
      "-xauth-"
      "-libx11-"
      "-fontconfig-"
    ];
  };
}
