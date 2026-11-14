#!/bin/sh
# MOSAIC installer. Run it from the MOSAIC download (normally ~/MOSAIC):
#   1. Creates your MOSAIC folder in the Klipper config folder
#      (~/printer_data/config/MOSAIC) with your one config file, mosaic.cfg,
#      and a link core/ -> this download, and adds  [include MOSAIC/mosaic.cfg]
#      to printer.cfg. Your file is never overwritten. An older install with
#      numbered files (00_core.cfg ...) is joined into mosaic.cfg.
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
# Your files from an older install:
# - dock positions that lived next to printer.cfg
if [ -f "$conf/mosaic_dock_positions.cfg" ] && [ ! -e "$dest/mosaic.cfg" ] && [ ! -e "$dest/20_dock_positions.cfg" ]; then
    mv "$conf/mosaic_dock_positions.cfg" "$dest/20_dock_positions.cfg"
    echo "moved your mosaic_dock_positions.cfg into $dest"
fi
# - the numbered files (00_core.cfg ... 90_settings.cfg): joined into one mosaic.cfg
#   in the order Klipper used to load them, the old files go to MOSAIC/old/
old=$(ls "$dest"/[0-9][0-9]_*.cfg 2>/dev/null || true)
if [ -n "$old" ] && [ ! -e "$dest/mosaic.cfg" ]; then
    mkdir -p "$dest/old"
    {
        echo "# MOSAIC: your configuration. This is the ONE file you edit."
        echo "# Joined from your numbered files by the installer, in the order they loaded."
        echo "# The originals are in the old/ folder next to this file. The current template,"
        echo "# with the explanations for every section, is in core/config/mosaic.cfg."
        echo
    } > "$dest/mosaic.cfg"
    for f in $old; do
        name=$(basename "$f")
        { echo "# ===== from $name ====="; cat "$f"; echo; } >> "$dest/mosaic.cfg"
        mv "$f" "$dest/old/$name"
    done
    echo "joined your numbered files into $dest/mosaic.cfg (originals: $dest/old/)"
fi
if [ ! -e "$dest/mosaic.cfg" ]; then
    cp "$here/config/mosaic.cfg" "$dest/mosaic.cfg"
    echo "  created mosaic.cfg - this is the one file you edit"
elif ! cmp -s "$here/config/mosaic.cfg" "$dest/mosaic.cfg"; then
    if [ -d "$dest/old" ] && grep -q "^# Joined from your numbered files" "$dest/mosaic.cfg"; then
        :   # a joined file always differs from the template, nothing to compare
    else
        cp "$here/config/mosaic.cfg" "$dest/mosaic.cfg.new"
        echo "  kept your mosaic.cfg (the current template is saved as mosaic.cfg.new)"
    fi
fi
# the one line in printer.cfg
if grep -q "^\[include MOSAIC/mosaic\.cfg\]" "$conf/printer.cfg"; then
    echo "printer.cfg already includes MOSAIC/mosaic.cfg"
elif grep -q "^\[include MOSAIC/\*\.cfg\]" "$conf/printer.cfg"; then
    cp "$conf/printer.cfg" "$conf/printer.cfg.mosaic-backup"
    sed -i "s|^\[include MOSAIC/\*\.cfg\]|[include MOSAIC/mosaic.cfg]|" "$conf/printer.cfg"
    echo "printer.cfg: [include MOSAIC/*.cfg] changed to [include MOSAIC/mosaic.cfg] (backup: printer.cfg.mosaic-backup)"
else
    cp "$conf/printer.cfg" "$conf/printer.cfg.mosaic-backup"
    { echo "[include MOSAIC/mosaic.cfg]"; cat "$conf/printer.cfg.mosaic-backup"; } > "$conf/printer.cfg"
    echo "added [include MOSAIC/mosaic.cfg] at the top of printer.cfg (backup: printer.cfg.mosaic-backup)"
fi
if grep -qE "^\[include (mosaic/|mosaic_dock_positions)" "$conf/printer.cfg"; then
    echo "NOTE: printer.cfg still has includes from an older MOSAIC install:"
    grep -nE "^\[include (mosaic/|mosaic_dock_positions)" "$conf/printer.cfg" | sed 's/^/    /'
    echo "      remove them, MOSAIC/mosaic.cfg loads everything now"
fi
stray=$(ls "$dest"/*.cfg 2>/dev/null | grep -v "/mosaic\.cfg$" || true)
if [ -n "$stray" ]; then
    echo "NOTE: only mosaic.cfg is loaded from $dest. These files are NOT loaded any more:"
    echo "$stray" | sed 's/^/    /'
    echo "      add an [include ...] line at the end of mosaic.cfg for any you still need"
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
    unit=/etc/systemd/system/mosaic.service
    # An earlier version called the service mosaic-ui; Moonraker only accepts the name "mosaic".
    if [ -f /etc/systemd/system/mosaic-ui.service ]; then
        sudo systemctl disable --now mosaic-ui >/dev/null 2>&1 || true
        sudo rm -f /etc/systemd/system/mosaic-ui.service
        echo "renamed the old service mosaic-ui to mosaic"
    fi
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
    if sudo install -m 644 "$tmp" "$unit" && sudo systemctl daemon-reload && sudo systemctl enable --now mosaic >/dev/null 2>&1; then
        sudo systemctl restart mosaic
        echo "service mosaic installed and running (user $user)"
    else
        echo "could not install the service (sudo?), see README 'The web page' for the manual steps"
    fi
    rm -f "$tmp"

    # Let Moonraker restart the service (needed for the update panel).
    asvc="$(dirname "$conf")/moonraker.asvc"
    if [ -f "$asvc" ]; then
        sed -i "/^mosaic-ui$/d" "$asvc"
        if ! grep -qx "mosaic" "$asvc"; then
            echo "mosaic" >> "$asvc"
            echo "added mosaic to $asvc"
        fi
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
            if grep -q "^managed_services:.*mosaic-ui" "$mconf"; then
                cp "$mconf" "$mconf.mosaic-backup"
                sed -i "s/^\(managed_services:.*\)mosaic-ui/\1mosaic/" "$mconf"
                sudo systemctl restart moonraker 2>/dev/null || true
                echo "update panel: fixed managed_services in moonraker.conf (backup: moonraker.conf.mosaic-backup), Moonraker restarted"
            else
                echo "update panel: already in moonraker.conf"
            fi
        else
            cat >> "$mconf" <<CONF

[update_manager mosaic]
type: git_repo
path: $here
origin: https://github.com/Slimohan/MOSAIC.git
primary_branch: main
managed_services: klipper mosaic
CONF
            sudo systemctl restart moonraker 2>/dev/null || true
            echo "update panel: MOSAIC added to moonraker.conf, Moonraker restarted"
        fi
    fi
fi

echo
echo "Next: edit $dest/mosaic.cfg (in Mainsail: Machine > MOSAIC > mosaic.cfg), section by section."
echo "Move your [tool Tn], tool heater/fan and [toolchanger] sections from printer.cfg into it."
echo "Then restart Klipper and run MOSAIC_CHECK."
[ -z "$NO_WEB" ] && echo "MOSAIC page: reload Mainsail and click MOSAIC in the sidebar."
