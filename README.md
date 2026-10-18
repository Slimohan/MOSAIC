<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/mosaic-logo-dark.svg">
    <img alt="MOSAIC" src="assets/mosaic-logo-light.svg" width="460">
  </picture>
</p>

# MOSAIC: Multi-Tool Offset Alignment & Integrated Calibration

For tool changers on Klipper and Kalico. The name was VAOC in earlier versions of this repository
(see "Coming from VAOC" below).

The RatRig VAOC aligns the nozzles of an IDEX printer with a camera that looks up at the nozzle, and
measures the height of each nozzle on a small switch next to it. MOSAIC brings the same idea to
any tool changer that runs on **klipper-toolchanger** (Viesturz), such as MadMax (Zruncho), on stock Klipper
or Kalico. It does not depend on MadMax itself, only on klipper-toolchanger's tools and tool parameters.

- **XY:** you centre every nozzle in a crosshair (web page or console). The macros turn that into the
  X and Y offset of each tool.
- **Z:** each nozzle presses a switch. The macros turn the trigger heights into the Z offset of each tool.
- **Tools (optional):** RatOS style `T0` ... `T9` commands and a Tools page for changers with several tools,
  including hotend swappers where every tool has its own heater and fan.

MOSAIC is based on the VAOC macros of RatOS and the probe code of Klipper. It is **not** automatic nozzle
detection: like the RatOS VAOC, you do the centring by eye (a few clicks per tool).

## What is in the package

| File | What it does |
|---|---|
| `mosaic.cfg` | The alignment and calibration macros. |
| `mosaic_tools.cfg` | Optional. `T0` ... `T9`, per tool temperature commands, standby handling. |
| `mosaic_tool_heaters.cfg` | Optional. `M104` / `M109` with a `T` parameter for slicers. |
| `klippy_extras/mosaic_z_probe.py` | Klipper module for the Z switch. Works next to Beacon, Cartographer or any probe. |
| `ui/` | Optional web page: a Tools tab (heaters, fans, mount, offsets) and an Alignment tab (camera, crosshair, arrows). |
| `assets/` | The logo (SVG and PNG, light and dark), and a 1280x640 social preview image. |
| `examples/` | Hardware sections, a `printer.cfg` example and the Mainsail menu entry. |
| `install.sh` | Links the module into Klipper and Kalico. |

## Requirements

- Klipper or Kalico with **klipper-toolchanger** working (tools defined with `[tool T0]`, `[tool T1]`, ...).
  For the default offset method you need klipper-toolchanger **2025.12.26 or newer**
  (offsets as the tool parameters `gcode_x_offset`, `gcode_y_offset`, `gcode_z_offset`).
- A `[save_variables]` section.
- A camera under the nozzle path, with a Z switch beside it. A webcam in Moonraker works for the page.
- Optional: an LED ring (`[neopixel mosaic_led]`) and a fan.

## Installation

1. Put this folder in your config folder as `mosaic`: `cd ~/printer_data/config && git clone https://github.com/Slimohan/klipper-mosaic mosaic`.
2. Install the switch module: `./install.sh` (it looks in `~/klipper` and `~/kalico`; pass a path if yours differs).
3. Add to `printer.cfg`:
   ```
   [include mosaic/mosaic.cfg]
   [include mosaic/examples/mosaic_hardware.cfg]
   ```
   Then edit the hardware file: switch pin, `x_offset` / `y_offset` (switch centre relative to the camera
   centre), LED and fan pins. Skip what you do not have.
4. To change settings, add a `[gcode_macro _MOSAIC_SETTINGS]` section **after** the include and list only the
   variables you want to change (see `examples/printer.cfg.example`). Every setting is explained in
   `mosaic.cfg`.
5. Restart Klipper and run `MOSAIC_CHECK`.

**Z minimum:** the nozzle has to be able to travel a few millimetres below the switch height. If the
switch sits close to Z 0, set `position_min` of `[stepper_z]` to a negative value, or the probing move
stops with "Move out of range".

## Setup, once

1. Home all axes. Run `MOSAIC_START`. The reference tool (T0) moves over the camera.
2. Set `camera_x`, `camera_y` and `focus_z` in `_MOSAIC_SETTINGS` if the first position is far off, then run
   `MOSAIC_START` again after `MOSAIC_END`. The camera position and focus height are saved when you save the
   reference tool, so they only need to be roughly right.
3. Centre the T0 nozzle in the crosshair with `MOSAIC_MOVE X=.. Y=.. Z=..` (or the web page). Each command
   moves at most 2 mm in XY and 1 mm in Z. Run `MOSAIC_SET_TOOL`. This is the camera reference.
4. For every other tool: `MOSAIC_LOAD_TOOL T=1`, centre, `MOSAIC_SET_TOOL`.
5. Run `MOSAIC_CALIBRATE_Z`. Every tool presses the switch and gets its Z offset. `MOSAIC_END` finishes.

