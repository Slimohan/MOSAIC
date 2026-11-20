#!/bin/sh
# MOSAIC installer. Run it from the MOSAIC download (normally ~/MOSAIC):
#   1. Creates your MOSAIC folder in the Klipper config folder
#      (~/printer_data/config/MOSAIC) with your one config file, mosaic.cfg,
#      and a link core/ -> this download, and adds  [include MOSAIC/mosaic.cfg]
#      to printer.cfg. Your file is never overwritten. An older install with
#      numbered files (00_core.cfg ...) is joined into mosaic.cfg.
#   2. Links the optional Z switch module into Klipper and Kalico.
#   3. Sets up the MOSAIC page: a service, the page at http://<printer>/mosaic/
#      through the web server of Mainsail and/or Fluidd, a MOSAIC entry in
#      Mainsail's sidebar (Fluidd has none), and MOSAIC in the Moonraker update
#      panel. Needs sudo for the service and nginx.
#
# Usage: ./install.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./install.sh   if your config folder is not ~/printer_data/config
#   COPY=1 ./install.sh                 to copy the module instead of symlinking it
#   NO_WEB=1 ./install.sh               to skip step 3
#   NGINX_SITE=/etc/nginx/sites-available/<name> ./install.sh   if your Mainsail or Fluidd site file has another name
#
# Several printers on one computer (KIAUH instances, ~/printer_<NAME>_data):
#   CONF=~/printer_<NAME>_data/config ./install.sh
# reads Moonraker's port from that instance's moonraker.conf and gives the
# instance its own page service (mosaic-<NAME>), page port and address
# (http://<computer>/mosaic-<NAME>/). Run it once per instance.
# Running it again is safe: every step checks what is already there.
set -e
here=$(cd "$(dirname "$0")" && pwd)
conf="${CONF:-$HOME/printer_data/config}"
conf="${conf%/}"
. "$here/instance.sh"
if [ -n "$inst" ]; then
    echo "instance $inst: Moonraker port $mport, MOSAIC service $name, page port $pport"
fi

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
        fname=$(basename "$f")
        { echo "# ===== from $fname ====="; cat "$f"; echo; } >> "$dest/mosaic.cfg"
        mv "$f" "$dest/old/$fname"
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
        fname=$(basename "$f")
        rm -f "$xdest/$fname"
        if [ -n "$COPY" ]; then cp "$f" "$xdest/$fname"; else ln -s "$f" "$xdest/$fname"; fi
    done
    echo "installed the Z switch module into $xdest"
done
[ $found -eq 1 ] || echo "no klippy/extras folder found, Z switch module not installed (only needed with [mosaic_z_probe]; pass the path to Klipper or Kalico)"

# --- 3. the MOSAIC page ------------------------------------------------------
if [ -z "$NO_WEB" ]; then
    echo "--- MOSAIC page"
    user=$(id -un)
    unit=/etc/systemd/system/$name.service
    # An earlier version called the service mosaic-ui; Moonraker only accepts the name "mosaic".
    if [ -z "$inst" ] && [ -f /etc/systemd/system/mosaic-ui.service ]; then
        sudo systemctl disable --now mosaic-ui >/dev/null 2>&1 || true
        sudo rm -f /etc/systemd/system/mosaic-ui.service
        echo "renamed the old service mosaic-ui to mosaic"
    fi
    # Converting a hand-made setup: the single "mosaic" service edited to talk to
    # this instance's Moonraker becomes $name, and its update panel entry,
    # Moonraker permission and /mosaic/ route go (the route only when no default
    # instance in ~/printer_data uses it).
    drop_default=0
    if [ -n "$inst" ] && [ -f /etc/systemd/system/mosaic.service ] && grep -q "127.0.0.1:$mport" /etc/systemd/system/mosaic.service; then
        echo "found the service mosaic pointed at this instance's Moonraker (port $mport): replacing it with $name"
        sudo systemctl disable --now mosaic >/dev/null 2>&1 || true
        sudo rm -f /etc/systemd/system/mosaic.service
        sudo systemctl daemon-reload
        if [ -f "$conf/moonraker.conf" ] && grep -q "^\[update_manager mosaic\]" "$conf/moonraker.conf"; then
            cp "$conf/moonraker.conf" "$conf/moonraker.conf.mosaic-backup"
            python3 - "$conf/moonraker.conf" "[update_manager mosaic]" <<'PY'
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
            echo "update panel: removed the old [update_manager mosaic] of this instance (backup: moonraker.conf.mosaic-backup)"
        fi
        [ -f "$datadir/moonraker.asvc" ] && sed -i "/^mosaic$/d" "$datadir/moonraker.asvc"
        [ -f "$HOME/printer_data/config/printer.cfg" ] || drop_default=1
    fi

    tmp=$(mktemp)
    cat > "$tmp" <<UNIT
[Unit]
Description=MOSAIC tool page ($name)
After=network.target $msvc.service

