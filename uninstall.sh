#!/bin/sh
# MOSAIC uninstaller: undoes what install.sh set up.
#   - the [include MOSAIC/mosaic.cfg] line in printer.cfg (a backup is kept)
#   - the core link in your MOSAIC folder
#   - the mosaic-ui service
#   - the /mosaic/ include in Mainsail's nginx site (a backup is kept)
#   - the MOSAIC entry in Mainsail's sidebar (.theme/navi.json)
#   - [update_manager mosaic] in moonraker.conf and mosaic-ui in moonraker.asvc (backups are kept)
#   - the Z switch module links in Klipper and Kalico
#
# Your MOSAIC folder with your mosaic.cfg (tools, settings, dock positions) and the
# saved offsets and filaments in [save_variables] are kept. Your tools and the
# [toolchanger] section live in that folder: move them back into printer.cfg
# if you keep using the tool changer without MOSAIC.
#
# Usage: ./uninstall.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./uninstall.sh   if your config folder is not ~/printer_data/config
#   NGINX_SITE=/etc/nginx/sites-available/<name> ./uninstall.sh
# Running it twice is safe.
set -e
here=$(cd "$(dirname "$0")" && pwd)
conf="${CONF:-$HOME/printer_data/config}"
stamp=$(date +%Y%m%d-%H%M%S)

# --- printer.cfg and the core link -----------------------------------------
if [ -f "$conf/printer.cfg" ] && grep -qE "^\[include MOSAIC/(mosaic|\*)\.cfg\]" "$conf/printer.cfg"; then
    cp "$conf/printer.cfg" "$conf/printer.cfg.mosaic-uninstall-$stamp"
    sed -i -E "/^\[include MOSAIC\/(mosaic|\*)\.cfg\]/d" "$conf/printer.cfg"
    echo "printer.cfg: the MOSAIC include removed (backup: printer.cfg.mosaic-uninstall-$stamp)"
fi
if [ -L "$conf/MOSAIC/core" ]; then
    rm -f "$conf/MOSAIC/core"
    echo "removed the core link in $conf/MOSAIC"
fi

# --- the service ------------------------------------------------------------
unit=/etc/systemd/system/mosaic-ui.service
if [ -f "$unit" ]; then
    sudo systemctl disable --now mosaic-ui >/dev/null 2>&1 || true
    sudo rm -f "$unit"
    sudo systemctl daemon-reload
    echo "service mosaic-ui removed"
else
    echo "service: not installed"
fi

# --- nginx -----------------------------------------------------------------
site="${NGINX_SITE:-/etc/nginx/sites-available/mainsail}"
if [ -f "$site" ] && grep -q "nginx-mosaic.conf" "$site"; then
    sudo cp "$site" "$site.mosaic-uninstall-$stamp"
    sudo sed -i "/nginx-mosaic.conf/d" "$site"
    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl reload nginx
        echo "nginx: /mosaic/ removed from $site (backup: $site.mosaic-uninstall-$stamp)"
    else
        sudo cp "$site.mosaic-uninstall-$stamp" "$site"
        echo "nginx: the check failed after removing /mosaic/, $site restored unchanged; remove the line with nginx-mosaic.conf by hand"
    fi
else
    echo "nginx: nothing to remove"
fi

# --- sidebar entry ----------------------------------------------------------
navi="$conf/.theme/navi.json"
if [ -f "$navi" ]; then
    python3 - "$navi" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    entries = json.load(open(path))
except ValueError:
    print("sidebar: %s is not valid JSON, left unchanged" % path); sys.exit(0)
kept = [e for e in entries if e.get("title") != "MOSAIC"]
if len(kept) == len(entries):
    print("sidebar: no MOSAIC entry")
elif kept:
    json.dump(kept, open(path, "w"), indent=2); print("sidebar: MOSAIC entry removed")
else:
    os.remove(path); print("sidebar: MOSAIC entry removed (navi.json was empty, deleted)")
PY
fi

# --- update panel ------------------------------------------------------------
mconf="$conf/moonraker.conf"
if [ -f "$mconf" ] && grep -q "^\[update_manager mosaic\]" "$mconf"; then
    cp "$mconf" "$mconf.mosaic-uninstall-$stamp"
    python3 - "$mconf" <<'PY'
import sys
path = sys.argv[1]
out, skip = [], False
for line in open(path).read().splitlines(True):
    if line.strip() == "[update_manager mosaic]":
        skip = True
        while out and not out[-1].strip():
            out.pop()
        continue
    if skip and line.lstrip().startswith("["):
        skip = False
        out.append("\n")
    if not skip:
        out.append(line)
open(path, "w").write("".join(out).rstrip("\n") + "\n")
PY
    echo "update panel: [update_manager mosaic] removed (backup: $mconf.mosaic-uninstall-$stamp)"
    sudo systemctl restart moonraker 2>/dev/null || true
fi
asvc="$(dirname "$conf")/moonraker.asvc"
if [ -f "$asvc" ] && grep -qx "mosaic-ui" "$asvc"; then
    sed -i "/^mosaic-ui$/d" "$asvc"
    echo "removed mosaic-ui from $asvc"
fi

# --- Z switch module ---------------------------------------------------------
[ $# -eq 0 ] && set -- "$HOME/klipper" "$HOME/kalico"
for tree in "$@"; do
    dest="$tree/klippy/extras"
    [ -d "$dest" ] || continue
    for f in "$here"/klippy_extras/*.py; do
        name=$(basename "$f")
        if [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
            rm -f "$dest/$name"
            echo "removed $dest/$name"
        fi
    done
done

echo
echo "Left for you to do:"
echo "  - if you keep the tool changer: move your [tool Tn], heater/fan and [toolchanger] sections"
echo "    from sections 4 and 5 of $conf/MOSAIC/mosaic.cfg back into printer.cfg (without the MOSAIC dock hooks)"
echo "  - restart Klipper"
echo "  - delete $conf/MOSAIC and $here when you no longer want them"
echo "Kept: your mosaic.cfg in $conf/MOSAIC and the MOSAIC values in [save_variables]."
