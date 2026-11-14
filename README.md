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
- **Tools (optional):** `T0` ... `T9` commands and a Tools page for changers with several tools,
  including hotend swappers where every tool has its own heater and fan. Each tool shows the filament that is
  loaded (material, name, colour), has temperature buttons, and every tool change is timed and checked. While a
  print runs, the page compares the loaded filament with what the sliced file expects.
- **Docking (optional):** pick-up and drop-off for passive (Maxwell / kinematic) couplings, with a position and
  path per dock, a teach command, and checks of a carriage switch and one switch per dock around every change.
  Leave it out if your changer brings its own dock macros. Details in [docs/docking.md](docs/docking.md).

## Screenshots

<p align="center">
  <img alt="MOSAIC page with eight tool cards, the filament check and the tool change log" src="assets/screenshots/tools.png" width="760">
</p>

One card per tool with the loaded filament, temperature, temperature buttons, fan, offsets, mount, dock and
calibrate. On top, the filament check of the last file; below, the calibration buttons, the offsets and the tool
change log.

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
| `config/` | Templates for your MOSAIC folder: tools, hardware, dock positions, switches, settings. `install.sh` copies them once. |
| `docs/` | The docking guide and examples of dock layouts. |
| `klippy_extras/mosaic_z_probe.py` | Optional Klipper module for the separate Z switch. Works next to Beacon, Cartographer or any probe. |
| `ui/` | The web page (heaters, fans, mount, dock, offsets, calibration), its server, and the files `install.sh` uses to add it to Mainsail. |
| `assets/` | The logo, the hexagon emblem alone, and a 1280x640 social preview image (PNG). |
| `examples/mainsail/` | The Mainsail sidebar entry. |
| `install.sh` | Creates your MOSAIC folder, adds its one include line to `printer.cfg`, links the Z switch module, and sets up the web page with its Mainsail sidebar entry and update panel entry. |
| `uninstall.sh` | Undoes what `install.sh` set up. |

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
- For the sidebar entry and the update panel: Mainsail and Moonraker (the standard KIAUH or MainsailOS setup), and
  `sudo` rights for the installer.

## Installation

Everything MOSAIC lives in one folder, `MOSAIC`, in your Klipper config folder. `printer.cfg` gets a single line:

```
[include MOSAIC/mosaic.cfg]
```

**Before you start:** klipper-toolchanger has to be installed first, using its own installer. MOSAIC is built on it.

### 1. Get the files

On the printer's Pi or PC, over SSH, in your home folder (not in the config folder):

```
cd ~
git clone https://github.com/Slimohan/MOSAIC
```

### 2. Run the installer

```
cd MOSAIC
./install.sh
```

It does three things:

- **Creates your MOSAIC folder** (`~/printer_data/config/MOSAIC`) with your `mosaic.cfg`, and adds
  `[include MOSAIC/mosaic.cfg]` at the top of `printer.cfg` (a backup is kept as `printer.cfg.mosaic-backup`). It never
  overwrites a file of yours; if a template changed, the new one is saved beside yours with `.new` at the end.
- **Links the optional Z switch module** into `~/klipper` or `~/kalico`. You only need this if you add the separate Z
  switch. If your Klipper or Kalico is somewhere else, pass the path: `./install.sh /path/to/klipper`.
- **Sets up the MOSAIC page and adds it to Mainsail's sidebar.** After a reload of Mainsail there is a **MOSAIC**
  entry on the left, and clicking it opens the page where you control and calibrate the tools. The installer
  asks for your password (sudo) for this part. Details in "The web page" below; skip it with `NO_WEB=1 ./install.sh`.

If your config folder is not `~/printer_data/config`: `CONF=/path/to/config ./install.sh`.

### 3. Fill in `mosaic.cfg`

In Mainsail, open **Machine** and then the `MOSAIC` folder:

```
MOSAIC/
  mosaic.cfg   the one file you edit
  core/        MOSAIC itself, a link to ~/MOSAIC: never edit anything in here
```

`mosaic.cfg` has seven sections, from top to bottom:

1. **What to load**: MOSAIC itself; switch optional parts on or off here
2. **Settings**: at least the Nudge position
3. **Hardware**: the Nudge probe, the optional Z switch, `[save_variables]`
4. **Toolchanger**: the `[toolchanger]` section with the dock hooks
5. **Tools**: every tool with its `[tool Tn]`, heater, thermistor and fans
6. **Switches**: carriage and dock switches (optional)
7. **Dock positions**: where every dock is ([docs/docking.md](docs/docking.md))

