# Path patterns for different docks

These are patterns, not measured settings for any particular printer. They show how to describe where the carriage comes from and how it leaves. Put them into `variable_approach`, `variable_pickup_in`, `variable_dropoff_in`, `variable_pickup_out` and `variable_dropoff_out` (shared in `_MOSAIC_DOCK_SETTINGS`, or per tool). All distances are relative to the dock position of that tool (`park_x`, `park_y`, `park_z`). Always check with `DRY=1` first.

Format: `dx,dy,dz[,speed[,v]]` steps separated by `/`. The last move of the approach goes to the dock position itself.

## 1. Docks in a row at the back, slide in from the front (the default)

Dock row along X at high Y. The carriage comes from lower Y.

```
variable_approach: "0,-25,0/0,-5,0"
variable_pickup_out: ""
variable_dropoff_out: ""
```

Stands 25 mm in front, then 5 mm in front, slides in. Empty exits mean the same way back.

## 2. Docks at the front, slide in from behind

Mirror image: the carriage comes from higher Y.

```
variable_approach: "0,25,0/0,5,0"
```

## 3. Docks in a column along Y, slide in from the side

Dock column along Y at the left edge, carriage comes from higher X.

```
variable_approach: "25,0,0/5,0,0"
```

## 4. Straight down onto the dock

The carriage comes down from above. A single step above the dock; the macros travel there at `safe_z` and come down to the dock position at `engage_speed`.

```
variable_approach: "0,0,25"
```

If 25 mm above the dock is higher than `safe_z`, make sure `safe_z` is still above every tool standing in the neighbouring docks.

## 5. Slide in, lift out

The tool is held in the dock by a ledge or catch. For a pickup the carriage goes in, lifts the tool up and then out. For a dropoff it goes in, sets the tool down and leaves sideways.

```
variable_approach: "0,-25,0/0,-5,0"
variable_pickup_out: "0,0,12,6/0,-25,12"
variable_dropoff_out: "0,-25,0"
```

Pickup: after seating, rise 12 mm at 6 mm/s, then back out 25 mm at the pullout speed. Dropoff: leave straight out.

## 6. Check the tool before leaving the dock

Add `v` as the fifth field of the pickup step where the carriage switch should already show the tool:

```
variable_pickup_out: "0,0,12,6,v/0,-25,12"
```

If the switch does not show the tool there, the change stops with an error before the carriage drags anything away. Without a carriage switch it falls back to klipper-toolchanger's `VERIFY_TOOL_DETECTED`, which does nothing when the tools have no detection pin.

## 7. Different path for one dock only

Per tool section, e.g. the dock at the end of the row has a wall on the right:

```
[gcode_macro _MOSAIC_DOCK_T5]
variable_approach: "-20,-25,0/-3,-5,0"
```

Docks without their own path keep using the shared one.

## 8. Different entry for pickup and drop-off

Slide the tool onto the dock sideways: a drop-off comes in beside the dock and slides onto it, a pickup goes in straight and slides out sideways, so the carriage never pushes against the tool it just left. This example has the docks at the front of the printer, the carriage coming from higher Y, 3.2 mm of sideways slide:

```
variable_pickup_in:  "0,45,0/0,40,0/0,18,0,120,,fast"
variable_dropoff_in: "3.2,45,0/3.2,30,0/3.2,6,0,120,,fast/3.2,0,0,20,,slow"
variable_pickup_out: "3.2,0,0,20,,slow/3.2,12,0,20,v,slow/3.2,30,0,120,,fast/3.2,45,0"
variable_dropoff_out: "0,18,0,20,,slow/0,40,0,120,,fast/0,45,0"
```

A pickup stands 45 mm away from the dock (higher Y), goes straight in (the last move to the dock position is the engage move), waits, slides 3.2 mm sideways, checks the carriage switch at 12 mm, then leaves along the 3.2 mm lane. A drop-off comes along the 3.2 mm lane, and its last move (the engage move) slides onto the dock; it leaves straight back. The first step of every path is on the same lane, 45 mm from the dock row.

## 9. Printers whose bed moves in Z

Set `variable_z_mode: 'keep'` (see [docking.md](docking.md#printers-whose-bed-moves-in-z)). Then no move has a Z part, `dz` is ignored (keep writing `0`) and the paths of the example above can be used as they are. Check the plan with `MOSAIC_DOCK_PICKUP T=0 DRY=1`: the printed moves have X and Y only. If the bed has to drop away first on low layers, use `'lift'`: the plan then starts with the move up to `safe_z` and ends with the move back to the print Z, the steps in between have X and Y only.

A complete example, for five docks at the front of a bed-Z printer (dock Y -36.2, the lane 45 mm behind it), with the travel at the print acceleration and the dock moves at 2000 / 500 mm/s²:

```
variable_safe_z: 20
variable_z_mode: 'lift'
variable_lane_guard: 1
variable_travel_accel: 'print'
variable_prime_before_restore: 1
variable_travel_speed: 300
variable_approach_speed: 120
variable_engage_speed: 20
variable_pullout_speed: 20
variable_accel_fast: 2000
variable_accel_slow: 500
variable_pickup_in:  "0,45,0,,,print/0,40,0,300,,print/0,18,0,120,,fast"
variable_dropoff_in: "3.2,45,0,,,print/3.2,30,0,300,,print/3.2,6,0,120,,fast/3.2,0,0,20,,slow"
variable_pickup_out: "3.2,0,0,20,,slow/3.2,12,0,20,v,slow/3.2,30,0,120,,fast/3.2,45,0,300,,print"
variable_dropoff_out: "0,18,0,20,,slow/0,40,0,120,,fast/0,45,0,300,,print"
```

`MOSAIC_DOCK_PICKUP T=0 DRY=1` then prints: Z up to 20 only when lower, straight out to Y 8.8 when the carriage is in front of it, along the lane to the dock, in and out at the dock accelerations, and back to the print (X and Y, then Z).
