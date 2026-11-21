#!/usr/bin/env python3
"""Loads every vrtx.cfg the installer can build into real Klipper, with klipper-toolchanger.

    tests/klipper_check.py --klipper ~/klipper --toolchanger ~/klipper-toolchanger

For each combination of calibration method (nudge, camera), tool changer type (full, hotend)
and number of tools (1, 3, 10) it builds vrtx.cfg the way install.sh does, puts it in a
throwaway config folder next to a test printer.cfg, and runs Klipper in batch mode
(klippy.py -i ... -d klipper.dict). Klipper reads the whole config, sets up klipper-toolchanger
and runs VRTX_CHECK, exactly as it would on a printer, without a printer attached.

The test printer matches the tool changer type:
  full    every tool has its own extruder motor, heater, hotend fan and part fan
          (fan_generic tN_part_fan), as on a MadMax or StealthChanger
  hotend  a hotend swapper: one shared extruder motor ([extruder_stepper]), heater-only
          tools with their own hotend fan, and the part cooling fans as the printer's
          one [fan] on the carriage (two fans through a [multi_pin])

A combination passes when Klipper starts without a config error. For the hotend swapper the
test also checks that VRTX_CHECK reports the missing shared motor until variable_motor is set,
and that the [tool] sections have no fan line.

Needs: a Klipper checkout with its Linux MCU built once (out/klipper.dict; the script builds
it when missing), a klipper-toolchanger checkout, and Klipper's Python packages. It links the
klipper-toolchanger modules and VRTX's Z switch module into that Klipper checkout, as
install.sh does, so use a checkout made for testing.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(REPO, "config", "build_config.py")

BASE = """[mcu]
serial: /dev/null

[mcu toolbox]
serial: /dev/null

[printer]
kinematics: cartesian
max_velocity: 300
max_accel: 3000
max_z_velocity: 10
max_z_accel: 100

[stepper_x]
step_pin: gpio1
dir_pin: gpio2
enable_pin: !gpio3
microsteps: 16
rotation_distance: 40
endstop_pin: ^gpio4
position_endstop: 0
position_max: 300
homing_speed: 50

[stepper_y]
step_pin: gpio5
dir_pin: gpio6
enable_pin: !gpio7
microsteps: 16
rotation_distance: 40
endstop_pin: ^gpio8
position_endstop: 0
position_max: 300
homing_speed: 50

[stepper_z]
step_pin: gpio9
dir_pin: gpio10
enable_pin: !gpio11
microsteps: 16
rotation_distance: 8
endstop_pin: ^gpio12
position_endstop: 0
position_max: 250

# What every Mainsail / Fluidd printer has
[virtual_sdcard]
path: {tmp}/gcodes

[pause_resume]

[display_status]

[respond]

"""

HEATER = """heater_pin: {heater}
sensor_type: EPCOS 100K B57560G104F
sensor_pin: {sensor}
control: pid
pid_Kp: 22.2
pid_Ki: 1.08
pid_Kd: 114
min_temp: 0
max_temp: 300
min_extrude_temp: 170
nozzle_diameter: 0.4
filament_diameter: 1.75
"""


def tool_pins(n):
    """Heater, thermistor and fan pins of tool n (ADC: 8 per MCU)."""
    sensor = "analog%d" % n if n < 8 else "toolbox:analog%d" % (n - 8)
    return {"heater": "toolbox:gpio%d" % (20 + n), "sensor": sensor,
            "hotend_fan": "toolbox:gpio%d" % (40 + n), "part_fan": "toolbox:gpio%d" % (60 + n),
            "step": "toolbox:gpio%d" % (80 + 3 * n), "dir": "toolbox:gpio%d" % (81 + 3 * n),
            "enable": "!toolbox:gpio%d" % (82 + 3 * n)}


def board_file(changer, tools):
    """The test printer's own board file: what a user keeps next to printer.cfg."""
    out = []
    if changer == "hotend":
        out.append("""# Carriage: the shared extruder motor and the two part cooling fans as one [fan]
[extruder_stepper shared_drive]
extruder: extruder
step_pin: gpio20
dir_pin: gpio21
enable_pin: !gpio22
microsteps: 16
rotation_distance: 22.6

[multi_pin part_fans]
pins: gpio30, gpio31

[fan]
pin: multi_pin:part_fans
""")
    for n in range(tools):
        p = tool_pins(n)
        name = "extruder" if n == 0 else "extruder%d" % n
        out.append("[%s]" % name)
        if changer == "full":
            out.append("step_pin: %(step)s\ndir_pin: %(dir)s\nenable_pin: %(enable)s\n"
                       "microsteps: 16\nrotation_distance: 22.6" % p)
        out.append(HEATER.format(**p))
        out.append("[heater_fan t%d_hotend_fan]\npin: %s\nheater: %s\nheater_temp: 50.0\n"
                   % (n, p["hotend_fan"], name))
        if changer == "full":
            out.append("[fan_generic t%d_part_fan]\npin: %s\n" % (n, p["part_fan"]))
    return "\n".join(out) + "\n"


