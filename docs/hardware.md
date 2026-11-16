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
# MOSAIC/mosaic.cfg, section 4: hand the motor to the mounted tool
[toolchanger]
after_change_gcode:
    SYNC_EXTRUDER_MOTION EXTRUDER=shared_drive MOTION_QUEUE={tool.extruder}
...

# MOSAIC/mosaic.cfg, section 5
[tool T0]
tool_number: 0
extruder: extruder

[tool T1]
tool_number: 1
extruder: extruder1

# MOSAIC/mosaic.cfg, section 6
[gcode_macro _MOSAIC_TOOLS_SETTINGS]
variable_head_switch: 'carriage_switch'
variable_dock_switches: 'dock_0, dock_1'
```

See the README, "A hotend swapper with one extruder", for why the motor is handed over with `after_change_gcode`
rather than klipper-toolchanger's `extruder_stepper:` tool option, and for the `heater_generic` alternative.

## Switches

The switch names are read from `_MOSAIC_TOOLS_SETTINGS`:

- `variable_head_switch`: the name of the carriage switch's `[gcode_button]`. Default `mosaic_head`.
- `variable_dock_switches`: the dock switches in tool order T0, T1, T2 ..., separated by commas. An empty or missing
  entry means `mosaic_dock_t<n>`, so `'dock_0, , dock_2'` gives T1 the default name.

A switch that does not exist is skipped. `MOSAIC_DOCK_SWITCHES` prints every switch by the name MOSAIC looks for, so
it shows straight away if a name is wrong. More in [docking.md](docking.md), "Tool switches".