The order matters: MOSAIC's T commands have to load before the tools, and your settings after MOSAIC. Move your
`[tool Tn]` sections, the heaters and fans of the tools, and your `[toolchanger]` options from `printer.cfg` into
sections 5 and 4. Each section explains what goes into it, and Klipper refuses to start while a section you switched
on still has `...` in it.

**Your own files** (a toolboard, say) can stay where they are, or go into the `MOSAIC` folder with an `[include]` line
of their own at the end of `mosaic.cfg`. Only `mosaic.cfg` is loaded from that folder, so leftover copies and old
files there do no harm.

**Taking a tool out:** put a hash sign in front of its block in section 5 and of its dock switch in section 6. Its
saved offsets and filament stay saved.

**Updates** never touch `mosaic.cfg`. If the template changes, the new one is saved beside yours as `mosaic.cfg.new`,
so you can see what is new and copy it over.

**Coming from an older install** (the numbered `00_core.cfg` ... `90_settings.cfg` files)? The installer joins them
into one `mosaic.cfg` for you (in the same order they used to load) and moves the old files into `MOSAIC/old/`.

### 4. Restart Klipper and run `MOSAIC_CHECK`

It reports anything that is missing, including the docking (it runs `MOSAIC_DOCK_CHECK` at the end).

### Updating

The installer adds MOSAIC to Mainsail's update panel (**Machine** page), so it updates like Klipper and Moonraker. An
update only replaces `~/MOSAIC` (what `core/` points to); your files in the MOSAIC folder are never touched. Without
the update panel, run `git pull` in `~/MOSAIC` and restart Klipper. After an update, run `./install.sh` once more if the
release notes say a template changed: it saves the new template beside yours as `.new` for you to compare.

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

klipper-toolchanger does not need one extruder motor per tool. Every tool can have its own heater, thermistor and
fan while one extruder motor is shared. There are two ways to set up the heaters; MOSAIC works with both.

**Heater-only extruders (recommended).** Each tool gets an `[extruder]`, `[extruder1]`, ... section with only the
heater and thermistor (no `step_pin`), and the one motor is an `[extruder_stepper]` that is handed to the mounted tool
after every change:

```
[extruder_stepper shared_drive]
extruder: extruder
step_pin: ...          # the extruder motor on the mainboard
...
[extruder1]            # tool 1: heater and thermistor only
heater_pin: ...
sensor_type: ...
sensor_pin: ...
...
[tool T1]
tool_number: 1
extruder: extruder1

[toolchanger]
after_change_gcode:
    SYNC_EXTRUDER_MOTION EXTRUDER=shared_drive MOTION_QUEUE={tool.extruder}
```

Klipper's cold-extrusion check then works for every tool, and slicer lines like `M104 T1 S220` reach the right
heater without `mosaic_tool_heaters.cfg` (include it anyway if you use the standby handling, see below). Use
`after_change_gcode` as shown rather than klipper-toolchanger's own `extruder_stepper:` tool option: that option
passes the full section name (`extruder_stepper shared_drive`) to `SYNC_EXTRUDER_MOTION`, which expects the short
name, so the hand-over fails.

**Generic heaters.** Each tool gets a `[heater_generic ...]` and the tool points at it with `heater:`; leave out
`extruder:`:

```
[heater_generic hotend0]
heater_pin: ...
sensor_type: ...
sensor_pin: ...
control: pid
...
[tool T0]
tool_number: 0
heater: heater_generic hotend0
```

Things to know for this layout:

- **Cold extrusion check.** Klipper checks `min_extrude_temp` against the heater of the `[extruder]` section only,
  never a `heater_generic`. So the `[extruder]` heater has to be something real, or `min_extrude_temp` has to be
  `0`, and then Klipper no longer stops a cold extrusion: keep the temperature handling in your own macros or the
  slicer.
- **M104 / M109.** Klipper's own `M104` and `M109` only know `[extruder]` heaters, and klipper-toolchanger does not
  wrap them. Slicer lines like `M104 T1 S220` therefore do nothing for a `heater_generic` tool. Include
  `mosaic_tool_heaters.cfg` (see below) or let the slicer use `SET_TOOL_TEMPERATURE T=1 TARGET=220`.