Do the Z measurement once XY is saved, because the switch position is relative to the camera reference.

## Tool commands and multi tool printers

Up to ten tools are supported: `T0` ... `T9`. The MOSAIC macros loop over whatever klipper-toolchanger
reports, so the alignment and the Z measurement work with every configured tool; the ten comes from the
`T0` ... `T9` macros (add more by copying one) and the ten saved-temperature variables of the standby handling.

### A hotend swapper with one extruder

klipper-toolchanger does not need one `[extruder]` per tool. A tool can have its own heater next to a shared
extruder. Give every tool a `heater:` (a `[heater_generic ...]` or an `[extruder...]` section) and a `fan:`
(a `[fan_generic ...]`), and leave out `extruder:`:

```
[heater_generic hotend0]
heater_pin: ...
sensor_type: ...
sensor_pin: ...
control: pid
...
[fan_generic fan0]
pin: ...

[tool T0]
tool_number: 0
heater: heater_generic hotend0
fan: fan_generic fan0
```

Things to know for this layout:

- **Cold extrusion check.** Klipper checks `min_extrude_temp` against the heater of the one `[extruder]` section.
  Klipper cannot take that check from a `heater_generic`, so with the heaters on the tools the `[extruder]`
  heater has to be something real or `min_extrude_temp` has to be `0`. In the second case Klipper does not
  stop a cold extrusion any more, so keep the temperature handling in your own macros or the slicer. I have
  not tried this on your board; decide it with your hardware in mind.
- **M104 / M109.** Klipper's own `M104` and `M109` only know the `[extruder]` heater, and
  klipper-toolchanger does not wrap them. Slicer lines like `M104 T1 S220` therefore do nothing for a
  `heater_generic` tool. Include `mosaic_tool_heaters.cfg` (see below) or let the slicer use
  `SET_TOOL_TEMPERATURE T=1 TARGET=220` through its custom G-code.
- **Fans.** `M106 S.. T..` and `M107 T..` are handled by klipper-toolchanger (its fan switcher) and need
  `fan:` on the tool. Do not define a `[fan]` section next to tool fans; klipper-toolchanger refuses that.
- **Beacon macros.** The thermal expansion offset of the Beacon macro set follows the `[extruder]` named in
  `_BEACON_SETTINGS`, not the heater of the mounted tool. It is not correct for a `heater_generic` hotend.

### The T commands

```
[include mosaic/mosaic.cfg]
[include mosaic/mosaic_tools.cfg]      # BEFORE the [tool Tn] sections
```

The include order matters. klipper-toolchanger registers its own `T0` ... `T9` for every tool and does
not replace a macro that already exists, so the macros must be loaded first. If you put them after the
tools, Klipper stops with `gcode command T0 already registered`.

| Command | Meaning |
|---|---|
| `T0` ... `T9` | Mount the tool (`SELECT_TOOL`), apply its saved offset in `gcode_offset` mode, and run the standby handling. Does nothing when that tool is already mounted. An unconfigured tool prints a warning; it does not raise an error, because any G-code error makes klipper-toolchanger forget the mounted tool. |
| `MOSAIC_SET_TEMP [T=] TARGET= [WAIT=1]` | Set the temperature of a tool (default: the mounted one). |
| `MOSAIC_TOOL_STANDBY [T=]` | Set the tool to `standby_temp` and remember its temperature. |
| `MOSAIC_TOOLS_OFF` | All tool heaters off. |
| `MOSAIC_TOOLS_STATUS` | One console line per tool: mounted or docked, temperature, target. |

`_MOSAIC_TOOLS_SETTINGS` has two settings: `standby_mode` and `standby_temp`. With `standby_mode: 'off'`
(default) a tool change does not touch any heater, which is right when the slicer sends its own standby
temperatures. With `'standby'` the tool that is put away goes to `standby_temp` (0 = off), and it returns
to its earlier temperature when it is mounted again (`wait_on_select` waits for it). Only a tool that is still at
`standby_temp` is restored, so a heater you switched off yourself stays off. For this to work change
temperatures with `M104 T..`, `MOSAIC_SET_TEMP`, or the page; raw `SET_TOOL_TEMPERATURE` bypasses the memory.

Like RatOS, every `T<n>` macro has an `active` variable that is `True` for the mounted tool. The state
of klipper-toolchanger (`printer.toolchanger.tool_number`) is the real source; `active` is only for
frontends that read it.

The RatOS `T0`/`T1` macros are written for IDEX (parking positions, the second carriage), so only the
idea carries over to a tool changer: a `T` command per tool, state variables, standby temperatures.

### M104 and M109 with T

