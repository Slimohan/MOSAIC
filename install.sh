#!/bin/sh
# MOSAIC installer.
#   1. Creates your dock positions file next to printer.cfg (never overwrites it).
#   2. Links the optional Z switch module into Klipper and Kalico.
#   3. Sets up the MOSAIC page: a service, the page at http://<printer>/mosaic/
#      through Mainsail's web server, a MOSAIC entry in Mainsail's sidebar,
#      and MOSAIC in Mainsail's update panel. Needs sudo for the service and nginx.
#
# Usage: ./install.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./install.sh   if this folder is not inside your config folder
#   COPY=1 ./install.sh                 to copy the module instead of symlinking it
#   NO_WEB=1 ./install.sh               to skip step 3
#   NGINX_SITE=/etc/nginx/sites-available/<name> ./install.sh   if Mainsail's site file has another name
# Running it again is safe: every step checks what is already there.
set -e
here=$(cd "$(dirname "$0")" && pwd)

# --- 1. dock positions -------------------------------------------------------
# The positions file is yours, so it lives in the config folder, outside this
# git folder: a "git pull" of MOSAIC can never overwrite or conflict with it.
conf="${CONF:-$(dirname "$here")}"
if [ -f "$conf/printer.cfg" ]; then
    if [ -e "$conf/mosaic_dock_positions.cfg" ]; then
        cp "$here/examples/mosaic_dock_positions.cfg" "$conf/mosaic_dock_positions.cfg.new"
        echo "kept your mosaic_dock_positions.cfg, fresh template saved as mosaic_dock_positions.cfg.new"
    else
        cp "$here/examples/mosaic_dock_positions.cfg" "$conf/mosaic_dock_positions.cfg"
        echo "created $conf/mosaic_dock_positions.cfg"
    fi
else
    echo "no printer.cfg in $conf, dock positions file not created (set CONF=/path/to/config)"
fi

# --- 2. Z switch module ------------------------------------------------------
[ $# -eq 0 ] && set -- "$HOME/klipper" "$HOME/kalico"
found=0
for tree in "$@"; do
    dest="$tree/klippy/extras"
    [ -d "$dest" ] || continue
    found=1
    # the module was called vaoc_z_probe.py before the rename to MOSAIC
    [ -L "$dest/vaoc_z_probe.py" ] && rm -f "$dest/vaoc_z_probe.py"
    for f in "$here"/klippy_extras/*.py; do
        name=$(basename "$f")
        rm -f "$dest/$name"
        if [ -n "$COPY" ]; then cp "$f" "$dest/$name"; else ln -s "$f" "$dest/$name"; fi
    done
    echo "installed the Z switch module into $dest"
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

echo "Next: add the includes and the [toolchanger] hooks to printer.cfg (see examples/printer.cfg.example), restart Klipper, run MOSAIC_CHECK."
[ -z "$NO_WEB" ] && echo "MOSAIC page: reload Mainsail and click MOSAIC in the sidebar."