For both layouts:

- **Fans.** A tool's `fan:` (a `[fan_generic ...]`) is its part-cooling fan: `M106 S.. T..` and `M107 T..` are
  handled by klipper-toolchanger's fan switcher. Do not define a `[fan]` section next to tool fans; klipper-toolchanger
  refuses that. A hotend (heat sink) fan per tool is a `[heater_fan]` with `heater:` set to that tool's heater.
- **Beacon macros.** The thermal expansion offset of the Beacon macro set follows the `[extruder]` named in
  `_BEACON_SETTINGS`, not the heater of the mounted tool.

### The T commands

`mosaic.cfg` loads `mosaic_tools.cfg` before the tools (section 5), as it must: klipper-toolchanger registers its own
`T0` ... `T9` for every tool and does not replace a macro that already exists, so MOSAIC's macros have to be there
first. If a `[tool Tn]` section is left in `printer.cfg` above the include line, Klipper stops with
`gcode command T0 already registered`; move it into section 5 of `mosaic.cfg`.

| Command | Meaning |
|---|---|
| `T0` ... `T9` | Mount the tool (`SELECT_TOOL`), apply its saved offset in `gcode_offset` mode, and run the standby handling. Does nothing when that tool is already mounted. An unconfigured tool prints a warning; it does not raise an error, because any G-code error makes klipper-toolchanger forget the mounted tool. |
| `MOSAIC_SET_TEMP [T=] TARGET= [WAIT=1]` | Set the temperature of a tool (default: the mounted one). |
| `MOSAIC_TOOL_STANDBY [T=]` | Set the tool to `standby_temp` and remember its temperature. |
| `MOSAIC_TOOLS_OFF` | All tool heaters off. |
| `MOSAIC_TOOLS_STATUS` | One console line per tool: mounted or docked, temperature, target, filament. |
| `MOSAIC_SET_FILAMENT [T=] MATERIAL= NAME= COLOR= TEMP= [CLEAR=1]` | The filament loaded in a tool, see "Filament per tool". |
| `MOSAIC_TOOL_LOG [RESET=1]` | The last tool changes with their time and result. |

`_MOSAIC_TOOLS_SETTINGS` has the settings `standby_mode`, `standby_temp`, `wait_on_select` and `presets`. With `standby_mode: 'off'`
(default) a tool change does not touch any heater, which is right when the slicer sends its own standby
temperatures. With `'standby'` the tool that is put away goes to `standby_temp` (0 = off), and it returns
to its earlier temperature when it is mounted again (`wait_on_select` waits for it). Only a tool that is still at
`standby_temp` is restored, so a heater you switched off yourself stays off. For this to work change
temperatures with `M104 T..`, `MOSAIC_SET_TEMP`, or the page; raw `SET_TOOL_TEMPERATURE` bypasses the memory.

Every `T<n>` macro has an `active` variable that is `True` for the mounted tool. The state
of klipper-toolchanger (`printer.toolchanger.tool_number`) is the real source; `active` is only for
frontends that read it.

### M104 and M109 with T

`mosaic_tool_heaters.cfg` wraps `M104` and `M109` so `T` selects the tool and no `T` means the mounted tool. Without
a mounted tool and without `T` the original command runs. `M109` waits for the tool it names; it does not
mount it. Do not include it together with `beacon_heater_hooks.cfg`: both define the macros `M104` and `M109`,
Klipper does not complain but merges them, and the file included last silently wins. This file calls the
Beacon offset update itself when the Beacon macros are loaded, so leave the Beacon hooks file out.

### Filament per tool

Each tool remembers the filament that is loaded: material, a name, a colour and its print temperature. Set it on the
page (the **Filament** button on a card) or in the console:

```
MOSAIC_SET_FILAMENT T=2 MATERIAL=PETG NAME="Galaxy Blue" COLOR=1E5AFF TEMP=240
```

`COLOR` is six hex digits without the `#` (Klipper reads `#` as the start of a comment). Values you leave out stay as
they were, so `MOSAIC_SET_FILAMENT T=2 TEMP=245` only changes the temperature; `CLEAR=1` forgets the filament. It is
saved in `[save_variables]` as `t2_filament` and survives a restart. Spoolman is not needed and not used.

The card shows a hotend drawn in the filament colour with the material and name. The print temperature becomes a
temperature button on the card.

### Filament sync with OrcaSlicer

