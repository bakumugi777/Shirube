#!/bin/sh
set -eu

source_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
bin_home=${SHIRUBE_BIN_HOME:-"$HOME/.local/bin"}
install_root="$data_home/shirube"
config_root="$config_home/shirube"
service_root="$config_home/systemd/user"

mkdir -p "$install_root/helpers" "$install_root/matugen/templates" \
    "$config_root/matugen" "$service_root" "$bin_home" "$state_home/shirube"

for source in "$source_dir"/*.qml; do
    install -m644 "$source" "$install_root/$(basename "$source")"
done
if [ ! -e "$config_root/config.json" ]; then
    install -m644 "$source_dir/config.json" "$config_root/config.json"
fi
install -m644 "$source_dir/matugen/templates/shirube-colors.json" \
    "$install_root/matugen/templates/shirube-colors.json"
if [ ! -e "$config_root/matugen/shirube-colors.json" ]; then
    install -m644 "$source_dir/matugen/templates/shirube-colors.json" \
        "$config_root/matugen/shirube-colors.json"
fi
sh "$source_dir/helpers/build.sh"
install -m755 "$source_dir/helpers/shirube-audio-rms" "$install_root/helpers/shirube-audio-rms"
install -m644 "$source_dir/systemd/shirube.service" "$service_root/shirube.service"

sed \
    -e "s|@INSTALL_ROOT@|$install_root|g" \
    "$source_dir/scripts/shirube.in" > "$bin_home/shirube"
chmod 755 "$bin_home/shirube"

printf '%s\n' "Installed Shirube."
printf '%s\n' "Run: $bin_home/shirube"
printf '%s\n' "Autostart: systemctl --user enable --now shirube.service"