def ensure_dict(klipper):
    d = os.path.join(klipper, "out", "klipper.dict")
    if not os.path.exists(d):
        with open(os.path.join(klipper, ".config"), "w") as f:
            f.write("CONFIG_MACH_LINUX=y\n")
        subprocess.run(["make", "olddefconfig"], cwd=klipper, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["make", "-j4"], cwd=klipper, check=True, stdout=subprocess.DEVNULL)
    return d


def link_modules(klipper, toolchanger):
    extras = os.path.join(klipper, "klippy", "extras")
    srcs = [os.path.join(toolchanger, "klipper", "extras", f)
            for f in os.listdir(os.path.join(toolchanger, "klipper", "extras")) if f.endswith(".py")]
    srcs.append(os.path.join(REPO, "klippy_extras", "vrtx_z_probe.py"))
    for s in srcs:
        dst = os.path.join(extras, os.path.basename(s))
        if os.path.islink(dst) or not os.path.exists(dst):
            if os.path.lexists(dst):
                os.remove(dst)
            os.symlink(s, dst)


def run(klipper, kdict, changer, calibration, tools, motor):
    """Returns (ok, log text)."""
    tmp = tempfile.mkdtemp(prefix="vrtx-check-")
    try:
        os.makedirs(os.path.join(tmp, "VRTX"))
        os.symlink(REPO, os.path.join(tmp, "VRTX", "core"))
        cfg = os.path.join(tmp, "VRTX", "vrtx.cfg")
        subprocess.run([sys.executable, BUILD, "--calibration", calibration, "--changer", changer,
                        "--tools", str(tools), "-o", cfg], check=True)
        with open(cfg) as f:
            text = f.read()
        if changer == "hotend" and "\nfan: fan_generic" in text:
            return False, "hotend swapper: a [tool] section still has a fan line"
        # the test printer's pins and paths
        text = text.replace("pin: ^PF5", "pin: ^gpio50")
        text = text.replace("~/printer_data/config/variables.cfg", os.path.join(tmp, "variables.cfg"))
        if motor:
            text = text.replace("#variable_motor: 'shared_drive'", "variable_motor: 'shared_drive'")
        with open(cfg, "w") as f:
            f.write(text)
        with open(os.path.join(tmp, "my_tools.cfg"), "w") as f:
            f.write(board_file(changer, tools))
        with open(os.path.join(tmp, "printer.cfg"), "w") as f:
            f.write(BASE.replace("{tmp}", tmp) + "[include my_tools.cfg]\n[include VRTX/vrtx.cfg]\n")
        os.makedirs(os.path.join(tmp, "gcodes"))
        with open(os.path.join(tmp, "in.gcode"), "w") as f:
            f.write("VRTX_CHECK\n")
        log = os.path.join(tmp, "klippy.log")
        r = subprocess.run([sys.executable, os.path.join(klipper, "klippy", "klippy.py"),
                            os.path.join(tmp, "printer.cfg"), "-i", os.path.join(tmp, "in.gcode"),
                            "-o", os.path.join(tmp, "out.serial"), "-v",
                            "-d", kdict, "-d", "toolbox=" + kdict, "-l", log],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
        out = r.stdout + (open(log).read() if os.path.exists(log) else "")
        ok = r.returncode == 0 and "Config error" not in out and "Error loading" not in out
        if ok and changer == "hotend":
            # VRTX_CHECK's own output, not the macro text Klipper copies into its log
            said_missing = any("VRTX CHECK: FAIL  this is a hotend swapper" in l
                               and "action_respond_info" not in l for l in out.splitlines())
            if said_missing == bool(motor):
                ok = False
                out += "\nVRTX_CHECK %s the missing-motor FAIL" % ("gave" if motor else "did not give")
        return ok, out
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--klipper", required=True)
    ap.add_argument("--toolchanger", required=True)
    ap.add_argument("-v", "--verbose", action="store_true", help="print Klipper's log of failures")
    a = ap.parse_args()
    klipper, toolchanger = os.path.expanduser(a.klipper), os.path.expanduser(a.toolchanger)
    kdict = ensure_dict(klipper)
    link_modules(klipper, toolchanger)
    cases = [(c, m, n, motor) for c in ("full", "hotend") for m in ("nudge", "camera")
             for n in (1, 3, 10) for motor in ((False, True) if c == "hotend" else (False,))]
    failed = 0
    for changer, calibration, tools, motor in cases:
        ok, out = run(klipper, kdict, changer, calibration, tools, motor)
        label = "%-6s %-6s %2d tools%s" % (changer, calibration, tools,
                                            " (motor set)" if motor else "")
        print("%s  %s" % ("ok  " if ok else "FAIL", label))
        if not ok:
            failed += 1
            ol = out.splitlines()
            cut = max([i for i, l in enumerate(ol) if l.startswith("Config error")] or [0])
            lines = ol[cut:] if cut else [l for l in ol if "VRTX CHECK" in l or "FAIL" in l
                                          or "did not give" in l or "gave the" in l]
            print("\n".join("      " + l for l in (ol[-60:] if a.verbose else lines[-12:])))
    print("%d of %d combinations passed" % (len(cases) - failed, len(cases)))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