MOSAIC copies the filament of every tool into Moonraker's database (namespace `lane_data`, one entry `T0` ... `T9`
per tool, the format AFC and Happy Hare use). OrcaSlicer reads it for Moonraker printers: press **Synchronize
filaments** in the filament list of the prepare tab, and Orca fills its filament slots with the colour and material
of every tool, so you do not pick them by hand.

- **Set up once in Orca:** connect the printer (the printer's address with Moonraker's port, for example
  `192.168.1.50:7125`). A recent OrcaSlicer is needed; older versions have no filament sync for Moonraker printers.
- **What Orca gets:** colour, material, the print temperature and the name you gave the filament. Orca chooses a
  matching generic profile for the material (for example Generic PLA); if you use your own tuned profile, pick it once
  after the sync.
- **When it updates:** the MOSAIC page service checks every 5 seconds, so a change on the page or with
  `MOSAIC_SET_FILAMENT` is there a moment later; then press sync in Orca again. Orca only reads, it never writes back.
- **Tools without a filament** are left out. Only the entries `T0` ... `T9` are MOSAIC's; other `lane_data` entries
  (from an MMU, for instance) are not touched. If you also edit filament slots in Mainsail, MOSAIC's values win for
  `T0` ... `T9`.
- **Needs the page service** (`mosaic-ui`, set up by `install.sh`). Switch the sync off with
  `variable_slicer_sync: False` in section 2 of `mosaic.cfg`; the entries already written then stay as they are.

### Temperature buttons

`presets` in `_MOSAIC_TOOLS_SETTINGS` is the list of temperature buttons on every card, as `name:temperature` separated
by commas. A tool can have its own list:

```
# in MOSAIC/mosaic.cfg, section 2
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_presets: 'PLA:215, PETG:240, ABS:255'
variable_presets_t3: 'TPU:225'
```

(`presets_t3` is for T3 only.)

`''` shows no buttons. The print temperature of the loaded filament is added as an extra, highlighted button.

### Filament check

The page compares the filament colours and types that the slicer wrote into a file (Moonraker's file metadata, filled
by OrcaSlicer, PrusaSlicer, SuperSlicer and others) with the filament saved for each tool the file uses. Choose any of
the 30 newest files to check it **before** you print; without a choice the page checks the current (or last) print. A
material that differs, or a colour that is clearly different, is marked in red, and when another tool holds the
expected filament the page says so ("different colour — loaded in T7").

The check only warns; it does not stop a print and it does not change which tool prints what. To use another tool,
load the expected filament into the tool the file asks for, or assign that filament to the other tool in the slicer
and slice again. Tool mapping belongs in the slicer: it also sets the temperatures, pressure advance, retraction and
purge for the tool it assigns, which a remap on the printer would miss. The check needs the filament set for the
tools (see "Filament per tool").

### Tool change log

The `T0` ... `T9` commands time every tool change, including the wait for the temperature in standby mode, and
check it: afterwards the tool must be the mounted one and, if you have a carriage switch (`mosaic_head`), the switch
must see a tool. A change that stopped with an error is counted as failed at the next change. `MOSAIC_TOOL_LOG`
prints the last 20 changes, the page shows the last 10 with the number of changes, failures and the average time. The
log lives in memory and starts empty after a Klipper restart. Changes made with `SELECT_TOOL` directly (the
calibration does that) are not logged.

## Docking

Every tool change goes through klipper-toolchanger's `SELECT_TOOL` (and `UNSELECT_TOOL` for the Dock button), and
klipper-toolchanger runs the docking motion from the `pickup_gcode` and `dropoff_gcode` hooks. Options you put in
`[toolchanger]` are the defaults for all tools, and an option that is present but empty in a tool section overrides that
default.

MOSAIC brings its own dock macros for passive couplings (`mosaic_dock.cfg`). The hooks in section 4 of `mosaic.cfg` already
point at `MOSAIC_DOCK_PICKUP` / `MOSAIC_DOCK_DROPOFF`; teach the docks in section 7, done. Setup, paths, switches and commands are in
[docs/docking.md](docs/docking.md). If your changer has its own dock macros (an actuated lock, for instance), put a hash
sign in front of `mosaic_dock.cfg` in section 1, empty section 7, and point the hooks at your macros.

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

The page works on a phone or a computer, and needs only the Python that is already on the printer. `install.sh` sets
it up; click **MOSAIC** in Mainsail's sidebar to open it.

