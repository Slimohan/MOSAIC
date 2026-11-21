# Shared by install.sh and uninstall.sh: which Klipper instance this is, and
# what VRTX calls its service, page and update entry on this computer.
#
# The first printer on a computer gets the plain names: service vrtx, page
# /vrtx/ on port 8099, [update_manager vrtx]. Only when another printer on the
# same computer already has them (a KIAUH multi-instance setup, each printer in
# ~/printer_<NAME>_data with its own Moonraker port) does a printer get its own:
# vrtx-<NAME>, /vrtx-<NAME>/, port 8099 + (Moonraker port - 7125).
#
# Override with INSTANCE=..., MOONRAKER_PORT=..., PAGE_PORT=...
datadir=$(dirname "$conf")
finst=""
case "$(basename "$datadir")" in
    printer_data) ;;
    printer_*_data) finst=$(basename "$datadir"); finst=${finst#printer_}; finst=${finst%_data} ;;
esac
msuf=""
[ -n "$finst" ] && msuf="-$finst"
msvc="moonraker$msuf"
mport="${MOONRAKER_PORT:-$(python3 - "$conf/moonraker.conf" <<'PY'
import configparser, sys
cp = configparser.ConfigParser(strict=False, interpolation=None, inline_comment_prefixes=("#", ";"))
try:
    cp.read(sys.argv[1])
    print(cp.getint("server", "port", fallback=7125))
except Exception:
    print(7125)
PY
)}"
# Plain names unless another printer on this computer already has them.
inst="${INSTANCE:-}"
if [ -z "$inst" ] && [ -n "$finst" ] && [ -f /etc/systemd/system/vrtx.service ] \
   && ! grep -q "127.0.0.1:$mport\b" /etc/systemd/system/vrtx.service; then
    inst="$finst"
fi
case "$inst" in
    *[!A-Za-z0-9_-]*) echo "instance name '$inst' has characters other than letters, digits, - and _ - set INSTANCE=..."; exit 1 ;;
esac
suf=""
[ -n "$inst" ] && suf="-$inst"
name="vrtx$suf"
if [ -n "$PAGE_PORT" ]; then
    pport="$PAGE_PORT"
elif [ -z "$inst" ]; then
    pport=8099
elif [ "$mport" -gt 7125 ] && [ "$mport" -lt 7225 ]; then
    pport=$((8099 + mport - 7125))
else
    pport=8199
fi
