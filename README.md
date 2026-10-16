# VAOC for tool changers (Klipper and Kalico)

The RatRig VAOC aligns the nozzles of an IDEX printer with a camera that looks up at the nozzle, and
measures the height of each nozzle on a small switch next to it. This package brings the same idea to
any tool changer that runs on **klipper-toolchanger** (Viesturz), such as MadMax (Zruncho), on stock Klipper
or Kalico. It does not depend on MadMax itself, only on klipper-toolchanger's tools and tool parameters.

- **XY:** you centre every nozzle in a crosshair (web page or console). The macros turn that into the
  X and Y offset of each tool.
- **Z:** each nozzle presses a switch. The macros turn the trigger heights into the Z offset of each tool.

It is based on the VAOC macros of RatOS and the probe code of Klipper. It is **not** automatic nozzle
detection: like the RatOS VAOC, you do the centring by eye (a few clicks per tool).

## What is in the package

| File | What it does |
|---|---|
| `vaoc.cfg` | All macros. |
| `klippy_extras/vaoc_z_probe.py` | Klipper module for the Z switch. Works next to Beacon, Cartographer or any probe. |
| `ui/` | Optional alignment web page with camera view, crosshair and arrow buttons. |
| `examples/` | Hardware sections and a `printer.cfg` example. |
| `install.sh` | Links the module into Klipper and Kalico. |

## Requirements

- Klipper or Kalico with **klipper-toolchanger** working (tools defined with `[tool T0]`, `[tool T1]`, ...).
  For the default offset method you need klipper-toolchanger **2025.12.26 or newer**
  (offsets as the tool parameters `gcode_x_offset`, `gcode_y_offset`, `gcode_z_offset`).
- A `[save_variables]` section.
- A camera under the nozzle path, with a Z switch beside it. A webcam in Moonraker works for the page.
- Optional: an LED ring (`[neopixel vaoc_led]`) and a fan.

## Installation

1. Put this folder in your config folder as `vaoc`: `cd ~/printer_data/config && git clone https://github.com/Slimohan/klipper-vaoc vaoc`.
2. Install the switch module: `./install.sh` (it looks in `~/klipper` and `~/kalico`; pass a path if yours differs).
3. Add to `printer.cfg`:
   ```
   [include vaoc/vaoc.cfg]
   [include vaoc/examples/vaoc_hardware.cfg]
   ```
   Then edit the hardware file: switch pin, `x_offset` / `y_offset` (switch centre relative to the camera
   centre), LED and fan pins. Skip what you do not have.
4. To change settings, add a `[gcode_macro _VAOC_SETTINGS]` section **after** the include and list only the
   variables you want to change (see `examples/printer.cfg.example`). Every setting is explained in
   `vaoc.cfg`.
5. Restart Klipper and run `VAOC_CHECK`.

**Z minimum:** the nozzle has to be able to travel a few millimetres below the switch height. If the
switch sits close to Z 0, set `position_min` of `[stepper_z]` to a negative value, or the probing move
stops with "Move out of range".

## Setup, once

1. Home all axes. Run `VAOC_START`. The reference tool (T0) moves over the camera.
2. Set `camera_x`, `camera_y` and `focus_z` in `_VAOC_SETTINGS` if the first position is far off, then run
   `VAOC_START` again after `VAOC_END`. The camera position and focus height are saved when you save the
   reference tool, so they only need to be roughly right.
3. Centre the T0 nozzle in the crosshair with `VAOC_MOVE X=.. Y=.. Z=..` (or the web page). Each command
   moves at most 2 mm in XY and 1 mm in Z. Run `VAOC_SET_TOOL`. This is the camera reference.
4. For every other tool: `VAOC_LOAD_TOOL T=1`, centre, `VAOC_SET_TOOL`.
5. Run `VAOC_CALIBRATE_Z`. Every tool presses the switch and gets its Z offset. `VAOC_END` finishes.

Do the Z measurement once XY is saved, because the switch position is relative to the camera reference.

## Commands

