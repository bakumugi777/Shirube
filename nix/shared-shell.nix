{
  cfg,
  lib,
  pkgs,
}:

let
  shared = cfg.sharedShell;
in
{
  options = {
    enable = lib.mkEnableOption "a QuickShell process shared with Kaname";
    kanamePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = lib.literalExpression "inputs.kaname.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "Independent Kaname package embedded into the shared shell.";
    };
  };

  assertion = {
    assertion = !shared.enable || shared.kanamePackage != null;
    message = "programs.shirube.sharedShell.kanamePackage must be set when sharedShell is enabled.";
  };

  packages = lib.optional shared.enable shared.kanamePackage;

  prepare = pkgs.writeShellScript "shirube-kaname-prepare" ''
    ${lib.getExe cfg.package} --help >/dev/null
    config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/kaname"
    ${pkgs.coreutils}/bin/install -d "$config_root"
    if [ ! -e "$config_root/config.json" ]; then
      ${pkgs.coreutils}/bin/install -m644 \
        ${shared.kanamePackage}/share/kaname/config/default.json \
        "$config_root/config.json"
    fi
    if [ ! -e "$config_root/menus.json" ]; then
      ${pkgs.coreutils}/bin/install -m644 \
        ${shared.kanamePackage}/share/kaname/config/menus.json \
        "$config_root/menus.json"
    fi
  '';

  serviceEnvironment = [
    "QT_PLUGIN_PATH=${pkgs.qt6.qtimageformats}/lib/qt-6/plugins"
  ];
}
