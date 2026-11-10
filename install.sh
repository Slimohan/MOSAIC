#!/bin/sh
# MOSAIC installer.
#   1. Creates your dock positions file next to printer.cfg (never overwrites it).
#   2. Links the optional Z switch module into Klipper and Kalico.
#
# Usage: ./install.sh [path to klipper or kalico, ...]   (default: ~/klipper ~/kalico)
#   CONF=/path/to/config ./install.sh   if this folder is not inside your config folder
#   COPY=1 ./install.sh                 to copy the module instead of symlinking it
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

echo "Next: add the includes and the [toolchanger] hooks to printer.cfg (see examples/printer.cfg.example), restart Klipper, run MOSAIC_CHECK."
echo "Web page: see README.md, section 'The web page'."
