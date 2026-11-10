# MOSAIC docking

Pick-up and drop-off macros for a **hotend-only toolchanger with a passive (Maxwell / kinematic) coupling**, built for [klipper-toolchanger](https://github.com/viesturz/klipper-toolchanger) on Klipper or Kalico. Each tool has its own dock section where you enter the position and, if the dock needs it, its own approach and exit path. Up to 10 tools (T0 to T9).

This is the docking part of MOSAIC. The calibration (`mosaic.cfg`) and the tool commands (`mosaic_tools.cfg`) use it for every tool change; it can also be used on its own. Back to the [main README](../README.md).

> **Status: written and tested in simulation only.** The macros were run against the real klipper-toolchanger module in Klipper's and Kalico's batch mode (all planned moves checked, errors checked). They have **not** been run on a printer. Your dock geometry is not known to the macros, so the numbers in `mosaic_dock_positions.cfg` are placeholders until you teach them. Do the first runs slowly, hand on the power switch. See [Before the first real tool change](#before-the-first-real-tool-change).

## What it assumes

- The coupling is **passive**: no motor, servo or pneumatic lock. Picking up and dropping off is only carriage motion. The dock holds the tool and the carriage takes it (or leaves it) by moving in and out along a path. If your mechanism has an actuator, these macros do not drive it.
- Positions are raw carriage coordinates in mm. Z is up.
- The carriage can travel sideways over all docks at one "safe" height.
- Switches are optional but recommended: **one switch on the carriage** that is pressed while any tool is attached, and **one switch per dock** that is pressed while its tool sits in the dock. See [Tool switches](#tool-switches).

## What it does

A pickup of tool `n` does this, every number from your settings:

1. Go up to `safe_z` if the carriage is lower.
2. Travel sideways at that height to the first step of the approach path, go down there.
3. Walk the approach path, the last move into the dock position is slow (`engage_speed`).
4. Wait `seat_dwell` ms.
5. Walk the exit path out of the dock, slowly (`pullout_speed`), optionally checking the carriage switch on the way.
6. Once the carriage is out, read both switches and compare with what must be true now (see [Tool switches](#tool-switches)).
7. Go up to `safe_z`, then sideways to where the print was, then down. (Only if you pass the restore position, see below.)

A drop-off is the same with its own exit path. It is called for the old tool first and for the new tool second during `T1`, `SELECT_TOOL` and so on, all handled by klipper-toolchanger.

Safety built in:

- Nothing moves for a dock until its section says `variable_taught: 1`.
- Before any motion, the whole plan is checked: every step must be a valid `dx,dy,dz`, inside the printer's axis limits, speeds above zero. A typo is an error message, not a crash into the frame.
- The macros refuse to move unless the toolchanger is in the `changing` state (a tool change, or after `ENTER_DOCKING_MODE`). That is the state where tool offsets are switched off, so the numbers mean the same thing every time.
- Every command takes `DRY=1` and then only prints the moves it would make.
- With the switches wired, a missing, stuck or dropped tool stops the change with a plain message instead of carrying on.

## Install

Docking is installed with the rest of MOSAIC (see [Installation](../README.md#installation) in the main README):

1. `./install.sh` creates `mosaic_dock_positions.cfg` in your config folder, next to `printer.cfg`, from the template in `examples/`. It never overwrites an existing one; a fresh template is saved as `mosaic_dock_positions.cfg.new` instead. The positions file lives outside the MOSAIC folder on purpose, so updating MOSAIC with `git pull` never touches your numbers.

2. Add to `printer.cfg`:

   ```
   [include mosaic/mosaic_dock.cfg]
   [include mosaic_dock_positions.cfg]
   ```

3. In your `[toolchanger]` section, add the two hooks (full copy-paste version in [`examples/printer.cfg.example`](../examples/printer.cfg.example)):

   ```
   [toolchanger]
   pickup_gcode:
       MOSAIC_DOCK_PICKUP T={tool.tool_number}{% if 'X' in restore_position %} RX={restore_position.X}{% endif %}{% if 'Y' in restore_position %} RY={restore_position.Y}{% endif %}{% if 'Z' in restore_position %} RZ={restore_position.Z}{% endif %}
   dropoff_gcode:
       MOSAIC_DOCK_DROPOFF T={tool.tool_number}{% if pickup_tool is none %}{% if 'X' in restore_position %} RX={restore_position.X}{% endif %}{% if 'Y' in restore_position %} RY={restore_position.Y}{% endif %}{% if 'Z' in restore_position %} RZ={restore_position.Z}{% endif %}{% endif %}
   ```

   A `[tool Tn]` section with its own `pickup_gcode` or `dropoff_gcode` overrides these, so remove those lines from the tools (an empty `pickup_gcode:` line counts as an override).

4. Restart Klipper and run `MOSAIC_CHECK`. It runs `MOSAIC_DOCK_CHECK` at the end, which lists which tools have a dock set up and warns if the hooks are missing. Until you teach the docks it will report problems, which is correct.

## Set up the docks

Open `mosaic_dock_positions.cfg`. Part 1 has the shared settings, part 2 has one section per tool.

**Shared settings (set these first, conservatively):**

| Setting | Meaning |
|---|---|
| `safe_z` | Height for sideways travel over the docks. Higher than every tool standing in its dock. |
| `travel_speed`, `z_speed` | Free moves, mm/s |
| `approach_speed` | Moves between approach steps, mm/s |
| `engage_speed` | The last move into the dock, mm/s. Keep it slow. |
| `pullout_speed` | Moves out of the dock, mm/s. Keep it slow. |
| `seat_dwell` | Pause when seated, ms |
| `restore_move` | `1` = after the change go back to the print position safely (sideways at safe height first, then down) |
| `check_switches` | `1` = read the switches before and after every change, `0` = ignore them |
| `switch_settle` | Wait in ms after the carriage stops before reading the switches |
| `approach` | Default approach path for all docks, see [Paths](#paths) |
| `pickup_out`, `dropoff_out` | Default exit paths. Empty means: walk the approach path backwards. |

**Per tool (`_MOSAIC_DOCK_T0` … `_MOSAIC_DOCK_T9`):** `taught`, `park_x`, `park_y`, `park_z`, and optional own `approach`, `pickup_out`, `dropoff_out` (leave empty to use the shared ones).

### Teach a dock

With a tool standing in its dock and the carriage free:

1. `G28`, then jog the carriage by hand in Mainsail (small steps near the end) until the coupling sits fully seated on the tool.
2. `MOSAIC_DOCK_TEACH T=0`. The current carriage position is stored for now and the lines to keep it are printed in the console.
3. Paste those lines into `[gcode_macro _MOSAIC_DOCK_T0]` in `mosaic_dock_positions.cfg`. (`SAVE_CONFIG` does not store these, they are plain macro variables. Without pasting, the value is lost at the next restart.)

Docks in an even row: teach one, then `MOSAIC_DOCK_FILL FROM=0 TO=5 DX=45` calculates T1 to T5 at 45 mm spacing. The numbers are computed, not measured, check each dock with the next step.

### Check a dock without a tool change

```
ENTER_DOCKING_MODE
MOSAIC_DOCK_GOTO T=2 WHERE=stage     # carriage stops just before the dock, look at the alignment
MOSAIC_DOCK_GOTO T=2 WHERE=park      # slow move to the dock position
MOSAIC_DOCK_LEAVE T=2 MODE=pickup    # walk out as a pickup would
EXIT_DOCKING_MODE
```

Adjust with `MOSAIC_DOCK_SET T=2 PARK_X=101.2 PARK_Y=280.4` until it is right (valid until restart), then paste the final numbers into the file. `MOSAIC_DOCK_GOTO` starts from free space: it first goes up to `safe_z` and over to the first approach step. Do not start it with the carriage seated in a dock, use `MOSAIC_DOCK_LEAVE` first.

### Before the first real tool change

1. `MOSAIC_DOCK_CHECK` is clean.
2. `MOSAIC_DOCK_PICKUP T=0 DRY=1` and `MOSAIC_DOCK_DROPOFF T=0 DRY=1` print every move. Read them.
3. Put the speeds at about half of what you want in the end. Run `T0` with your hand on the emergency stop and watch the carriage. (`ENTER_DOCKING_MODE` followed by klipper-toolchanger's `TEST_TOOL_DOCKING` docks and picks up the current tool again, if you prefer that.)
4. Then `T1`, `T0` back and forth, then the other tools, then raise the speeds step by step.

## Tool switches

Two kinds of switch, both read as `[gcode_button]` so Klipper and Kalico treat them the same. Wire them so the button is **pressed when a tool is present** (put `!` in front of the pin if yours works the other way round).

```
# One switch on the carriage: pressed while any tool is attached
[gcode_button mosaic_head]
pin: ^PA1
press_gcode:
release_gcode:
    MOSAIC_DOCK_HEAD_RELEASED

# One switch per dock: pressed while that tool sits in its dock
[gcode_button mosaic_dock_t0]
pin: ^PA2
press_gcode:
```

The names are fixed: `mosaic_head` and `mosaic_dock_t0` … `mosaic_dock_t9`. A switch that does not exist is skipped, so you can start with only some of them. A full example is in [`examples/printer.cfg.example`](../examples/printer.cfg.example).

**At the dock** (what these macros do, with `check_switches: 1`):

| Moment | Dock switch | Carriage switch |
|---|---|---|
| before a pickup | tool present | empty |
| before a drop-off | empty | tool present |
| after a pickup | empty | tool present |
| after a drop-off | tool present | empty |

If a check fails the change stops with an error that says what the combination means, for example *"T3 stayed in its dock, the coupling did not take it"*, *"T3 is neither in the dock nor on the carriage, it may have dropped on the way out"* or *"both switches show the tool, check the wiring"*. Before-checks run before anything moves. After-checks run when the carriage is out of the dock, before it travels on, so the carriage stays in free space next to the dock. The step marker `v` in a pickup exit path (see [Paths](#paths)) checks the carriage switch partway out of the dock.

**While printing:** continuous watching is not the job of a dock macro. `MOSAIC_DOCK_HEAD_RELEASED` (called from the `release_gcode` above) reports and pauses a running print if the carriage switch lets go while a tool is selected and no tool change is running. Give the switch a debounce (`debounce_delay: 0.1`) so vibration does not trigger it.

**Why not klipper-toolchanger's own `detection_pin`?** It is made for one switch per tool, so it tells the tools apart. You have one switch on the carriage, which can only say "a tool is attached", and these macros already know which tool they expect. Leave `detection_pin` out of the `[tool]` sections unless every tool has its own, and then both can be used together.

`MOSAIC_DOCK_SWITCHES` prints what every switch reads right now: press them by hand to test the wiring. `MOSAIC_DOCK_PICKUP T=n DRY=1` also prints the before-check against the current readings.

## Paths

A path is a text of steps, separated by `/`. Each step is `dx,dy,dz` in mm **relative to the dock position**, optionally followed by a speed and a check flag:

```
dx,dy,dz[,speed[,v]]
```

- `speed` in mm/s, empty = the default for that kind of move.
- `v` in a pickup exit path: check right after that step that the carriage switch shows a tool. Without a carriage switch it runs `VERIFY_TOOL_DETECTED` instead, which does nothing when the tools have no detection pin.
- The last move of the approach goes to the dock position itself, you do not write it.
- The **first approach step must be in free space** where the carriage can come down from `safe_z`.
- If an exit path is empty, the approach path is walked backwards (speeds in the approach are ignored on the way out).

The default `0,-25,0/0,-5,0` means: stand 25 mm in front of the dock (lower Y), go to 5 mm in front, then slide in. Examples for other dock layouts (from above, sideways, lift-out, tool check partway) are in [`dock_layouts.md`](dock_layouts.md).

## Commands

| Command | What it does |
|---|---|
| `MOSAIC_DOCK_PICKUP T=n` / `MOSAIC_DOCK_DROPOFF T=n` | Used in the `[toolchanger]` hooks. `DRY=1` prints the plan. Moves only in `changing` state. |
| `MOSAIC_DOCK_TEACH T=n` | Take the current carriage position as the dock position, print the lines to paste |
| `MOSAIC_DOCK_FILL FROM=a TO=b DX= [DY= DZ=]` | Calculate the docks of a row from one taught dock |
| `MOSAIC_DOCK_SET T=n PARK_X= PARK_Y= PARK_Z= TAUGHT= APPROACH= PICKUP_OUT= DROPOFF_OUT=` | Change a dock until restart |
| `MOSAIC_DOCK_GOTO T=n WHERE=stage\|park` | Drive to a dock to check it (docking mode needed) |
| `MOSAIC_DOCK_LEAVE T=n MODE=pickup\|dropoff` | Walk out of a dock |
| `MOSAIC_DOCK_SHOW [T=n]` | Print settings and paths |
| `MOSAIC_DOCK_SWITCHES` | Print the current reading of the carriage switch and all dock switches |
| `MOSAIC_DOCK_HEAD_RELEASED` | For the `release_gcode` of the carriage switch: pause the print if a selected tool falls off |
| `MOSAIC_DOCK_CHECK` | Check every tool of the toolchanger: dock set up, paths valid, hooks present, which switches exist |

## How the calibration uses it

`MOSAIC_CALIBRATE` and the `T0` ... `T9` commands change tools through klipper-toolchanger's `SELECT_TOOL`, which runs these dock macros through the `[toolchanger]` hooks. `safe_z` here is the height for travel over the docks; `safe_z` in `_MOSAIC_SETTINGS` is the height for the calibration moves. Set both high enough to clear the docks, the parked tools and the Nudge.

## Limits, honestly

- **No hardware test yet.** Simulation shows the moves and the error handling, it cannot show if the coupling seats. The switch checks were tested with simulated switches that flip at the right moment, not with real ones, so wiring, polarity and debounce need checking on the machine (`MOSAIC_DOCK_SWITCHES`). Expect to adjust the paths, speeds and the dwell.
- **No actuator.** If your coupling needs a latch, magnet release or pin to be driven, that is outside this package.
- **No smoothing.** Moves are plain `G0` with stops at the corners. That is on purpose for slow, controlled docking, but it is slower than the rounded paths of some other toolchanger setups.
- **Dock geometry is yours.** The macros cannot know where walls and neighbouring docks are. `safe_z` and the first approach step must be in free space. Axis limits are checked, collisions are not.
- **Hot tools.** The macros do not touch heaters. Handling of hot tools in the docks (standby temperatures, waiting) is up to your setup, or MOSAIC's standby settings.
- **After any error** in a tool change, klipper-toolchanger forgets the mounted tool. Fix the cause, then `INITIALIZE_TOOLCHANGER T=<n>` (or without T for an empty carriage).
- **`UNSELECT_TOOL`** returns to the print position after the drop-off only because the hook passes the restore position when no new tool follows (see the hook above).

## License

GNU GPL v3, see [LICENSE](../LICENSE).
