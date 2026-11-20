# Your hardware

MOSAIC works with any board. It contains no board of its own: the heaters, thermistors, fans, motors and switches of
your tools are set up in sections 5 and 6 of `MOSAIC/mosaic.cfg`, and MOSAIC refers to them by name. You have two
ways to set them up. Pick one per printer.

**A. A file of your own.** A board file next to `printer.cfg` (from your tool changer, or one you write from the
examples below), pulled in by one line in section 5 of `mosaic.cfg`:

```
MOSAIC/mosaic.cfg   section 5:   [include ../my_tools.cfg]
my_tools.cfg                     yours, next to printer.cfg; MOSAIC never touches it
```

The `../` is there because the include is relative to the `MOSAIC` folder. (Including the file in `printer.cfg`
before `[include MOSAIC/mosaic.cfg]` works as well.) The name of the file is up to you, and so are the names of the
sections in it.

**B. Everything in `mosaic.cfg`.** The examples below are what you would put in sections 5 and 6 (Part 1 of each),
without a separate file. The templates in the file are the same, with `...` where your pins go.

Either way, one toolboard per tool, an expansion board for all tools, or everything on the mainboard: the
`[tool Tn]` sections look the same.

What goes where:

| What | Where |
|---|---|
| `[mcu ...]` of the tool board(s) | your board file (A), or in `printer.cfg` |
| `[extruder]` ... `[extruder9]` or `[heater_generic ...]` (heater, thermistor, motor if any) | A: your board file. B: `mosaic.cfg`, section 5 Part 1 |
| `[extruder_stepper ...]` (a shared extruder motor) | same |
| `[heater_fan ...]`, `[fan_generic ...]` | same |
| `[gcode_button ...]` carriage and dock switches | A: your board file. B: `mosaic.cfg`, section 6 Part 1 |
| `[tool Tn]` | `MOSAIC/mosaic.cfg`, section 5 Part 2 |
| which switch is which (only if not named `mosaic_head`, `mosaic_dock_t<n>`) | `MOSAIC/mosaic.cfg`, section 6 Part 2 |
| `[toolchanger]` | `MOSAIC/mosaic.cfg`, section 4 |
| Nudge probe and Z switch | `MOSAIC/mosaic.cfg`, section 3 (MOSAIC's own equipment) |

The `[tool Tn]` sections stay in `mosaic.cfg` because MOSAIC's `T0` ... `T9` commands have to load before them.

## Example A: every tool is a full toolhead

Every tool has its own extruder motor, for example one toolboard per tool. The names (`tool0`, `t0_part_fan`, ...)
are examples; replace every `...` with your values.

```
# my_tools.cfg

[mcu tool0]
serial: /dev/serial/by-id/...

[extruder]
step_pin: tool0:...
dir_pin: tool0:...
enable_pin: !tool0:...
microsteps: 16
rotation_distance: ...
heater_pin: tool0:...
sensor_type: ...
sensor_pin: tool0:...
control: pid
pid_Kp: ...
pid_Ki: ...
pid_Kd: ...
min_temp: 0
max_temp: 300
nozzle_diameter: 0.4
filament_diameter: 1.75

[heater_fan t0_hotend_fan]
pin: tool0:...
heater: extruder
heater_temp: 50.0

[fan_generic t0_part_fan]
pin: tool0:...

# Dock switch of T0, pressed while the tool sits in its dock
[gcode_button t0_dock]
pin: ^...
press_gcode:

# ... the same for T1 with [mcu tool1], [extruder1], t1_hotend_fan, t1_part_fan, t1_dock
```

```
# MOSAIC/mosaic.cfg, section 5
[tool T0]
tool_number: 0
extruder: extruder
fan: fan_generic t0_part_fan

[tool T1]
tool_number: 1
extruder: extruder1
fan: fan_generic t1_part_fan

# MOSAIC/mosaic.cfg, section 6
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_dock_switches: 't0_dock, t1_dock'
```

## Example B: hotend swapper with one shared extruder motor

Every tool has its own heater, thermistor and hotend fan; only the hotend is swapped and one extruder motor feeds
whichever tool is mounted. Each tool is a heater-only `[extruder]` (no `step_pin`), and the motor is an
`[extruder_stepper]`.

```
# my_tools.cfg

[mcu toolbox]
serial: /dev/serial/by-id/...

# The shared extruder motor (wherever it is wired, here on the mainboard)
[extruder_stepper shared_drive]
extruder: extruder
step_pin: ...
dir_pin: ...
enable_pin: !...
microsteps: 16
rotation_distance: ...

[extruder]
heater_pin: toolbox:...
sensor_type: ...
sensor_pin: toolbox:...
control: pid
pid_Kp: ...
pid_Ki: ...
pid_Kd: ...
min_temp: 0
max_temp: 300
min_extrude_temp: 170
nozzle_diameter: 0.4
filament_diameter: 1.75

[heater_fan hotend_fan_0]
pin: toolbox:...
heater: extruder
heater_temp: 50.0

# ... [extruder1] and hotend_fan_1 for T1, and so on

# The carriage switch: pressed while any tool is attached
[gcode_button carriage_switch]
pin: ^...
press_gcode:
release_gcode:
    MOSAIC_DOCK_HEAD_RELEASED

[gcode_button dock_0]
pin: ^toolbox:...
press_gcode:

[gcode_button dock_1]
pin: ^toolbox:...
press_gcode:
```

```
# MOSAIC/mosaic.cfg, section 2: the shared motor
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_motor: 'shared_drive'

# MOSAIC/mosaic.cfg, section 5
[tool T0]
tool_number: 0
extruder: extruder
params_pressure_advance: 0.045
params_pressure_advance_smooth_time: 0.04

[tool T1]
tool_number: 1
extruder: extruder1
params_pressure_advance: 0.062

# MOSAIC/mosaic.cfg, section 6
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_head_switch: 'carriage_switch'
variable_dock_switches: 'dock_0, dock_1'
```

The `after_change_gcode` hook in section 4 (`MOSAIC_AFTER_CHANGE`) hands the motor to the mounted tool and sets that tool's
pressure advance. You do not write the `SYNC_EXTRUDER_MOTION` line yourself.

**Where the pressure advance goes.** Klipper keeps pressure advance on the motor, not on the heater-only `[extruderN]`
(it has no motor, so `SET_PRESSURE_ADVANCE EXTRUDER=extruder1` fails). With one shared motor there is one value at a time,
so each tool needs its own and has to set it when it is mounted:

- `params_pressure_advance` (and `params_pressure_advance_smooth_time`) in `[tool Tn]`: set on the motor after every
  tool change. Tune it per hotend and write the number there. A tool without the line leaves the value alone.
- `params_rotation_distance` in `[tool Tn]`: the same for the rotation distance, for tools with a different hotend
  drive ratio or filament. Left out = not touched.
- `SET_PRESSURE_ADVANCE ADVANCE=...` typed in the console, or sent by a slicer, has no `EXTRUDER=` and acts on the
  active extruder, which is heater-only here. Include `core/mosaic_shared_extruder.cfg` in section 1 and it is sent to
  the motor named in `variable_motor` instead (a command with its own `EXTRUDER=` is passed on unchanged). Klipper
  allows only one `SET_PRESSURE_ADVANCE` macro, so do not use this file together with one of your own.
  A value set that way lasts until the next tool change, when the tool's own `params_` value is set again.
- For calibrating the pressure advance with the usual tower, mount the tool, set the line in `[tool Tn]`, then run
  `MOSAIC_AFTER_CHANGE T=<n>` (or just change tools) so the printer has the same value the print will use.

## Example C: the shared motor is the `[extruder]` stepper

Some printers (Bondtech INDX style heads among them) have the one motor as the stepper of `[extruder]` itself, and T1, T2, ...
are heater-only `[extruderN]` sections that the motor is switched over to. This works the same way as example B, with
the motor named `extruder`:

```
# my_tools.cfg
[extruder]                  # T0's heater AND the one motor
step_pin: ...
dir_pin: ...
enable_pin: !...
microsteps: 16
rotation_distance: ...
heater_pin: ...
sensor_type: ...
sensor_pin: ...
control: pid
...

[extruder1]                 # T1: heater and thermistor only, no step_pin
heater_pin: ...
sensor_type: ...
sensor_pin: ...
control: pid
...
```

```
# MOSAIC/mosaic.cfg, section 2
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_motor: 'extruder'
```

The tools and the `params_` lines are the same as in example B. `MOSAIC_AFTER_CHANGE` runs
`SYNC_EXTRUDER_MOTION EXTRUDER=extruder MOTION_QUEUE=<tool's extruder>` for every tool, T0 included, so after T1 the
motor goes back to T0's own queue. Pressure advance goes on `extruder` here, which is what the plain
`SET_PRESSURE_ADVANCE` already does while T0 is active, but not while T1 is: use the optional
`mosaic_shared_extruder.cfg` or the `params_` lines.

If your printer has a different arrangement (every tool with its own motor, or a motor that is moved by a macro of
your own), leave `variable_motor` empty and MOSAIC does nothing with the extruder motor.

## Printing with a shared motor

- **Retract before the change, prime after.** A hotend that is put away with the filament still pushed into it oozes,
  and the new tool starts with an empty nozzle. `variable_retract` (section 2) pulls the filament back on the tool that
  leaves and pushes it forward again when that tool is mounted, `retract_speed` / `unretract_speed` set the speeds.
  It happens during a print only, or by hand with `MOSAIC_RETRACT` / `MOSAIC_PRIME` and `FORCE=1`. The push-back waits
  for the tool's heater to reach its target (`prime_wait`); with the heater off nothing is pushed and the retract stays
  pending, a later `MOSAIC_PRIME` (a print start can call it after heating the tool) does it. Set the slicer's tool change retraction to 0, or the filament is
  pulled twice.
- **Print start and end.** In `PRINT_START`, heat and mount the first tool with `T<n>` as always, then call
  `MOSAIC_REQUIRE_TOOL T=<n>`: when the change failed the print is paused (see docking.md, "When a change fails during a
  print"), but a macro that is already running carries on, and this stops it with an error. If the first tool is already on
  the carriage no change happens and nothing is primed: call `MOSAIC_PRIME T=<n>` yourself after heating it. At the end of the
  print `MOSAIC_TOOLS_OFF RETRACT=1` pulls the filament of the mounted tool back and switches every heater off. The
  tools in their docks were retracted when they were put away.
- **Pending retracts are saved.** Which tool is retracted by how much is written to `[save_variables]`
  (`t<N>_retracted`) and read back when Klipper starts, so a restart or a cancelled print does not lose it. The next
  time the tool is mounted in a print it is pushed forward. Outside a print: `MOSAIC_PRIME T=<n> FORCE=1`. It costs
  two small writes of the variables file per tool change.
- **Prime over a brush, and the first prime.** `MOSAIC_PRIME` pushes the filament back where the nozzle is, which after
  a change is on the print (the changer has already moved there). Where that is not wanted, set `variable_prime_macro` to a
  macro of yours: it is called as `MY_MACRO T=<tool> LENGTH=<mm> SPEED=<mm/s>` once the tool is hot, and has to move to
  the brush or bucket, push `LENGTH` mm, wipe and come back. It runs inside the change, so klipper-toolchanger moves to
  the print position afterwards by itself. With it, `variable_first_prime` adds that many mm the first time each
  tool is used in a print (a nozzle that has been standing empty puts down a tower with nothing in it). Call
  `MOSAIC_PRIMED_RESET` at the start of `PRINT_START` so every print starts the list again. `MOSAIC_CHECK` tells you
  if the macro does not exist.
- **M109 wait.** With `mosaic_tool_heaters.cfg`, `variable_wait_below` / `variable_wait_above` make `M109 T.. S..` wait
  for a window around the target (the usual `TEMPERATURE_WAIT`) instead of Klipper's slower "flat for a few seconds" wait,
  which matters when every tool change waits for the temperature.

## Switches

The switch names are read from `_MOSAIC_TOOLS_SETTINGS`:

- `variable_head_switch`: the name of the carriage switch's `[gcode_button]`. Default `mosaic_head`.
- `variable_dock_switches`: the dock switches in tool order T0, T1, T2 ..., separated by commas. An empty or missing
  entry means `mosaic_dock_t<n>`, so `'dock_0, , dock_2'` gives T1 the default name.

A switch that does not exist is skipped. `MOSAIC_DOCK_SWITCHES` prints every switch by the name MOSAIC looks for, so
it shows straight away if a name is wrong. More in [docking.md](docking.md), "Tool switches".
