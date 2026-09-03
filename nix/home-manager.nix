{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.shirube;
  shared = cfg.sharedShell;
  sharedSupport = import ./shared-shell.nix { inherit cfg lib pkgs; };
  sharedRoot = "${config.xdg.configHome}/quickshell/shirube-kaname";
  managedConfigSource = lib.attrByPath [
    "xdg"
    "configFile"
    "shirube/config.json"
    "source"
  ] null config;
in
{
  options.programs.shirube = {
    enable = lib.mkEnableOption "Shirube light-field interface";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Shirube package to install.";
    };
    autostart = lib.mkEnableOption "Shirube at graphical-session startup" // {
      default = true;
    };
    sharedShell = sharedSupport.options;
  };

  config = lib.mkIf cfg.enable {
    assertions = [ sharedSupport.assertion ];

    home.packages = [ cfg.package ] ++ sharedSupport.packages;
    home.sessionVariables = lib.mkIf shared.enable {
      SHIRUBE_QML_DIR = sharedRoot;
      KANAME_QML_DIR = sharedRoot;
    };
    xdg.configFile = lib.mkIf shared.enable {
      "quickshell/shirube-kaname/shell.qml".source = ../examples/shared-shell/shell.qml;
      "quickshell/shirube-kaname/Shirube".source = "${cfg.package}/share/shirube";
      "quickshell/shirube-kaname/Kaname".source = "${shared.kanamePackage}/share/kaname/quickshell";
    };
    systemd.user.services.shirube = lib.mkIf cfg.autostart {
      Unit = {
        Description = "Shirube light-field interface";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # Home Manager replaces declarative config files with a new store
        # symlink during activation. File watchers cannot reliably observe that
        # replacement, so restart the shell whenever its managed config changes.
        X-Restart-Triggers = [ cfg.package ] ++ lib.optional (managedConfigSource != null) managedConfigSource;
      };
      Service = {
        ExecStart =
          if shared.enable then "${pkgs.quickshell}/bin/qs -p ${sharedRoot}" else "${lib.getExe cfg.package}";
        Restart = "on-failure";
        RestartSec = 2;
      }
      // lib.optionalAttrs shared.enable {
        ExecStartPre = sharedSupport.prepare;
        Environment = sharedSupport.serviceEnvironment;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
