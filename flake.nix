{
  description = "Shirube — a left-edge light field interface for Wayland";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          appData = pkgs.stdenv.mkDerivation {
            pname = "shirube-data";
            version = "0.1.0";
            src = ./.;
            buildPhase = ''
              runHook preBuild
              $CC -O2 -pipe -std=c11 -Wall -Wextra -Wpedantic \
                helpers/shirube-audio-rms.c -o shirube-audio-rms -lm
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              install -d $out/share/shirube/helpers $out/share/shirube/matugen/templates \
                $out/share/doc/shirube
              install -m644 *.qml config.json $out/share/shirube/
              install -m755 shirube-audio-rms $out/share/shirube/helpers/
              install -m644 matugen/templates/shirube-colors.json \
                $out/share/shirube/matugen/templates/
              install -m644 matugen/config.example.toml $out/share/shirube/matugen/
              install -m644 README.md README.en.md CHANGELOG.md LICENSE $out/share/doc/shirube/
              runHook postInstall
            '';
          };
          launcher = pkgs.writeShellApplication {
            name = "shirube";
            runtimeInputs = with pkgs; [
              coreutils
              gawk
              gnused
              networkmanager
              pipewire
              quickshell
              wireplumber
            ];
            text = builtins.replaceStrings [ "@INSTALL_ROOT@" ] [ "${appData}/share/shirube" ] (
              builtins.readFile ./scripts/shirube.in
            );
          };
        in
        pkgs.symlinkJoin {
          name = "shirube-0.1.0";
          paths = [
            appData
            launcher
          ];
          meta = {
            description = "Left-edge light field interface for Niri and Hyprland";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "shirube";
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
        shirube = packageFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/shirube";
          meta.description = "Run the Shirube light-field interface";
        };
      });

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          package = self.packages.${system}.default;
          source =
            pkgs.runCommand "shirube-source-check"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.shellcheck
                ];
              }
              ''
                cd ${self}
                shellcheck install.sh uninstall.sh scripts/shirube.in helpers/build.sh
                jq empty config.json matugen-colors.example.json \
                  matugen/templates/shirube-colors.json
                touch $out
              '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      homeManagerModules.default = import ./nix/home-manager.nix { inherit self; };
      nixosModules.default = import ./nix/nixos-module.nix { inherit self; };
    };
}
