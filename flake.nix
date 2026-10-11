{
  description = "smol NixOS base image for AWS EC2, deployed through nivis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nivis = {
      url = "github:nivis-project/nivis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nivis,
    }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      pkgsFor = system: nixpkgs.legacyPackages.${system};

      # The target architectures an image can be built for. EC2 x86_64 is the
      # primary track; aarch64 (Graviton) is a separate track per BRIEFING §3.
      imageSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Never pass a prebuilt `pkgs` here: smol strategies install overlays from
      # inside `config`, which only works when the module system instantiates
      # nixpkgs itself. See BRIEFING §5 and GOTCHAS.md.
      mkSystem =
        {
          system,
          modules,
        }:
        lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = system; }
            self.nixosModules.smol
          ]
          ++ modules;
          specialArgs = { inherit nivis; };
        };

      # system -> { "<name>" = <config>; } for every tracked system variant.
      variants = {
        baseline = ./systems/baseline;
        candidate = ./systems/candidate;
        accepted = ./systems/accepted;
      };

      nixosConfigurationsFor =
        system:
        lib.mapAttrs' (
          name: path:
          lib.nameValuePair "${name}-${system}" (mkSystem {
            inherit system;
            modules = [ path ];
          })
        ) variants;
    in
    {
      nixosModules.smol = ./modules/smol;

      # Gate 2. `nivis` evaluates this attribute by default; lab/deploy-ec2.sh
      # drives it with --var. Evaluating it never touches AWS.
      nivis.plan = import ./lab/nivis-plan.nix {
        nivis = nivis.lib;
        inherit (self) nixosConfigurations;
      };

      # `<variant>-<system>` for every combination, plus unsuffixed aliases on
      # the primary x86_64 EC2 target.
      nixosConfigurations =
        lib.foldl' (acc: system: acc // nixosConfigurationsFor system) { } imageSystems
        // lib.mapAttrs (
          name: path:
          mkSystem {
            system = "x86_64-linux";
            modules = [ path ];
          }
        ) variants;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        lib.optionalAttrs (lib.elem system imageSystems) (
          lib.mapAttrs (
            name: _: self.nixosConfigurations."${name}-${system}".config.system.build.toplevel
          ) variants
          // {
            default = self.nixosConfigurations."accepted-${system}".config.system.build.toplevel;
          }
          // lib.mapAttrs' (
            name: _:
            lib.nameValuePair "image-${name}"
              self.nixosConfigurations."${name}-${system}".config.system.build.images.amazon
          ) variants
        )
        // {
          # Pushed to the target before verifying, so the image itself never
          # has to ship an HTTPS client. Both gates use this one.
          static-curl = pkgs.pkgsStatic.curl;

          options-doc = import ./docs/options-doc.nix {
            inherit pkgs lib;
            smolModule = self.nixosModules.smol;
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        lib.optionalAttrs (lib.elem system imageSystems) {
          # Gate 1: boot the candidate in QEMU and run the §3 verification
          # contract over SSH.
          verify-candidate = import ./lab/test-local.nix {
            inherit pkgs lib;
            name = "candidate";
            systemModules = [
              self.nixosModules.smol
              ./systems/candidate
            ];
          };
          verify-accepted = import ./lab/test-local.nix {
            inherit pkgs lib;
            name = "accepted";
            systemModules = [
              self.nixosModules.smol
              ./systems/accepted
            ];
          };
        }
        // {
          shellcheck = pkgs.runCommand "shellcheck-lab" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            # -x follows `. aws-env.sh`, which the scripts share; -P tells
            # shellcheck where the sourced file lives.
            shellcheck -x -P ${./lab} ${./lab}/*.sh
            touch $out
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.just
              pkgs.python3
              pkgs.jq
              pkgs.awscli2
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.nixfmt
              pkgs.qemu_kvm
              pkgs.openssh
              pkgs.coreutils
              nivis.packages.${system}.nivis
            ];
            shellHook = ''
              echo "smol lab, run 'just' for the recipe list"
            '';
          };
        }
      );

      # nixfmt over the repo's own .nix files, nothing else. Passing a
      # directory to nixfmt is deprecated and the tree wrappers pull in more
      # than this repo needs.
      formatter = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.writeShellApplication {
          name = "smol-fmt";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.findutils
          ];
          text = ''
            find "''${1:-.}" -name '*.nix' -not -path '*/.git/*' -not -path '*/.jj/*' \
              -print0 | xargs -0 -r nixfmt
          '';
        }
      );
    };
}
