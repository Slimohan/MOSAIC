#!/bin/sh
# VRTX uninstaller: undoes what install.sh set up.
#   - the [include VRTX/vrtx.cfg] line in printer.cfg (a backup is kept)
#   - the core link in your VRTX folder
#   - the vrtx service (and vrtx-ui, its name in an earlier version)
#   - the /vrtx/ include in the nginx site of Mainsail and/or Fluidd (a backup is kept)
#   - the VRTX entry in Mainsail's sidebar (.theme/navi.json)
#   - [update_manager vrtx] in moonraker.conf and vrtx in moonraker.asvc (backups are kept)
#   - the Z switch module links in Klipper and Kalico
#
# Your VRTX folder with your vrtx.cfg (tools, settings, dock positions) and the
# saved offsets and filaments in [save_variables] are kept. Your tools and the
# [toolchanger] section live in that folder: move them back into printer.cfg
# if you keep using the tool changer without VRTX.
#
# Usage: ./uninstall.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./uninstall.sh   if your config folder is not ~/printer_data/config
#   NGINX_SITE=/etc/nginx/sites-available/<name> ./uninstall.sh
# Running it twice is safe.
set -e
here=$(cd "$(dirname "$0")" && pwd)
conf="${CONF:-$HOME/printer_data/config}"
conf="${conf%/}"
stamp=$(date +%Y%m%d-%H%M%S)
. "$here/instance.sh"
[ -n "$inst" ] && echo "instance $inst: removing VRTX service $name"

# --- printer.cfg and the core link -----------------------------------------
if [ -f "$conf/printer.cfg" ] && grep -qE "^\[include VRTX/(vrtx|\*)\.cfg\]" "$conf/printer.cfg"; then
    cp "$conf/printer.cfg" "$conf/printer.cfg.vrtx-uninstall-$stamp"
    sed -i -E "/^\[include VRTX\/(vrtx|\*)\.cfg\]/d" "$conf/printer.cfg"
    echo "printer.cfg: the VRTX include removed (backup: printer.cfg.vrtx-uninstall-$stamp)"
fi
if [ -L "$conf/VRTX/core" ]; then
    rm -f "$conf/VRTX/core"
    echo "removed the core link in $conf/VRTX"
fi

# --- the service ------------------------------------------------------------
if [ -f "/etc/systemd/system/$name.service" ] || { [ -z "$inst" ] && [ -f /etc/systemd/system/vrtx-ui.service ]; }; then
    svcs="$name"
    [ -z "$inst" ] && svcs="vrtx vrtx-ui"
    for svc in $svcs; do
        sudo systemctl disable --now "$svc" >/dev/null 2>&1 || true
        sudo rm -f "/etc/systemd/system/$svc.service"
    done
    sudo systemctl daemon-reload
    echo "service $name removed"
else
    echo "service: not installed"
fi

# --- nginx -----------------------------------------------------------------
sites="${NGINX_SITE:-/etc/nginx/sites-available/mainsail /etc/nginx/sites-available/fluidd}"
removed=0
if [ -z "$inst" ]; then snippet="nginx-vrtx.conf"; else snippet="/etc/nginx/vrtx/$name.conf"; fi
for site in $sites; do
    if [ -f "$site" ] && grep -qF "$snippet" "$site"; then
        sudo cp "$site" "$site.vrtx-uninstall-$stamp"
        sudo sed -i "\|$snippet|d" "$site"
        if sudo nginx -t >/dev/null 2>&1; then
            sudo systemctl reload nginx
            echo "nginx: /$name/ removed from $site (backup: $site.vrtx-uninstall-$stamp)"
        else
            sudo cp "$site.vrtx-uninstall-$stamp" "$site"
            echo "nginx: the check failed after removing /$name/, $site restored unchanged; remove the line with $snippet by hand"
        fi
        removed=1
    fi
done
if [ -n "$inst" ] && [ -f "/etc/nginx/vrtx/$name.conf" ]; then
    sudo rm -f "/etc/nginx/vrtx/$name.conf"
fi
[ $removed -eq 1 ] || echo "nginx: nothing to remove"

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
kept = [e for e in entries if e.get("title") != "VRTX"]
if len(kept) == len(entries):
    print("sidebar: no VRTX entry")
elif kept:
    json.dump(kept, open(path, "w"), indent=2); print("sidebar: VRTX entry removed")
else:
    os.remove(path); print("sidebar: VRTX entry removed (navi.json was empty, deleted)")
PY
fi

# --- update panel ------------------------------------------------------------
mconf="$conf/moonraker.conf"
if [ -f "$mconf" ] && grep -q "^\[update_manager $name\]" "$mconf"; then
    cp "$mconf" "$mconf.vrtx-uninstall-$stamp"
    python3 - "$mconf" "[update_manager $name]" <<'PY'
import sys
path, header = sys.argv[1], sys.argv[2]
out, skip = [], False
for line in open(path).read().splitlines(True):
    if line.strip() == header:
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
    echo "update panel: [update_manager $name] removed (backup: $mconf.vrtx-uninstall-$stamp)"
    sudo systemctl restart "$msvc" 2>/dev/null || true
fi
asvc="$(dirname "$conf")/moonraker.asvc"
if [ -f "$asvc" ] && grep -qxE "$name|vrtx-ui" "$asvc"; then
    sed -i -E "/^($name|vrtx-ui)$/d" "$asvc"
    echo "removed $name from $asvc"
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
echo "    from sections 4 and 5 of $conf/VRTX/vrtx.cfg back into printer.cfg (without the VRTX dock hooks)"
echo "  - restart Klipper"
echo "  - delete $conf/VRTX and $here when you no longer want them"
echo "Kept: your vrtx.cfg in $conf/VRTX and the VRTX values in [save_variables]."
