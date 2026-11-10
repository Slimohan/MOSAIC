<p align="center">
  <img alt="MOSAIC" src="assets/mosaic-logo.png" width="420">
</p>

# MOSAIC: Multi-Tool Offset Alignment & Integrated Calibration

One package for the tools of a tool changer on Klipper and Kalico: calibration, tool control and docking.
Every nozzle touches a small probe, the macros turn the touch points into the X, Y and Z offsets of each tool,
and you do nothing in between. The same package gives you the `T0` ... `T9` commands, the dock pick-up and
drop-off moves, and one web page to control it all.

It works with any tool changer that runs on **klipper-toolchanger** (Viesturz), such as MadMax (Zruncho), on
stock Klipper or Kalico. It does not depend on MadMax itself, only on klipper-toolchanger's tools and tool parameters.

- **XY and Z, automatic:** a [Nudge](https://github.com/zruncho3d/nudge) probe (a mechanical contact probe,
  about 10 dollars) sits on the bed. `MOSAIC_CALIBRATE` mounts every tool in turn, touches the Nudge from four
  sides and from above, and saves the offsets. The probing itself is klipper-toolchanger's `[tools_calibrate]`
  module; MOSAIC runs it for all tools, adds up the offsets and saves them.
- **Z with a separate switch (optional):** the Nudge is very repeatable in X and Y but less so in Z. If you
  want the best Z, add a plain switch that every nozzle presses from above (`[mosaic_z_probe]`) and MOSAIC
  takes Z from it.
- **Tools (optional):** RatOS style `T0` ... `T9` commands and a Tools page for changers with several tools,
  including hotend swappers where every tool has its own heater and fan.
- **Docking (optional):** pick-up and drop-off for passive (Maxwell / kinematic) couplings, with a position and
  path per dock, a teach command, and checks of a carriage switch and one switch per dock around every change.
  Leave it out if your changer brings its own dock macros. Details in [docs/docking.md](docs/docking.md).

An earlier version of this package aligned the nozzles by eye with a camera. That is gone: the Nudge does it
without anyone watching, so the camera, the LED ring and the alignment page were removed.

## Screenshots

<p align="center">
  <img alt="MOSAIC Tools page with ten tool cards and the calibration buttons" src="assets/screenshots/tools.png" width="760">
</p>

One card per tool with temperature, standby, fan, offsets, mount, dock and calibrate, and the calibration
buttons below.

<p align="center">
  <img alt="MOSAIC page on a phone" src="assets/screenshots/tools-phone.png" width="300">
</p>

The same page on a phone.

These screenshots show the real page running against a simulated printer: the temperatures and offsets are
made-up demo data, not a real machine.

## What is in the package

| File | What it does |
|---|---|
| `mosaic.cfg` | The calibration macros. |
| `mosaic_tools.cfg` | Optional. `T0` ... `T9`, per tool temperature commands, standby handling. |
| `mosaic_tool_heaters.cfg` | Optional. `M104` / `M109` with a `T` parameter for slicers. |
| `mosaic_dock.cfg` | Optional. The dock pick-up / drop-off engine. You do not edit it. |
| `examples/mosaic_dock_positions.cfg` | Template for your dock positions. `install.sh` copies it next to `printer.cfg`. |
| `docs/` | The docking guide and examples of dock layouts. |
| `klippy_extras/mosaic_z_probe.py` | Optional Klipper module for the separate Z switch. Works next to Beacon, Cartographer or any probe. |
| `ui/` | Optional web page: heaters, fans, mount, offsets and the calibration buttons. |
| `assets/` | The logo, the hexagon emblem alone, and a 1280x640 social preview image (PNG). |
| `examples/` | Hardware sections, a `printer.cfg` example and the Mainsail menu entry. |
| `install.sh` | Creates your dock positions file and links the Z switch module into Klipper and Kalico. |

## Requirements

- Klipper or Kalico with **klipper-toolchanger** working (tools defined with `[tool T0]`, `[tool T1]`, ...), and its
  `tools_calibrate` module (it is part of klipper-toolchanger; Kalico ships its own copy).
  For the default offset method you need klipper-toolchanger **2025.12.26 or newer**
  (offsets as the tool parameters `gcode_x_offset`, `gcode_y_offset`, `gcode_z_offset`).
- A `[save_variables]` section.
- A **Nudge probe** on the bed, wired to a free endstop pin. Every nozzle must be able to reach it, and it must
  sit rigid: bolted to the bed frame or the printer, not on a flexing plate.
  Nudge needs about 6 mm of overtravel for the pin to wobble.
- Optional: a switch for Z.

## Installation

1. Put this folder in your config folder as `mosaic`: `cd ~/printer_data/config && git clone https://github.com/Slimohan/MOSAIC mosaic`.
2. Run `./install.sh`. It creates `mosaic_dock_positions.cfg` next to `printer.cfg` (never overwriting yours) and links
   the Z switch module (only needed with a separate Z switch; it looks in `~/klipper` and `~/kalico`, pass a path if
   yours differs).
