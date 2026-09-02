#!/bin/sh
set -eu

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
bin_home=${SHIRUBE_BIN_HOME:-"$HOME/.local/bin"}
config_root="$config_home/shirube"

systemctl --user disable --now shirube.service 2>/dev/null || true
rm -f "$config_home/systemd/user/shirube.service"
rm -f "$bin_home/shirube"
rm -rf "$data_home/shirube"
rm -rf "$cache_home/shirube"

if [ "${1:-}" = "--purge" ]; then
    rm -rf "$config_root"
    printf '%s\n' "Removed Shirube and its user configuration."
else
    printf '%s\n' "Removed Shirube. Configuration remains in $config_root"
fi
