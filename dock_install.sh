#!/bin/sh
# Copy the MOSAIC dock macros into the Klipper config folder.
# Usage: ./install.sh [config folder]    (default: ~/printer_data/config)
# The engine (mosaic_dock.cfg) is always updated. Your positions file is never
# overwritten: if it exists, the fresh copy is stored as mosaic_dock_positions.cfg.new
set -e
here=$(cd "$(dirname "$0")" && pwd)
conf="${1:-$HOME/printer_data/config}"
[ -d "$conf" ] || { echo "config folder not found: $conf"; echo "usage: ./install.sh /path/to/config"; exit 1; }
dest="$conf/mosaic"
mkdir -p "$dest"
cp "$here/mosaic_dock.cfg" "$dest/mosaic_dock.cfg"
if [ -e "$dest/mosaic_dock_positions.cfg" ]; then
    cp "$here/mosaic_dock_positions.cfg" "$dest/mosaic_dock_positions.cfg.new"
    echo "kept your mosaic_dock_positions.cfg, new template saved as mosaic_dock_positions.cfg.new"
else
    cp "$here/mosaic_dock_positions.cfg" "$dest/mosaic_dock_positions.cfg"
    echo "created $dest/mosaic_dock_positions.cfg"
fi
echo "installed into $dest"
echo "Next: add these to printer.cfg and set the hooks in [toolchanger], see examples/printer.cfg.example"
echo "    [include mosaic/mosaic_dock.cfg]"
echo "    [include mosaic/mosaic_dock_positions.cfg]"
