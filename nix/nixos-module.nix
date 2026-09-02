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
  sharedRoot = "/etc/xdg/quickshell/shirube-kaname";
in
{
  options.programs.shirube = {
    enable = lib.mkEnableOption "Shirube light-field interface";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Shirube package to install for all users.";
    };
    autostart = lib.mkEnableOption "Shirube for graphical user sessions" // {
      default = true;
    };
    sharedShell = sharedSupport.options;
  };

  config = lib.mkIf cfg.enable {
    assertions = [ sharedSupport.assertion ];
    environment.systemPackages = [ cfg.package ] ++ sharedSupport.packages;
    environment.sessionVariables = lib.mkIf shared.enable {
      SHIRUBE_QML_DIR = sharedRoot;
      KANAME_QML_DIR = sharedRoot;
    };
    environment.etc = lib.mkIf shared.enable {
      "xdg/quickshell/shirube-kaname/shell.qml".source = ../examples/shared-shell/shell.qml;
      "xdg/quickshell/shirube-kaname/Shirube".source = "${cfg.package}/share/shirube";
      "xdg/quickshell/shirube-kaname/Kaname".source = "${shared.kanamePackage}/share/kaname/quickshell";
    };
    systemd.user.services.shirube = lib.mkIf cfg.autostart {
      description = "Shirube light-field interface";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart =
          if shared.enable then "${pkgs.quickshell}/bin/qs -p ${sharedRoot}" else lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 2;
      }
      // lib.optionalAttrs shared.enable {
        ExecStartPre = sharedSupport.prepare;
        Environment = sharedSupport.serviceEnvironment;
      };
    };
  };
}
