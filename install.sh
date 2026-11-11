#!/bin/sh
# MOSAIC installer. Run it from the MOSAIC download (normally ~/MOSAIC):
#   1. Creates your MOSAIC folder in the Klipper config folder
#      (~/printer_data/config/MOSAIC) with your config files and a link
#      core/ -> this download, and adds  [include MOSAIC/*.cfg]  to
#      printer.cfg. Your files are never overwritten.
#   2. Links the optional Z switch module into Klipper and Kalico.
#   3. Sets up the MOSAIC page: a service, the page at http://<printer>/mosaic/
#      through Mainsail's web server, a MOSAIC entry in Mainsail's sidebar,
#      and MOSAIC in Mainsail's update panel. Needs sudo for the service and nginx.
#
# Usage: ./install.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./install.sh   if your config folder is not ~/printer_data/config
#   COPY=1 ./install.sh                 to copy the module instead of symlinking it
#   NO_WEB=1 ./install.sh               to skip step 3
#   NGINX_SITE=/etc/nginx/sites-available/<name> ./install.sh   if Mainsail's site file has another name
# Running it again is safe: every step checks what is already there.
set -e
here=$(cd "$(dirname "$0")" && pwd)
conf="${CONF:-$HOME/printer_data/config}"

# --- 1. your MOSAIC folder -----------------------------------------------------
if [ ! -f "$conf/printer.cfg" ]; then
    echo "no printer.cfg in $conf - set CONF=/path/to/config and run again"
    exit 1