| Command | Meaning |
|---|---|
| `VAOC_START [RESET=1]` | Start a session. `RESET=1` zeroes the offsets of the other tools first. |
| `VAOC_LOAD_TOOL T=n` | Mount tool n and move it over the camera. |
| `VAOC_MOVE X= Y= Z=` | Small relative move. |
| `VAOC_SET_TOOL` | Save the mounted tool (T0: camera reference, others: XY offsets). |
| `VAOC_END` | Finish, mount the reference tool, LED off. |
| `VAOC_CALIBRATE_Z [TEMP=]` | Measure the Z offset of all tools on the switch. |
| `VAOC_AUTO_Z_OFFSET [TEMP=]` | Same, meant for `PRINT_START` after homing. |
| `VAOC_ECHO_OFFSETS`, `VAOC_RESET_OFFSETS [T=]`, `VAOC_APPLY_OFFSETS`, `VAOC_CHECK` | Utilities. |
| `VAOC_Z_QUERY`, `VAOC_Z_PROBE`, `VAOC_Z_PROBE_ACCURACY` | The switch module. Use the last one to check its repeatability. |

Wrong input (a move that is too large, no session, a missing tool) only prints a warning and does nothing.
That is deliberate: klipper-toolchanger forgets the mounted tool after any G-code error.

## Offset methods

`offset_method` in `_VAOC_SETTINGS` decides how the offsets reach Klipper. Both methods save the offsets
in `[save_variables]` as `t<N>_offset_x`, `t<N>_offset_y`, `t<N>_offset_z`.

- `tool_parameter` (default): the macros set `gcode_x_offset`, `gcode_y_offset`, `gcode_z_offset` on the
  tools. They are loaded from the saved variables two seconds after Klipper starts. Use this with a
  current klipper-toolchanger and a MadMax config that keeps its offsets in the tool sections.
- `gcode_offset`: for configs that apply offsets with `SET_GCODE_OFFSET` in their own tool change macros
  from the `t<N>_offset_x/y/z` variables (the r2pdx MadMax configs do this). The VAOC macros apply the
  saved offsets themselves while they work. Only the saved offsets are applied, nothing else your own
  macros add to Z.

Sign convention: a tool offset is added to G-code coordinates to get machine coordinates, the same as in
klipper-toolchanger. The r2pdx MadMax calibration macros use the same variable names. Do not let two offset tools write
the offsets of the same tool at the same time.

## Z measurement

All tools press the same switch. The reference tool gives the reference height, and every other tool
gets `Z offset = reference Z offset + (its trigger height - reference trigger height)`. Each tool does a
fast search, lifts, then measures with the samples set in `[vaoc_z_probe]`. A warning appears when the
samples spread more than `z_range_warning` (0.02 mm by default); clean the nozzle and the switch then.

`TEMP=200` (or `z_cal_temp`) heats each nozzle for the measurement, so the thermal expansion is
included, and restores the earlier heater targets afterwards. If a measurement fails in between,
the heaters stay where they are: check them.

## The alignment page

The page works on a phone or a computer, and needs only the Python that is already on the printer.

1. Copy `ui/vaoc-ui.service` to `/etc/systemd/system/`, fix the user and the path inside, then
   `sudo systemctl enable --now vaoc-ui`.
2. Open `http://<printer-address>:8099`.
3. Choose your camera in Moonraker's webcam settings (a webcam named with "vaoc", "nozzle" or "under" is
   preferred), or type the stream URL into the page.
4. Arrow keys and Page Up / Page Down also move. Enter pixels per mm to click on the picture to centre.

The page can move the printer, and the server has no login. Use it only on a trusted network.

## What was tested, and what was not

Tested, on Klipper and on Kalico, in batch mode with the real klipper-toolchanger and a three tool test
config: the whole XY session, the offset maths in both methods, the Z calibration (with a stand-in for
the switch that returns known heights), heater restore, loading the saved offsets, error handling,
`vaoc_z_probe` loading and issuing its probing moves, and the page's server and buttons against a fake
Moonraker.

**Not tested: real hardware.** Batch mode has no camera, no switch that triggers and no moving printer.
The first run needs care: keep a hand near the emergency stop, start with `safe_z` generously high, check
the camera position and the switch position at low speed, and run `VAOC_Z_PROBE_ACCURACY` before you trust
the Z values. Please report anything odd.

## Licence and credits

GPL-3.0, see `LICENSE`. Based on the VAOC code of RatOS (Helge Keck and the RatOS contributors) and
the probe code of Klipper (Kevin O'Connor). Works with klipper-toolchanger by Viesturz and the MadMax
tool changer by Zruncho; this package is not affiliated with any of them.