[Service]
User=$user
ExecStart=/usr/bin/python3 $here/ui/mosaic_server.py --port $pport --bind 127.0.0.1 --moonraker http://127.0.0.1:$mport
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
    if sudo install -m 644 "$tmp" "$unit" && sudo systemctl daemon-reload && sudo systemctl enable --now "$name" >/dev/null 2>&1; then
        sudo systemctl restart "$name"
        echo "service $name installed and running (user $user, page port $pport, Moonraker port $mport)"
    else
        echo "could not install the service (sudo?), see README 'The web page' for the manual steps"
    fi
    rm -f "$tmp"

    # Let Moonraker restart the service (needed for the update panel).
    asvc="$(dirname "$conf")/moonraker.asvc"
    if [ -f "$asvc" ]; then
        [ -z "$inst" ] && sed -i "/^mosaic-ui$/d" "$asvc"
        if ! grep -qx "$name" "$asvc"; then
            echo "$name" >> "$asvc"
            echo "added $name to $asvc"
        fi
    fi

    # The page at /mosaic/ (or /mosaic-<NAME>/) inside the nginx site of Mainsail and/or Fluidd.
    # The default instance uses the snippet in this download; an instance gets its
    # own snippet in /etc/nginx/mosaic/ (kept out of the download, so updates stay clean).
    if [ -z "$inst" ]; then
        snippet="$here/ui/nginx-mosaic.conf"
    else
        snippet="/etc/nginx/mosaic/$name.conf"
        tmp=$(mktemp)
        sed -e "s|/mosaic|/$name|g" -e "s|127.0.0.1:8099|127.0.0.1:$pport|" "$here/ui/nginx-mosaic.conf" > "$tmp"
        sudo mkdir -p /etc/nginx/mosaic && sudo install -m 644 "$tmp" "$snippet" || echo "nginx: could not write $snippet (sudo?)"
        rm -f "$tmp"
    fi
    if [ -n "$NGINX_SITE" ]; then
        sites="$NGINX_SITE"
    else
        sites=""
        for site_name in mainsail fluidd; do
            [ -f "/etc/nginx/sites-available/$site_name" ] && sites="$sites /etc/nginx/sites-available/$site_name"
        done
    fi
    if [ -z "$sites" ]; then
        echo "nginx: no Mainsail or Fluidd site found in /etc/nginx/sites-available, the page is only on this machine at port $pport (set NGINX_SITE=/etc/nginx/sites-available/<name> and run again)"
    fi
    for site in $sites; do
        if [ $drop_default -eq 1 ] && [ -f "$site" ] && grep -q "ui/nginx-mosaic.conf" "$site"; then
            sudo cp "$site" "$site.mosaic-backup"
            sudo sed -i "\|ui/nginx-mosaic.conf|d" "$site"
            echo "nginx: removed the old /mosaic/ route from $site (backup: $site.mosaic-backup)"
        fi
        if [ ! -f "$site" ]; then
            echo "nginx: $site not found (set NGINX_SITE=... to the right file and run again)"
        elif grep -qF "$snippet" "$site"; then
            echo "nginx: /$name/ already set up in $site"
        else
            sudo cp "$site" "$site.$name-backup"
            # insert the include as the first line inside the server block
            if sudo sed -i "0,/server[[:space:]]*{/s||&\n    include $snippet;  # MOSAIC page ($name)|" "$site" && sudo nginx -t >/dev/null 2>&1; then
                sudo systemctl reload nginx
                echo "nginx: the page is at http://<printer>/$name/ via $site (backup: $site.$name-backup)"
            else
                sudo cp "$site.$name-backup" "$site"
                echo "nginx: could not add /$name/, $site restored unchanged"
            fi
        fi
    done

    # The MOSAIC entry in Mainsail's sidebar (.theme/navi.json, merged with yours).
    # Fluidd has no such feature; skipped when Mainsail is not installed.
    mainsail=0
    [ -d "$HOME/mainsail" ] && mainsail=1
    case " $sites " in *mainsail*) mainsail=1 ;; esac
    [ -n "$NGINX_SITE" ] && mainsail=1
    if [ $mainsail -eq 0 ]; then
        echo "sidebar: Mainsail not found, no sidebar entry (open http://<printer>/mosaic/ or bookmark it)"
    elif [ -f "$conf/printer.cfg" ]; then
        mkdir -p "$conf/.theme"
        python3 - "$conf/.theme/navi.json" "$here/examples/mainsail/navi.json" "/$name/" <<'PY'
import json, os, sys
path, template, href = sys.argv[1], sys.argv[2], sys.argv[3]
entry = json.load(open(template))[0]
entry["href"] = href
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

    # MOSAIC in the Moonraker update panel of this instance.
    mconf="$conf/moonraker.conf"
    if [ -f "$mconf" ]; then
        if grep -q "^\[update_manager $name\]" "$mconf"; then
            if [ -z "$inst" ] && grep -q "^managed_services:.*mosaic-ui" "$mconf"; then
                cp "$mconf" "$mconf.mosaic-backup"
                sed -i "s/^\(managed_services:.*\)mosaic-ui/\1mosaic/" "$mconf"
                sudo systemctl restart "$msvc" 2>/dev/null || true
                echo "update panel: fixed managed_services in moonraker.conf (backup: moonraker.conf.mosaic-backup), Moonraker restarted"
            else
                echo "update panel: already in moonraker.conf"
            fi
        else
            cat >> "$mconf" <<CONF

[update_manager $name]
type: git_repo
path: $here
origin: https://github.com/Slimohan/MOSAIC.git
primary_branch: main
managed_services: klipper $name
CONF
            sudo systemctl restart "$msvc" 2>/dev/null || true
            echo "update panel: MOSAIC added to moonraker.conf as [update_manager $name], $msvc restarted"
        fi
    fi
fi

echo
echo "Next: edit $dest/mosaic.cfg (Mainsail: Machine > MOSAIC > mosaic.cfg; Fluidd: Configuration > MOSAIC), section by section."
echo "Move your [tool Tn], tool heater/fan and [toolchanger] sections from printer.cfg into it."
echo "Then restart Klipper and run MOSAIC_CHECK."
[ -z "$NO_WEB" ] && echo "MOSAIC page: http://<printer>/$name/ (Mainsail: reload and click MOSAIC in the sidebar; Fluidd: bookmark the address)."