fi
case "$here/" in
    "$conf"/*) echo "This MOSAIC download is inside the config folder ($here)."
               echo "Clone it into your home folder instead:  cd ~ && git clone https://github.com/Slimohan/MOSAIC"
               exit 1 ;;
esac
dest="$conf/MOSAIC"
mkdir -p "$dest"
if [ -e "$dest/core" ] && [ ! -L "$dest/core" ]; then
    echo "$dest/core exists and is not a link - move it away and run again"
    exit 1
fi
ln -sfn "$here" "$dest/core"
echo "MOSAIC folder: $dest (core -> $here)"
# your dock positions from an older install, next to printer.cfg
if [ -f "$conf/mosaic_dock_positions.cfg" ] && [ ! -e "$dest/20_dock_positions.cfg" ]; then
    mv "$conf/mosaic_dock_positions.cfg" "$dest/20_dock_positions.cfg"
    echo "moved your mosaic_dock_positions.cfg to $dest/20_dock_positions.cfg"
fi
for f in "$here"/config/*.cfg; do
    name=$(basename "$f")
    if [ ! -e "$dest/$name" ]; then
        cp "$f" "$dest/$name"
        echo "  created $name"
    elif ! cmp -s "$f" "$dest/$name"; then
        cp "$f" "$dest/$name.new"
        echo "  kept your $name (the current template is saved as $name.new)"
    fi
done
# the one line in printer.cfg
if grep -q "^\[include MOSAIC/\*\.cfg\]" "$conf/printer.cfg"; then
    echo "printer.cfg already includes MOSAIC/*.cfg"
else
    cp "$conf/printer.cfg" "$conf/printer.cfg.mosaic-backup"
    { echo "[include MOSAIC/*.cfg]"; cat "$conf/printer.cfg.mosaic-backup"; } > "$conf/printer.cfg"
    echo "added [include MOSAIC/*.cfg] at the top of printer.cfg (backup: printer.cfg.mosaic-backup)"
fi
if grep -qE "^\[include (mosaic/|mosaic_dock_positions)" "$conf/printer.cfg"; then
    echo "NOTE: printer.cfg still has includes from an older MOSAIC install:"
    grep -nE "^\[include (mosaic/|mosaic_dock_positions)" "$conf/printer.cfg" | sed 's/^/    /'
    echo "      remove them, the MOSAIC folder loads everything now"
fi

# --- 2. Z switch module ------------------------------------------------------
[ $# -eq 0 ] && set -- "$HOME/klipper" "$HOME/kalico"
found=0
for tree in "$@"; do
    xdest="$tree/klippy/extras"
    [ -d "$xdest" ] || continue
    found=1
    for f in "$here"/klippy_extras/*.py; do
        name=$(basename "$f")
        rm -f "$xdest/$name"
        if [ -n "$COPY" ]; then cp "$f" "$xdest/$name"; else ln -s "$f" "$xdest/$name"; fi
    done
    echo "installed the Z switch module into $xdest"
done
[ $found -eq 1 ] || echo "no klippy/extras folder found, Z switch module not installed (only needed with [mosaic_z_probe]; pass the path to Klipper or Kalico)"

# --- 3. the MOSAIC page ------------------------------------------------------
if [ -z "$NO_WEB" ]; then
    echo "--- MOSAIC page"
    user=$(id -un)
    unit=/etc/systemd/system/mosaic-ui.service
    tmp=$(mktemp)
    cat > "$tmp" <<UNIT
[Unit]
Description=MOSAIC tool page
After=network.target moonraker.service

[Service]
User=$user
ExecStart=/usr/bin/python3 $here/ui/mosaic_server.py --port 8099 --bind 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
    if sudo install -m 644 "$tmp" "$unit" && sudo systemctl daemon-reload && sudo systemctl enable --now mosaic-ui >/dev/null 2>&1; then
        sudo systemctl restart mosaic-ui
        echo "service mosaic-ui installed and running (user $user)"
    else
        echo "could not install the service (sudo?), see README 'The web page' for the manual steps"
    fi
    rm -f "$tmp"

    # Let Moonraker restart the service (needed for the update panel).
    asvc="$(dirname "$conf")/moonraker.asvc"
    if [ -f "$asvc" ] && ! grep -qx "mosaic-ui" "$asvc"; then
        echo "mosaic-ui" >> "$asvc"
        echo "added mosaic-ui to $asvc"
    fi

    # The page at /mosaic/ inside Mainsail's nginx site.
    site="${NGINX_SITE:-/etc/nginx/sites-available/mainsail}"
    if [ -f "$site" ]; then
        if grep -q "nginx-mosaic.conf" "$site"; then
            echo "nginx: /mosaic/ already set up in $site"
        else
            sudo cp "$site" "$site.mosaic-backup"
            # insert the include as the first line inside the server block
            if sudo sed -i "0,/server[[:space:]]*{/s||&\n    include $here/ui/nginx-mosaic.conf;  # MOSAIC page|" "$site" && sudo nginx -t >/dev/null 2>&1; then
                sudo systemctl reload nginx
                echo "nginx: the page is at http://<printer>/mosaic/ (backup: $site.mosaic-backup)"
            else
                sudo cp "$site.mosaic-backup" "$site"
                echo "nginx: could not add /mosaic/, $site restored unchanged"
            fi
        fi
    else
        echo "nginx: $site not found, the page is only on this machine at port 8099 (set NGINX_SITE=... and run again)"
    fi

    # The MOSAIC entry in Mainsail's sidebar (.theme/navi.json, merged with yours).
    if [ -f "$conf/printer.cfg" ]; then
        mkdir -p "$conf/.theme"
        python3 - "$conf/.theme/navi.json" "$here/examples/mainsail/navi.json" <<'PY'
import json, os, sys
path, template = sys.argv[1], sys.argv[2]
entry = json.load(open(template))[0]
entries = []
if os.path.exists(path):
    try:
        entries = json.load(open(path))
    except ValueError:
        print("sidebar: %s is not valid JSON, left unchanged" % path)
        sys.exit(0)
entries = [e for e in entries if e.get("title") != entry["title"]] + [entry]
json.dump(entries, open(path, "w"), indent=2)
print("sidebar: MOSAIC entry in %s (reload Mainsail to see it)" % path)
PY
    fi

    # MOSAIC in Mainsail's update panel.
    mconf="$conf/moonraker.conf"
    if [ -f "$mconf" ]; then
        if grep -q "^\[update_manager mosaic\]" "$mconf"; then
            echo "update panel: already in moonraker.conf"
        else
            cat >> "$mconf" <<CONF

[update_manager mosaic]
type: git_repo
path: $here
origin: https://github.com/Slimohan/MOSAIC.git
primary_branch: main
managed_services: klipper mosaic-ui
CONF
            sudo systemctl restart moonraker 2>/dev/null || true
            echo "update panel: MOSAIC added to moonraker.conf, Moonraker restarted"
        fi
    fi
fi

echo
echo "Next: edit the files in $dest (in Mainsail: Machine > MOSAIC):"
echo "  40_tools.cfg, 10_hardware.cfg, 90_settings.cfg, then 50_switches.cfg and 20_dock_positions.cfg."
echo "Move your [tool Tn], tool heater/fan and [toolchanger] sections from printer.cfg into them."
echo "Then restart Klipper and run MOSAIC_CHECK."
[ -z "$NO_WEB" ] && echo "MOSAIC page: reload Mainsail and click MOSAIC in the sidebar."
