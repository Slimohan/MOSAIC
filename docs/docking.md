# VRTX docking

Pick-up and drop-off macros for a **hotend-only toolchanger with a passive (Maxwell / kinematic) coupling**, built for [klipper-toolchanger](https://github.com/viesturz/klipper-toolchanger) on Klipper or Kalico. Each tool has its own dock section where you enter the position and, if the dock needs it, its own approach and exit path. Up to 10 tools (T0 to T9).

This is the docking part of VRTX. The calibration (`vrtx.cfg`) and the tool commands (`vrtx_tools.cfg`) use it for every tool change; it can also be used on its own. Back to the [main README](../README.md).

> **Status: written and tested in simulation only.** The macros were run against the real klipper-toolchanger module in Klipper's and Kalico's batch mode (all planned moves checked, errors checked). They have **not** been run on a printer. Your dock geometry is not known to the macros, so the numbers in section 7 of `VRTX/vrtx.cfg` are placeholders until you teach them. Do the first runs slowly, hand on the power switch. See [Before the first real tool change](#before-the-first-real-tool-change).

## What it assumes

- The coupling is **passive**: no motor, servo or pneumatic lock. Picking up and dropping off is only carriage motion. The dock holds the tool and the carriage takes it (or leaves it) by moving in and out along a path. If your mechanism has an actuator, these macros do not drive it.
- Positions are raw carriage coordinates in mm. Z is up.
- The carriage can travel sideways over all docks at one "safe" height. (A printer whose **bed** moves in Z has no such height: set `z_mode` to `keep`, see [Printers whose bed moves in Z](#printers-whose-bed-moves-in-z).)
- Switches are optional but recommended: **one switch on the carriage** that is pressed while any tool is attached, and **one switch per dock** that is pressed while its tool sits in the dock. See [Tool switches](#tool-switches).

## What it does

A pickup of tool `n` does this, every number from your settings:

1. Go up to `safe_z` if the carriage is lower.
2. Travel sideways at that height to the first step of the entry path, go down there.
3. Walk the entry path (the pickup path for a pickup, the drop-off path for a drop-off; both are the approach path unless you give them their own), the last move into the dock position is slow (`engage_speed`).
4. Wait `seat_dwell` ms.
5. Walk the exit path of that action out of the dock, slowly (`pullout_speed`), optionally checking the carriage switch on the way.
6. Once the carriage is out, read both switches and compare with what must be true now (see [Tool switches](#tool-switches)).
7. Go up to `safe_z`, then sideways to where the print was, then down. (Only if you pass the restore position, see below.)

A drop-off is the same with its own entry and exit path. It is called for the old tool first and for the new tool second during `T1`, `SELECT_TOOL` and so on, all handled by klipper-toolchanger.

Safety built in:

- Nothing moves for a dock until its section says `variable_taught: 1`.
- Before any motion, the whole plan is checked: every step must be a valid `dx,dy,dz`, inside the printer's axis limits, speeds above zero. A typo is an error message, not a crash into the frame.
- The macros refuse to move unless the toolchanger is in the `changing` state (a tool change, or after `ENTER_DOCKING_MODE`). That is the state where tool offsets are switched off, so the numbers mean the same thing every time.
- Every command takes `DRY=1` and then only prints the moves it would make.
- With the switches wired, a missing, stuck or dropped tool stops the change with a plain message instead of carrying on.

## Install

Docking is installed with the rest of VRTX (see [Installation](../README.md#installation) in the main README).
Everything is already in your one file, `VRTX/vrtx.cfg`:

- Section 1 loads the dock engine (`core/vrtx_dock.cfg`).
- Section 7 is your dock positions. Updates never touch the file.
- Section 4 has the two hooks in `[toolchanger]` that run the dock macros for every tool change:

  ```
  [toolchanger]
  pickup_gcode:
      VRTX_DOCK_PICKUP T={tool.tool_number}{% if 'X' in restore_position %} RX={restore_position.X}{% endif %}{% if 'Y' in restore_position %} RY={restore_position.Y}{% endif %}{% if 'Z' in restore_position %} RZ={restore_position.Z}{% endif %}
  dropoff_gcode:
      VRTX_DOCK_DROPOFF T={tool.tool_number}{% if pickup_tool is none %}{% if 'X' in restore_position %} RX={restore_position.X}{% endif %}{% if 'Y' in restore_position %} RY={restore_position.Y}{% endif %}{% if 'Z' in restore_position %} RZ={restore_position.Z}{% endif %}{% endif %}
  ```

  A `[tool Tn]` section with its own `pickup_gcode` or `dropoff_gcode` overrides these, so remove those lines from
  the tools (an empty `pickup_gcode:` line counts as an override).

Restart Klipper and run `VRTX_CHECK`. It runs `VRTX_DOCK_CHECK` at the end, which lists which tools have a dock set
up and warns if the hooks are missing. Until you teach the docks it will report problems, which is correct.

## Set up the docks

Open `VRTX/vrtx.cfg` and go to section 7 (dock positions). Part 1 has the shared settings, part 2 has one section per tool.

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
| `z_mode` | `absolute` (default): the dock moves use `safe_z` and the Z of the dock. `keep`: no dock move has a Z part. `lift`: up to `safe_z` when lower before the dock moves, back to the print Z after, the dock steps have no Z. `keep` and `lift` are for printers whose bed moves in Z, see [below](#printers-whose-bed-moves-in-z). |
| `lift_min` | `z_mode: lift` only: go at least this many mm above the print Z before the dock moves (default 0 = only `safe_z`). |
| `travel_accel` | Acceleration of the lift to `safe_z` and of the way back to the print: `fast` (default, `accel_fast`), `slow`, `print` (the acceleration the print had) or mm/s². |
| `prime_before_restore` | `1` = after a pickup that is followed by a first prime (`first_prime` with a `prime_macro`), the way back to the print waits until after the prime, so the `prime_macro` goes from the dock straight to its brush. It can call `VRTX_DOCK_RESTORE_PENDING` when it is done at the brush (before it pushes the retract back); otherwise VRTX goes back after the prime. `0` (default) = back to the print first. |
| `lane_guard` | `1` = a carriage that is between the first entry step and the docks goes straight out to the line of that step first, then sideways. For `keep` / `lift`, where the paths are the only clearance. `0` (default) = straight to the first step. |
| `approach` | Default entry path for all docks, see [Paths](#paths) |
| `pickup_in`, `dropoff_in` | Own entry path for a pickup and for a drop-off. Empty means: use `approach`. |
| `pickup_out`, `dropoff_out` | Default exit paths. Empty means: walk the entry path of the same action backwards. |

**Per tool (`_VRTX_DOCK_T0` … `_VRTX_DOCK_T9`):** `taught`, `park_x`, `park_y`, `park_z` (not used with `z_mode: keep` or `lift`), and optional own `approach`, `pickup_in`, `dropoff_in`, `pickup_out`, `dropoff_out` (leave empty to use the shared ones).

### Teach a dock

With a tool standing in its dock and the carriage free:

1. `G28`, then jog the carriage by hand in Mainsail (small steps near the end) until the coupling sits fully seated on the tool.
2. `VRTX_DOCK_TEACH T=0`. The current carriage position is stored for now and the lines to keep it are printed in the console.
3. Paste those lines into `[gcode_macro _VRTX_DOCK_T0]` in section 7 of `VRTX/vrtx.cfg`. (`SAVE_CONFIG` does not store these, they are plain macro variables. Without pasting, the value is lost at the next restart.)

Docks in an even row: teach one, then `VRTX_DOCK_FILL FROM=0 TO=5 DX=45` calculates T1 to T5 at 45 mm spacing. The numbers are computed, not measured, check each dock with the next step.

### Check a dock without a tool change

```
ENTER_DOCKING_MODE
VRTX_DOCK_GOTO T=2 WHERE=stage     # carriage stops just before the dock, look at the alignment
VRTX_DOCK_GOTO T=2 WHERE=park      # slow move to the dock position (MODE=dropoff drives the drop-off entry path)
VRTX_DOCK_LEAVE T=2 MODE=pickup    # walk out as a pickup would
EXIT_DOCKING_MODE
```

Adjust with `VRTX_DOCK_SET T=2 PARK_X=101.2 PARK_Y=280.4` until it is right (valid until restart), then paste the final numbers into the file. `VRTX_DOCK_GOTO` starts from free space: it first goes up to `safe_z` and over to the first approach step. Do not start it with the carriage seated in a dock, use `VRTX_DOCK_LEAVE` first.

### Before the first real tool change

1. `VRTX_DOCK_CHECK` is clean.
2. `VRTX_DOCK_PICKUP T=0 DRY=1` and `VRTX_DOCK_DROPOFF T=0 DRY=1` print every move. Read them.
3. Put the speeds at about half of what you want in the end. Run `T0` with your hand on the emergency stop and watch the carriage. (`ENTER_DOCKING_MODE` followed by klipper-toolchanger's `TEST_TOOL_DOCKING` docks and picks up the current tool again, if you prefer that.)
4. Then `T1`, `T0` back and forth, then the other tools, then raise the speeds step by step.

## Tool switches

Two kinds of switch, both read as `[gcode_button]` so Klipper and Kalico treat them the same. Wire them so the button is **pressed when a tool is present** (put `!` in front of the pin if yours works the other way round).

```
# In your board file, or in section 6 of vrtx.cfg (see hardware.md). Any names you like.
# One switch on the carriage: pressed while any tool is attached
[gcode_button carriage_switch]
pin: ^...
press_gcode:
release_gcode:
    VRTX_DOCK_HEAD_RELEASED

# One switch per dock: pressed while that tool sits in its dock
[gcode_button dock_0]
pin: ^...
press_gcode:
```

If you named them `vrtx_head` and `vrtx_dock_t0`, `vrtx_dock_t1` ... VRTX finds them by itself. With any other names, tell VRTX in section 6 of `VRTX/vrtx.cfg`:

```
[gcode_macro _VRTX_TOOLS_SETTINGS]
variable_head_switch: 'carriage_switch'
# in tool order T0, T1, T2 ...; an empty entry = no dock switch for that tool
variable_dock_switches: 'dock_0, dock_1, dock_2'
```

Without names there VRTX looks for `vrtx_head` and `vrtx_dock_t0` … `vrtx_dock_t9`, so switches set up for an older version keep working. A switch that does not exist is skipped, so you can start with only some of them. `VRTX_DOCK_SWITCHES` prints every switch under the name VRTX looks for.

**At the dock** (what these macros do, with `check_switches: 1`):

| Moment | Dock switch | Carriage switch |
|---|---|---|
| before a pickup | tool present | empty |
| before a drop-off | empty | tool present |
| after a pickup | empty | tool present |
| after a drop-off | tool present | empty |

If a check fails the change stops with an error that says what the combination means, for example *"T3 stayed in its dock, the coupling did not take it"*, *"T3 is neither in the dock nor on the carriage, it may have dropped on the way out"* or *"both switches show the tool, check the wiring"*. Before-checks run before anything moves. After-checks run when the carriage is out of the dock, before it travels on, so the carriage stays in free space next to the dock. The step marker `v` in a pickup exit path (see [Paths](#paths)) checks the carriage switch partway out of the dock.

**Tool count.** With the carriage switch and a dock switch for every tool, every change first counts the tools the switches see: the carriage switch (one tool) plus the occupied docks must equal the number of tools. A tool that was knocked off, taken out by hand or put into the wrong dock stops the change before anything moves, and the message says how many tools the switches see and which docks are empty. `check_count: 0` in section 7 turns this check off (the checks at the dock stay). With a missing switch the count is skipped, `VRTX_DOCK_CHECK` says so.

**At startup.** Klipper starts without knowing which tool is on the carriage, and klipper-toolchanger would assume the carriage is empty. Four seconds after Klipper starts, VRTX reads the switches: a tool on the carriage with exactly one empty dock is that tool, no tool on the carriage with every dock full means an empty carriage, and it tells the changer (`INITIALIZE_TOOLCHANGER`). Anything else (no switches, two empty docks, the carriage and every dock full) is reported and left alone: run `VRTX_RESUME T=<n>` when you know. `variable_auto_init: False` in `_VRTX_TOOLS_SETTINGS` turns it off.

**While printing:** continuous watching is not the job of a dock macro. `VRTX_DOCK_HEAD_RELEASED` (called from the `release_gcode` above) reports and pauses a running print if the carriage switch lets go while a tool is selected and no tool change is running. Give the switch a debounce (`debounce_delay: 0.1`) so vibration does not trigger it.

**Why not klipper-toolchanger's own `detection_pin`?** It is made for one switch per tool, so it tells the tools apart. You have one switch on the carriage, which can only say "a tool is attached", and these macros already know which tool they expect. Leave `detection_pin` out of the `[tool]` sections unless every tool has its own, and then both can be used together.

`VRTX_DOCK_SWITCHES` prints what every switch reads right now: press them by hand to test the wiring. `VRTX_DOCK_PICKUP T=n DRY=1` also prints the before-check against the current readings.

## Paths

A path is a text of steps, separated by `/`. Each step is `dx,dy,dz` in mm **relative to the dock position**, optionally followed by a speed, a check flag and an acceleration:

```
dx,dy,dz[,speed[,v[,accel]]]
```

- `speed` in mm/s, empty = the default for that kind of move.
- `accel` in mm/s², or `fast` / `slow` (the `accel_fast` / `accel_slow` settings), or `print` (the acceleration the print had). Empty = `fast` on the approach and `slow` on the way out of the dock. It needs `accel_fast` / `accel_slow` to be set, or a number.
- `v` in a pickup exit path: check right after that step that the carriage switch shows a tool. Without a carriage switch it runs `VERIFY_TOOL_DETECTED` instead, which does nothing when the tools have no detection pin.
- The last move of an entry path goes to the dock position itself, you do not write it.
- The **first entry step must be in free space** where the carriage can come down from `safe_z` (with `z_mode: keep`: where it can travel to from the print).
- Which entry path is used: for a pickup the dock's own `pickup_in`, else the shared `pickup_in`, else the dock's own `approach`, else the shared `approach`. A drop-off the same with `dropoff_in`. Empty everywhere is an error that `VRTX_DOCK_CHECK` reports.
- If an exit path is empty (the dock's own and the shared one), the entry path of the same action is walked backwards (speeds in the entry path are ignored on the way out).
- Why separate entry paths: some docks are entered differently for the two actions, e.g. a drop-off that comes in beside the dock and slides sideways onto it, while a pickup goes in straight and slides out sideways. The two paths then have different last steps, so the carriage never runs into the tool it just left.

The default `0,-25,0/0,-5,0` means: stand 25 mm in front of the dock (lower Y), go to 5 mm in front, then slide in. Examples for other dock layouts (from above, sideways, lift-out, tool check partway, separate pickup and drop-off paths, bed-Z printers) are in [`dock_layouts.md`](dock_layouts.md).

## Printers whose bed moves in Z

On a printer where the bed, not the toolhead, moves in Z (docks at the front, nothing to lift over), the carriage cannot go "up to a safe height". Set

```
variable_z_mode: 'keep'
```

in part 1 of section 7. Then **no dock move has a Z part**: the macros do not go to `safe_z`, not to `park_z + dz` of a step, and the move back to the print position has no Z either. Z stays wherever it is. This also means:

- `park_z`, `safe_z` and the third number (`dz`) of every step are ignored and not range-checked. Keep writing `0` for `dz`, the step format does not change.
- `VRTX_DOCK_TEACH` does not store a `park_z`, `VRTX_DOCK_FILL` ignores `DZ`.
- After a failed check (see below) there is no slow lift to `safe_z` either: the carriage stays where it is.
- All the geometry is in X and Y, so put the safe lane into the paths: make the first step of every path a point on a lane that is clear of the docks and tools (for docks at the front: some mm behind the dock row), and make sure the straight move from the print position to that first step and the one back from the last step stay on the clear side of it. `variable_lane_guard: 1` does the first half for you: a carriage that is between the lane and the docks (a print near the dock edge of the bed) first goes straight out to the lane, then along it.

If the bed must first drop away from the docks or the tools (low layers on a printer whose bed edge or print would come too close to the hanging tool), use

```
variable_z_mode: 'lift'
```

instead. Before the dock moves Z goes up to `safe_z` when it is lower (the bed goes down; above `safe_z` nothing moves), the dock steps have no Z part, and at the end Z goes back to the print Z after X and Y, the same order as on a toolhead-Z printer. As with `keep`, `park_z` and `dz` are not used and `VRTX_DOCK_TEACH` stores no `park_z`; `safe_z` is range-checked. After a failed check the carriage is lifted to `safe_z` slowly, like with `absolute`.

Above `safe_z` (high layers) `lift` does not move Z, so the way back to the print comes in sideways at the print Z (plus the slicer's Z hop). On a prime tower that is where the nozzle may meet what is left on its edge. `variable_lift_min: 2` lifts at least 2 mm above the print Z before the dock moves (taken from the Z the change goes back to, so a drop-off followed by a pickup lifts once), and the way back then comes in 2 mm above the print and goes down straight.

Two more settings help on such printers, both off by default:

- `variable_lane_guard: 1` (see above) for prints near the dock edge of the bed.
- `variable_prime_before_restore: 1` if your `prime_macro` primes over a brush on the first use of a tool (`first_prime`). Without it a pickup first goes back to the print, then the prime macro travels to the brush and back again. With it the pickup leaves the carriage at the dock lane, the prime macro goes from there to the brush, and the way back to the print follows the prime. A prime macro that wants to push the toolchange retract back at the print position calls `VRTX_DOCK_RESTORE_PENDING` after the wipe and pushes afterwards:

  ```
  [gcode_macro MY_BRUSH_PRIME]
  gcode:
      {% set ts = printer["gcode_macro _VRTX_TOOLS_SETTINGS"] %}
      {% set length = params.LENGTH|float %}
      SAVE_GCODE_STATE NAME=my_prime
      G90
      M83
      {% if length <= ts.retract|float + 0.01 %}
          # an ordinary change: only the retract, pushed back where the nozzle is
          G1 E{length} F{ts.unretract_speed|float * 60}
      {% else %}
          # first use: to the brush, prime, retract, wipe, back, push the retract back
          G1 X... Y... F12000
          G1 E{length} F{params.SPEED|float * 60}
          G1 E-{ts.retract|float} F{ts.retract_speed|float * 60}
          # ... wipe moves ...
          VRTX_DOCK_RESTORE_PENDING
          G90
          M83
          G1 E{ts.retract|float} F{ts.unretract_speed|float * 60}
      {% endif %}
      RESTORE_GCODE_STATE NAME=my_prime MOVE=0
  ```

  `VRTX_PRIME` calls the macro for every change that has a retract to push back, so the first branch keeps the ordinary changes at the print position. If the macro does not call `VRTX_DOCK_RESTORE_PENDING` (or the prime is skipped because the nozzle is cold), VRTX goes back after the prime. VRTX waits for the nozzle temperature (`prime_wait`) before it calls the macro, i.e. at the dock lane in this case.

- klipper-toolchanger's own `t_command_restore_axis` defaults to `XYZ`. With `keep` the Z it restores is the Z it already has, so nothing should move, but `XY` says what you mean. I have not tried this on a real printer.
- `z_mode` only changes the **dock** moves. `VRTX_CALIBRATE` and the Z probing of the tool offsets still move the nozzle in Z the way a toolhead-Z printer does, so they are not set up for a bed-Z printer yet.

## Speed and acceleration

`accel_fast` and `accel_slow` (section 7 of `vrtx.cfg`, mm/s², 0 = do not touch) set the acceleration of the dock moves, the way fast Voron toolchanger configs do: free travel, the approach and the way back to the print at `accel_fast`, the last move into the dock and the moves out of it at `accel_slow`. A path step can choose its own with the sixth field (see [Paths](#paths)). The value never goes above the acceleration that was set when the change began, and that acceleration is put back at the end, also after a failed change. The `DRY=1` plan shows the acceleration of every step.

`travel_accel` sets the acceleration of the two free moves that are not part of a path: the lift to `safe_z` before the dock moves and the way back to the print afterwards (`fast` by default, i.e. `accel_fast`). `print` keeps the acceleration the print had, which suits printers whose dock moves were tuned that way; `slow` or a number in mm/s² work too. `print` is also accepted in the accel field of a path step, for the travel steps of a path.

## When a change fails during a print

Any G-code error makes klipper-toolchanger forget the mounted tool, and during a print an error in a macro also ends the print (Klipper's `virtual_sdcard` cancels it). To give you the chance to fix a tool by hand, VRTX does not raise errors from its own checks while a print runs inside a `T0` ... `T9` change. It records the failure, skips what is left of the docking, lifts the carriage to a clear height (slowly) and then **pauses the print** (`PAUSE`, a prompt with a *Recover and resume* button, a message in the console, and a call to `variable_error_notify` if you set one, for a message to your phone).

Then:

1. Fix the cause by hand. Seat the tool or put it back in its dock. The console message says what was found. VRTX does not carry the tool back over the part itself after a failed check. One move it cannot prevent: klipper-toolchanger moves to the print position at the end of every change (`t_command_restore_axis`, default `XYZ`), and does so also after a failed one. VRTX keeps the slow acceleration for that move; a tool that is half coupled still travels with it, so keep a hand near the stop on the first tests.
2. Run `VRTX_RESUME` (or press the button). It reads the switches to find the tool on the carriage (or use `T=<n>` when they cannot tell), repairs the changer, redoes the change to the tool the print wanted, primes the nozzle if a retract was pending (while still paused, so a `prime_macro` may go to a brush: `RESUME` then moves back to the saved position by itself) and `RESUME`s. `VRTX_RESUME RESUME=0` only repairs the changer.

**The Resume button.** After a failed change klipper-toolchanger believes the new tool is mounted. A plain `RESUME` (the big button in Mainsail, Fluidd and KlipperScreen) would continue the print with the wrong tool and offsets. Make it refuse until `VRTX_RESUME` has repaired the changer:

- With Mainsail or Fluidd (their client macros define `RESUME`): use their hook. In your `printer.cfg`:

  ```
  [gcode_macro _CLIENT_VARIABLE]
  variable_user_resume_macro: "VRTX_RESUME_GUARD"
  ```

  It runs first in their `RESUME`, before anything moves. If `user_resume_macro` already names a hook macro of your own, put `VRTX_RESUME_GUARD` on the first line of that macro instead; `VRTX_CHECK` looks into it. This does not touch `mainsail.cfg` (a link into `~/mainsail-config` that is replaced on every update). It is checked in Mainsail's `client.cfg`; Fluidd's client macros have the same variable, but I have not checked where it runs there. Do **not** include `vrtx_resume_guard.cfg` next to them: Klipper does not complain about a second `[gcode_macro RESUME]`, it merges the two and the one read last wins, so the guard would silently replace their whole `RESUME` (or be replaced by it).
- Without a `RESUME` macro of your own: include `core/vrtx_resume_guard.cfg` (section 1 of `vrtx.cfg`, a line is in the template).

`VRTX_CHECK` tells you which of these applies, and warns about the include next to the client macros. The refusal is an error from a console command only, so it does not end the paused print.

**Start macros.** A macro that called the `T` command (your `PRINT_START`) keeps running after the pause. Put `VRTX_REQUIRE_TOOL T=<n>` right after the change: it raises an error when the change failed, which stops the start cleanly before the first layer. Then `CANCEL_PRINT`, fix the tool, `VRTX_RESUME RESUME=0`. Until that runs, every `T` command stays refused and the acceleration stays low after a cancel too: `CANCEL_PRINT` does not clear the failure, only `VRTX_RESUME` does.

This needs `[pause_resume]` in `printer.cfg` and `variable_pause_on_error: True` (the default). Set `error_gcode: VRTX_TOOLCHANGE_ERROR` in `[toolchanger]` (the template does) so the failures that klipper-toolchanger finds itself are reported the same way. Honest limits:

- Only changes started by the `T0` ... `T9` commands are covered. A `SELECT_TOOL` typed by hand or called by another macro still raises a normal error.
- After a "no tool on the carriage" failure the changer cannot be repaired without a seated tool: seat one, or run `FIRMWARE_RESTART`.
- Outside a print, or with `pause_on_error: False`, a failure is a plain error as before.

## Commands

| Command | What it does |
|---|---|
| `VRTX_DOCK_PICKUP T=n` / `VRTX_DOCK_DROPOFF T=n` | Used in the `[toolchanger]` hooks. `DRY=1` prints the plan. Moves only in `changing` state. |
| `VRTX_DOCK_TEACH T=n` | Take the current carriage position as the dock position, print the lines to paste |
| `VRTX_DOCK_FILL FROM=a TO=b DX= [DY= DZ=]` | Calculate the docks of a row from one taught dock |
| `VRTX_DOCK_SET T=n PARK_X= PARK_Y= PARK_Z= TAUGHT= APPROACH= PICKUP_IN= DROPOFF_IN= PICKUP_OUT= DROPOFF_OUT=` | Change a dock until restart |
| `VRTX_DOCK_GOTO T=n WHERE=stage\|park [MODE=pickup\|dropoff]` | Drive to a dock to check it, along the pickup (default) or drop-off entry path (docking mode needed) |
| `VRTX_DOCK_LEAVE T=n MODE=pickup\|dropoff` | Walk out of a dock |
| `VRTX_DOCK_SHOW [T=n]` | Print settings and paths |
| `VRTX_DOCK_SWITCHES` | Print the current reading of the carriage switch and all dock switches |
| `VRTX_RESUME [T=n] [RESUME=0]` | After a failed change: find the tool on the carriage, repair the changer, redo the change and resume the print |
| `VRTX_DOCK_RESTORE_PENDING` | With `prime_before_restore`: go back to the print position that a pickup left for after the first prime (sideways at safe height, then down). Call it from your `prime_macro` when it is done at the brush; VRTX calls it after the prime anyway, and it does nothing when nothing is waiting |
| `VRTX_DOCK_HEAD_RELEASED` | For the `release_gcode` of the carriage switch: pause the print if a selected tool falls off |
| `VRTX_DOCK_CHECK` | Check every tool of the toolchanger: dock set up, paths valid, hooks present, which switches exist |

## How the calibration uses it

`VRTX_CALIBRATE` and the `T0` ... `T9` commands change tools through klipper-toolchanger's `SELECT_TOOL`, which runs these dock macros through the `[toolchanger]` hooks. `safe_z` here is the height for travel over the docks; `safe_z` in `_VRTX_SETTINGS` is the height for the calibration moves. Set both high enough to clear the docks, the parked tools and the Nudge.

## Limits, honestly

- **No hardware test yet.** Simulation shows the moves and the error handling, it cannot show if the coupling seats. The switch checks were tested with simulated switches that flip at the right moment, not with real ones, so wiring, polarity and debounce need checking on the machine (`VRTX_DOCK_SWITCHES`). Expect to adjust the paths, speeds and the dwell.
- **No actuator.** If your coupling needs a latch, magnet release or pin to be driven, that is outside this package.
- **No smoothing.** Moves are plain `G0` with stops at the corners, so a path with several steps stops at every corner. That is on purpose for slow, controlled docking, and `accel_fast` / `accel_slow` take most of the sting out of it, but it is slower than the rounded paths of some other toolchanger setups. Fewer steps in a path means fewer stops.
- **Dock geometry is yours.** The macros cannot know where walls and neighbouring docks are. `safe_z` and the first approach step must be in free space. Axis limits are checked, collisions are not.
- **Hot tools.** The macros do not touch heaters. Handling of hot tools in the docks (standby temperatures, waiting) is up to your setup, or VRTX's standby settings.
- **After any error** in a tool change, klipper-toolchanger forgets the mounted tool. Fix the cause, then `INITIALIZE_TOOLCHANGER T=<n>` (or without T for an empty carriage).
- **`UNSELECT_TOOL`** returns to the print position after the drop-off only because the hook passes the restore position when no new tool follows (see the hook above).

## License

GNU GPL v3, see [LICENSE](../LICENSE).
