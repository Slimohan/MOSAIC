# Shared by install.sh and uninstall.sh: which Klipper instance this is.
# A KIAUH multi-instance setup keeps each printer in ~/printer_<NAME>_data with
# its own klipper-<NAME> and moonraker-<NAME> services and Moonraker port, so
# VRTX gets its own service, page port and page address per instance:
#
#   ~/printer_data/config                 -> vrtx,           /vrtx/,           port 8099
#   ~/printer_PICOTRAIN_data/config       -> vrtx-PICOTRAIN, /vrtx-PICOTRAIN/, port 8099 + (Moonraker port - 7125)
#
# Override with INSTANCE=..., MOONRAKER_PORT=..., PAGE_PORT=...
datadir=$(dirname "$conf")
inst="${INSTANCE:-}"
if [ -z "$inst" ]; then
    case "$(basename "$datadir")" in
        printer_data) ;;
        printer_*_data) inst=$(basename "$datadir"); inst=${inst#printer_}; inst=${inst%_data} ;;
    esac
fi
case "$inst" in
    *[!A-Za-z0-9_-]*) echo "instance name '$inst' has characters other than letters, digits, - and _ - set INSTANCE=..."; exit 1 ;;
esac
suf=""
[ -n "$inst" ] && suf="-$inst"
name="vrtx$suf"
msvc="moonraker$suf"
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
if [ -n "$PAGE_PORT" ]; then
    pport="$PAGE_PORT"
elif [ -z "$inst" ]; then
    pport=8099
elif [ "$mport" -gt 7125 ] && [ "$mport" -lt 7225 ]; then
    pport=$((8099 + mport - 7125))
else
    pport=8199
fi