One card per tool, up to ten: mounted or docked, current and target temperature with a
state (off, heating, ready, cooling), a field and buttons to set the temperature, put the tool on standby or
switch it off, the temperature buttons, a fan slider, the saved offsets, and Mount, Dock and Calibrate. Each card
also shows the loaded filament and has a **Filament** button to change it. The bar on top has All heaters off
and the tool list. Below the calibration and offsets come the tool change log and, during a print, the filament
check. The Calibration section has Calibrate all tools, X and Y only, Z only, an optional temperature,
the Nudge state, the set-up check and the saved offsets. Without `mosaic_tools.cfg` the buttons
fall back to `SELECT_TOOL` and `SET_TOOL_TEMPERATURE`.

**Locked while printing.** While a print runs or is paused, Mount, Dock, Calibrate and Reload saved offsets are
switched off on the page, so a tap cannot move the toolhead in the middle of a print. Temperatures, fans and the
filament still work. The console commands are not locked (`MOSAIC_AUTO_Z_OFFSET` is meant to run in `PRINT_START`).

The page can move the printer and heat tools, and the server has no login, just like Mainsail itself. Use it only
on a trusted network.

### What the installer sets up

- **The service** `mosaic-ui` runs the page server (`ui/mosaic_server.py`) as your user. It listens only on the
  printer itself (port 8099); you reach it through Mainsail's web server.
- **The address `http://<printer>/mosaic/`.** The installer adds one `include` line for `ui/nginx-mosaic.conf` to
  Mainsail's nginx site (`/etc/nginx/sites-available/mainsail`), checks it with `nginx -t`, and puts the original
  back if the check fails. A backup is kept as `mainsail.mosaic-backup`. Because the page shares Mainsail's address,
  the sidebar entry works however you reach the printer (IP address, host name, VPN). If your site file has another
  name, run `NGINX_SITE=/etc/nginx/sites-available/<name> ./install.sh`.
- **The sidebar entry.** Mainsail reads extra sidebar entries from `.theme/navi.json` in the config folder. The
  installer adds the MOSAIC entry from `examples/mainsail/navi.json` to that file, keeping any entries you already
  have. It opens the page in the same tab; change `"target"` to `"_blank"` for a new tab.
- **The update panel.** An `[update_manager mosaic]` section in `moonraker.conf`, and `mosaic-ui` in
  `moonraker.asvc` so Moonraker may restart the page after an update.

Running `./install.sh` again is safe: every step checks what is already there. Reinstalling Mainsail (for
instance with KIAUH) can replace its nginx site; run `./install.sh` again afterwards to put `/mosaic/` back.

The sidebar entry is a Mainsail feature. Fluidd users can open `http://<printer>/mosaic/` directly.

### Uninstalling

`./uninstall.sh` removes the include line from `printer.cfg`, the `core` link, the service, the `/mosaic/` line in the
nginx site, the sidebar entry, the update panel entry and the Z switch module links, and keeps a backup of every file
it edits. Your MOSAIC folder stays, with your tools, settings and dock positions, and so do the offsets and filaments
in `[save_variables]`. If you keep using the tool changer without MOSAIC, move your tools and `[toolchanger]` section
back into `printer.cfg` (without the MOSAIC dock hooks) before restarting Klipper.

**By hand, without the installer:** copy `ui/mosaic-ui.service` to `/etc/systemd/system/`, fix the user and the
path inside, run `sudo systemctl enable --now mosaic-ui`, and open `http://<printer-address>:8099`.

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
been run in batch mode yet. The page's `/mosaic/` route was tested through a real nginx in front of the page server;
the installer itself has not been run on a real Pi. The filament, temperature button, tool change log and lock
features were tested in a Klipper-style macro simulator (same template rules and parameter parsing, not Klipper
itself) and in a headless browser against a fake Moonraker with an 8 tool printer, idle and printing. `uninstall.sh`
has not been run on a real Pi.

**Not tested: real hardware.** Batch mode has no Nudge, no switch that triggers and no moving printer. The stand-in
probe uses the sign convention of the klipper-toolchanger code; whether the offsets come out with the
right sign on a real printer needs the check described under "Sign convention". Waiting for temperatures
(`WAIT=1`) cannot be checked in batch mode, fan speeds could not be read back, and the Mainsail sidebar entry was not tried
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