`mosaic_tool_heaters.cfg` wraps `M104` and `M109` so `T` selects the tool and no `T` means the mounted tool. Without
a mounted tool and without `T` the original command runs. `M109` waits for the tool it names; it does not
mount it. Do not include it together with `beacon_heater_hooks.cfg`: both define the macros `M104` and `M109`,
Klipper does not complain but merges them, and the file included last silently wins (I tried it). This file calls the
Beacon offset update itself when the Beacon macros are loaded, so leave the Beacon hooks file out.

## Commands

| Command | Meaning |
|---|---|
| `MOSAIC_START [RESET=1]` | Start a session. `RESET=1` zeroes the offsets of the other tools first. |
| `MOSAIC_LOAD_TOOL T=n` | Mount tool n and move it over the camera. |
| `MOSAIC_MOVE X= Y= Z=` | Small relative move. |
| `MOSAIC_SET_TOOL` | Save the mounted tool (T0: camera reference, others: XY offsets). |
| `MOSAIC_END` | Finish, mount the reference tool, LED off. |
| `MOSAIC_CALIBRATE_Z [TEMP=]` | Measure the Z offset of all tools on the switch. |
| `MOSAIC_AUTO_Z_OFFSET [TEMP=]` | Same, meant for `PRINT_START` after homing. |
| `MOSAIC_ECHO_OFFSETS`, `MOSAIC_RESET_OFFSETS [T=]`, `MOSAIC_APPLY_OFFSETS`, `MOSAIC_CHECK` | Utilities. `MOSAIC_CHECK` also checks the heater of every tool and that `T0` ... `T9` are the MOSAIC macros. |
| `MOSAIC_Z_QUERY`, `MOSAIC_Z_PROBE`, `MOSAIC_Z_PROBE_ACCURACY` | The switch module. Use the last one to check its repeatability. |

Wrong input (a move that is too large, no session, a missing tool) only prints a warning and does nothing.
That is deliberate: klipper-toolchanger forgets the mounted tool after any G-code error.

## Offset methods

`offset_method` in `_MOSAIC_SETTINGS` decides how the offsets reach Klipper. Both methods save the offsets
in `[save_variables]` as `t<N>_offset_x`, `t<N>_offset_y`, `t<N>_offset_z`.

- `tool_parameter` (default): the macros set `gcode_x_offset`, `gcode_y_offset`, `gcode_z_offset` on the
  tools. They are loaded from the saved variables two seconds after Klipper starts. Use this with a
  current klipper-toolchanger and a MadMax config that keeps its offsets in the tool sections.
- `gcode_offset`: for configs that apply offsets with `SET_GCODE_OFFSET` in their own tool change macros
  from the `t<N>_offset_x/y/z` variables (the r2pdx MadMax configs do this). The MOSAIC macros apply the
  saved offsets themselves while they work. Only the saved offsets are applied, nothing else your own
  macros add to Z.

Sign convention: a tool offset is added to G-code coordinates to get machine coordinates, the same as in
klipper-toolchanger. The r2pdx MadMax calibration macros use the same variable names. Do not let two offset tools write
the offsets of the same tool at the same time.

## Z measurement

All tools press the same switch. The reference tool gives the reference height, and every other tool
gets `Z offset = reference Z offset + (its trigger height - reference trigger height)`. Each tool does a
fast search, lifts, then measures with the samples set in `[mosaic_z_probe]`. A warning appears when the
samples spread more than `z_range_warning` (0.02 mm by default); clean the nozzle and the switch then.

`TEMP=200` (or `z_cal_temp`) heats each nozzle for the measurement, so the thermal expansion is
included, and restores the earlier heater targets afterwards. If a measurement fails in between,
the heaters stay where they are: check them.

## The web page

The page works on a phone or a computer, and needs only the Python that is already on the printer.

1. Copy `ui/mosaic-ui.service` to `/etc/systemd/system/`, fix the user and the path inside, then
   `sudo systemctl enable --now mosaic-ui`.
2. Open `http://<printer-address>:8099`.

**Tools tab.** One card per tool, up to ten: mounted or docked, current and target temperature with a
state (off, heating, ready, cooling), a field and buttons to set the temperature, put the tool on standby or
switch it off, a fan slider, the saved offsets, and Mount, Dock and Align. The bar on top has All heaters off,
the tool list, and Measure Z of all tools with an optional temperature. Without `mosaic_tools.cfg` the buttons
fall back to `SELECT_TOOL` and `SET_TOOL_TEMPERATURE`. Align starts a session if none is running, mounts that tool over
the camera and opens the Alignment tab.

**Alignment tab.**

1. Choose your camera in Moonraker's webcam settings (a webcam named with "mosaic", "vaoc", "nozzle" or "under" is
   preferred), or type the stream URL into the page.
2. Arrow keys and Page Up / Page Down also move. Enter pixels per mm to click on the picture to centre.