3. Add to `printer.cfg`:
   ```
   [include mosaic/mosaic.cfg]
   [include mosaic/examples/mosaic_hardware.cfg]
   [include mosaic/mosaic_tools.cfg]          # optional, BEFORE the [tool Tn] sections
   [include mosaic/mosaic_dock.cfg]           # optional, docking
   [include mosaic_dock_positions.cfg]        # with docking: your dock positions
   ```
   Then edit the hardware file: the Nudge pin and, if you have one, the Z switch. With docking, also add the
   `pickup_gcode` / `dropoff_gcode` hooks to `[toolchanger]` and the switch sections, see
   `examples/printer.cfg.example` and [docs/docking.md](docs/docking.md).
4. Add a `[gcode_macro _MOSAIC_SETTINGS]` section **after** the include with at least `nudge_x`, `nudge_y` and
   `nudge_z` (see "Setup, once"). List only the variables you want to change (see `examples/printer.cfg.example`). Every
   setting is explained in `mosaic.cfg`.
5. Restart Klipper and run `MOSAIC_CHECK`.

## Setup, once

1. **Test the Nudge by hand.** Run `MOSAIC_NUDGE_QUERY` with the pin at rest: it must say `open`. Push the pin
   aside with a finger: `TRIGGERED`. If it is the other way round, add or remove the `!` in front of the pin.
2. **Find the position.** Home, mount the reference tool (T0) and move the nozzle above the middle of the Nudge
   pin, a few millimetres above the top of the pin. Write down the G-code X, Y and Z. They go into
   `nudge_x`, `nudge_y`, `nudge_z`. 1 to 2 mm off in X and Y is fine: the probing finds the centre itself. Z
   has to be higher than the pin plus the `lift_z` of `[tools_calibrate]` (1 mm by default).
3. **Check the other tools can reach it.** `SELECT_TOOL T=1`, `G1 X.. Y.. Z..` to the same numbers; the nozzle should be
   over the pin, not further than about 1 to 2 mm off. If a tool is further off than that (you have never
   calibrated it), correct it by hand: put a rough offset into `gcode_x_offset` / `gcode_y_offset` of the tool, or use
   `SET_TOOL_PARAMETER` once, then run the calibration.
4. **Run it.** `MOSAIC_CALIBRATE`. Watch the first run with a hand near the emergency stop. The console prints
   the offset of every tool.
5. **Check it.** Print a small test of two tools side by side, or touch the same spot with two tools using
   `G1` and compare. Do this at least once before you trust the numbers; see "Sign convention" below.

**Z minimum:** with a separate Z switch the nozzle has to be able to travel a few millimetres below the switch
height. If the switch sits close to Z 0, set `position_min` of `[stepper_z]` to a negative value, or the probing
move stops with "Move out of range".

## Tool commands and multi tool printers

Up to ten tools are supported: `T0` ... `T9`. The MOSAIC macros loop over whatever klipper-toolchanger
reports, so the calibration works with every configured tool; the ten comes from the
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

## Docking

Every tool change goes through klipper-toolchanger's `SELECT_TOOL` (and `UNSELECT_TOOL` for the Dock button), and
klipper-toolchanger runs the docking motion from the `pickup_gcode` and `dropoff_gcode` hooks. Options you put in
`[toolchanger]` are the defaults for all tools, and an option that is present but empty in a tool section overrides that
default.

MOSAIC brings its own dock macros for passive couplings (`mosaic_dock.cfg`): set the hooks in `[toolchanger]` to
`MOSAIC_DOCK_PICKUP` / `MOSAIC_DOCK_DROPOFF`, teach the docks, done. Setup, paths, switches and commands are in
[docs/docking.md](docs/docking.md). If your changer has its own dock macros (an actuated lock, for instance), leave
`mosaic_dock.cfg` out and point the hooks at those.

`MOSAIC_CHECK` prints a `WARN` line for every tool that has no `pickup_gcode` or `dropoff_gcode`, and runs
`MOSAIC_DOCK_CHECK` at the end when the dock macros are included. Without the hooks a tool change only switches
klipper-toolchanger's state and the toolhead does not move to the dock.

What the MOSAIC macros assume, so your dock macros and settings have to fit:

- **Every calibration step uses the dock macros.** `MOSAIC_CALIBRATE` mounts the reference tool, then every other
  tool in turn, and finally puts the tool back that was mounted when it started. With ten tools that is ten pickup and
  dropoff cycles, so test the docking on its own first.
- **After a tool change the tool is mounted and the toolhead is clear of the dock.** MOSAIC then raises to `safe_z`
  and travels to the Nudge probe or the switch.