The page can move the printer and heat tools, and the server has no login. Use it only on a trusted network.

### A link in Mainsail

Mainsail can show a menu entry that opens the page, but it cannot embed it: the entry is a link. Copy
`examples/mainsail/navi.json` to the `.theme` folder in your config folder (`~/printer_data/config/.theme/navi.json`,
create the folder if it does not exist), replace `YOUR-PRINTER-ADDRESS` with the address of the printer, and reload Mainsail.
If you already have a `navi.json`, add the entry to its list. Mainsail's documentation describes the
fields (`title`, `href`, `target`, `position`, `icon`); I could not check the exact folder on a running
Mainsail, so if the entry does not appear, look up "custom navigation" in the Mainsail docs for your version.
`target` `_self` opens the page in the same tab, `_blank` in a new one.

## Coming from VAOC

Everything that was called `vaoc` is now `mosaic`. If you installed an earlier version:

| Before | Now |
|---|---|
| `VAOC_START`, `VAOC_SET_TOOL`, `VAOC_CALIBRATE_Z`, ... | `MOSAIC_START`, `MOSAIC_SET_TOOL`, `MOSAIC_CALIBRATE_Z`, ... (same names, new prefix) |
| `[include vaoc/vaoc.cfg]`, `vaoc_tools.cfg`, `vaoc_tool_heaters.cfg` | `[include mosaic/mosaic.cfg]`, `mosaic_tools.cfg`, `mosaic_tool_heaters.cfg` |
| `[vaoc_z_probe]`, `VAOC_Z_PROBE`, `VAOC_Z_QUERY` | `[mosaic_z_probe]`, `MOSAIC_Z_PROBE`, `MOSAIC_Z_QUERY` |
| `[gcode_macro _VAOC_SETTINGS]` and `variable_...` | `[gcode_macro _MOSAIC_SETTINGS]`, the variables keep their names |
| `[neopixel vaoc_led]` | `[neopixel mosaic_led]` |
| folder `vaoc`, service `vaoc-ui` | folder `mosaic`, service `mosaic-ui` |
| saved variables `vaoc_ref_x/y/z` | `mosaic_ref_x/y/z` |

The saved tool offsets (`t<N>_offset_x/y/z`) keep their names and stay valid. The camera reference is stored under the new
name, so run `MOSAIC_START`, centre the reference tool and `MOSAIC_SET_TOOL` once more (or rename the three
variables in your `variables.cfg`). Run `./install.sh` again; it removes the old `vaoc_z_probe.py` link.

## What was tested, and what was not

Tested, on Klipper and on Kalico, in batch mode with the real klipper-toolchanger and a three tool test
config (the alignment and Z parts): the whole XY session, the offset maths in both methods, the Z calibration (with a stand-in for
the switch that returns known heights), heater restore, loading the saved offsets, error handling,
`mosaic_z_probe` loading and issuing its probing moves, and the page's server and buttons against a fake
Moonraker.

After the rename to MOSAIC the alignment, Z and multi tool tests were run again on Klipper and Kalico with the new names.

Tested for the multi tool part, on Klipper and on Kalico, in batch mode with the real klipper-toolchanger and a
ten tool config (`heater_generic` hotend and `fan_generic` fan per tool, one extruder): `T0` ... `T9`, the
warning for an unconfigured tool, a repeated `T` command, `MOSAIC_SET_TEMP`, standby and restore, `MOSAIC_TOOLS_OFF`,
`M104` / `M109` with `T`, `M106 T`, the `active` variable, `MOSAIC_CHECK`, and the refusal of the wrong include order.
The page was tested in a headless browser against a fake Moonraker with ten tools: every button sends the expected
command, phone width, and the fallback without `mosaic_tools.cfg`.

**Not tested:** waiting for a temperature (`WAIT=1`, `wait_on_select`) cannot be checked in batch mode, fan speeds
could not be read back in the test rig, and the Mainsail menu entry was not tried in a real Mainsail.
Nothing was tried on a real tool changer, and the page was never used with a real camera.
Ten tools are tested only as a config that loads and answers commands, no tool was physically swapped.

**Not tested: real hardware.** Batch mode has no camera, no switch that triggers and no moving printer.
The first run needs care: keep a hand near the emergency stop, start with `safe_z` generously high, check
the camera position and the switch position at low speed, and run `MOSAIC_Z_PROBE_ACCURACY` before you trust
the Z values. Please report anything odd.

## Licence and credits

GPL-3.0, see `LICENSE`. Based on the VAOC code of RatOS (Helge Keck and the RatOS contributors) and
the probe code of Klipper (Kevin O'Connor). Works with klipper-toolchanger by Viesturz and the MadMax
tool changer by Zruncho. VAOC is the name of a RatRig feature; this package is not affiliated with RatRig,
RatOS, Viesturz or Zruncho.