- **`safe_z` must clear everything on the way**: the docks, the tools that are parked, the Nudge and the
  switch. It is a setting in `_MOSAIC_SETTINGS`. Start high.
- **Home first.** The macros need homed axes, as the docking does.
- **Errors reset the mounted tool.** A failed pickup or dropoff makes klipper-toolchanger forget which tool is
  mounted. After a failure, fix it by hand and run `INITIALIZE_TOOLCHANGER` before continuing.

A sensible first test order on the printer: `G28`, `SELECT_TOOL T=0`, `SELECT_TOOL T=1`, `SELECT_TOOL T=0`
(watch the dock each time), then `MOSAIC_CHECK`, and only then `MOSAIC_CALIBRATE`.

## Commands

| Command | Meaning |
|---|---|
| `MOSAIC_CALIBRATE [TOOL=n] [XY=0] [Z=0] [TEMP=]` | Measure the offsets of all tools (or one). `XY=0` or `Z=0` leaves an axis out. `TEMP` heats each nozzle to that temperature (C) for the measurement, 0 = cold. |
| `MOSAIC_CALIBRATE_XY`, `MOSAIC_CALIBRATE_Z` | Shortcuts for `XY=1 Z=0` and `XY=0 Z=1`. |
| `MOSAIC_AUTO_Z_OFFSET [TEMP=]` | Same as `MOSAIC_CALIBRATE_Z`, meant for `PRINT_START` after homing. |
| `MOSAIC_NUDGE_QUERY` | Is the Nudge probe triggered? For testing the wiring. |
| `MOSAIC_ECHO_OFFSETS`, `MOSAIC_RESET_OFFSETS [T=]`, `MOSAIC_APPLY_OFFSETS`, `MOSAIC_CHECK` | Utilities. `MOSAIC_CHECK` also checks the heater of every tool, that `T0` ... `T9` are the MOSAIC macros, warns about tools without `pickup_gcode` or `dropoff_gcode`, and runs `MOSAIC_DOCK_CHECK` when docking is included. |
| `MOSAIC_DOCK_PICKUP`, `MOSAIC_DOCK_DROPOFF`, `MOSAIC_DOCK_TEACH`, `MOSAIC_DOCK_GOTO`, ... | Docking, see the command list in [docs/docking.md](docs/docking.md#commands). |
| `MOSAIC_Z_QUERY`, `MOSAIC_Z_PROBE`, `MOSAIC_Z_PROBE_ACCURACY` | The Z switch module (only with `[mosaic_z_probe]`). Use the last one to check its repeatability. |

Wrong input (a missing tool, an unset position, axes not homed) only prints a warning and does nothing. That is
deliberate: klipper-toolchanger forgets the mounted tool after any G-code error. Errors from the probing itself
(for instance the nozzle is not over the pin) are real G-code errors; see "If a calibration stops half way".

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

## How the offsets are calculated

The reference tool (T0 by default) is measured first and is the zero point. Every other tool is measured the
same way, and the difference to the reference becomes its offset:

`offset = reference offset + (position of this tool at the probe - position of the reference tool at the probe)`

The reference offset is normally 0. The result is checked against `max_offset` (10 mm by default). A larger value
is not saved and a warning explains why: it means the wrong spot was probed or a tool is not seated.

**Z source.** `z_source: 'auto'` takes the separate Z switch if `[mosaic_z_probe]` exists and `z_switch_x` /
`z_switch_y` are set, otherwise the Nudge. `'nudge'` or `'switch'` forces one. With the switch, each tool does a
fast search from `safe_z`, lifts, then measures with the samples set in `[mosaic_z_probe]`. A warning appears when the
samples spread more than `z_range_warning` (0.02 mm by default); clean the nozzle and the switch then.

**Hot or cold.** `TEMP=150` (or `cal_temp`) heats each nozzle before it is measured, so the thermal expansion of
each hotend is included, and gives every heater its earlier target back afterwards. A hot nozzle must be clean:
leftover filament changes the touch point. 150 C is enough to soften filament; a clean cold nozzle is also fine.
Whichever you choose, use the same for every calibration and let the printer be at its normal temperature.

**Sign convention.** A tool offset is added to G-code coordinates to get machine coordinates, the same as in
klipper-toolchanger. If a tool prints to the wrong side after the first calibration, the offset is applied the other
way round on your set-up; check this once with two tools touching the same spot before you rely on it. The r2pdx
MadMax calibration macros use the same variable names. Do not let two offset tools write the offsets of the
same tool at the same time.

## If a calibration stops half way

If the probing fails (the nozzle is not above the pin, the Nudge does not trigger, a tool cannot be mounted), the
G-code stops with an error. Then:

- Heaters stay at the calibration temperature if you used `TEMP`. Run `MOSAIC_TOOLS_OFF` or set them yourself.
- A nozzle can be standing over the Nudge. Raise Z before you move sideways.
- If klipper-toolchanger lost track of the tool, fix it by hand and run `INITIALIZE_TOOLCHANGER`.
- Offsets of tools that were already finished are saved; the others keep their old values.

## The web page

The page works on a phone or a computer, and needs only the Python that is already on the printer.

1. Copy `ui/mosaic-ui.service` to `/etc/systemd/system/`, fix the user and the path inside, then
   `sudo systemctl enable --now mosaic-ui`.
2. Open `http://<printer-address>:8099`.

One card per tool, up to ten: mounted or docked, current and target temperature with a
state (off, heating, ready, cooling), a field and buttons to set the temperature, put the tool on standby or
switch it off, a fan slider, the saved offsets, and Mount, Dock and Calibrate. The bar on top has All heaters off
and the tool list. The Calibration section has Calibrate all tools, X and Y only, Z only, an optional temperature,
the Nudge state, the set-up check and the saved offsets. Without `mosaic_tools.cfg` the buttons
fall back to `SELECT_TOOL` and `SET_TOOL_TEMPERATURE`.

The page can move the printer and heat tools, and the server has no login. Use it only on a trusted network.

### A link in Mainsail

Mainsail can show a menu entry that opens the page, but it cannot embed it: the entry is a link. Copy
`examples/mainsail/navi.json` to the `.theme` folder in your config folder (`~/printer_data/config/.theme/navi.json`,
create the folder if it does not exist), replace `YOUR-PRINTER-ADDRESS` with the address of the printer, and reload Mainsail.
If you already have a `navi.json`, add the entry to its list. Mainsail's documentation describes the
fields (`title`, `href`, `target`, `position`, `icon`); I could not check the exact folder on a running
Mainsail, so if the entry does not appear, look up "custom navigation" in the Mainsail docs for your version.
`target` `_self` opens the page in the same tab, `_blank` in a new one.

## Coming from the camera version

The camera, the LED ring, the Alignment page and the macros `MOSAIC_START`, `MOSAIC_LOAD_TOOL`, `MOSAIC_MOVE`,
`MOSAIC_SET_TOOL` and `MOSAIC_END` are gone, together with the settings `camera_x`, `camera_y`, `focus_z`, the LED
and camera cooling settings and the `x_offset` / `y_offset` of `[mosaic_z_probe]`. The saved tool offsets
(`t<N>_offset_x/y/z`) keep their names and stay valid. The old `mosaic_ref_x/y/z` variables are not used any more and can
be deleted from `variables.cfg`. Run `./install.sh` again.

## What was tested, and what was not

Tested, on Klipper and on Kalico, in batch mode with the real klipper-toolchanger and a three tool test config. The
`[tools_calibrate]` probing was replaced by a stand-in that models tools with known physical errors, so what is
verified is MOSAIC's own part: the order of the steps, the offset maths (also with offsets that were already saved),
single tool and XY / Z only runs, hot runs and heater restore, the Z switch route (with a stand-in switch that returns
known heights), `z_source` selection, the `max_offset` refusal, missing settings and wrong input, both offset methods,
`MOSAIC_CHECK`, and saving and loading the offsets. The web page was tested in a headless browser against a fake
Moonraker. The multi tool part (`T0` ... `T9`, standby, `M104` / `M109` with `T`) was tested on a ten tool config.
The dock macros were tested the same way when they were a separate package (planned moves, errors, simulated
switches); the combined package with the new `MOSAIC_CHECK` link and the new location of the positions file has not
been run in batch mode yet.

**Not tested: real hardware.** Batch mode has no Nudge, no switch that triggers and no moving printer. The stand-in
probe has the sign convention that I read from the klipper-toolchanger code; whether the offsets come out with the
right sign on a real printer needs the check described under "Sign convention". Waiting for temperatures
(`WAIT=1`) cannot be checked in batch mode, fan speeds could not be read back, and the Mainsail menu entry was not tried
in a real Mainsail. Nothing was tried on a real tool changer.

The first run needs care: keep a hand near the emergency stop, start with `safe_z` generously high, check the Nudge
and switch positions at low speed, and run `MOSAIC_Z_PROBE_ACCURACY` before you trust the Z values from a switch.
Nudge's own documentation says Z is less repeatable than X and Y; if your Z offsets vary from run to run, add the
separate switch. Please report anything odd.

## Licence and credits

GPL-3.0, see `LICENSE`. The Z switch module is based on the probe code of Klipper (Kevin O'Connor) and RatOS
(Helge Keck and the RatOS contributors). The probing uses the `tools_calibrate` module of klipper-toolchanger by
Viesturz, with the Nudge probe by Zruncho. Works with the MadMax tool changer by Zruncho. This package is not
affiliated with RatRig, RatOS, Viesturz or Zruncho.
