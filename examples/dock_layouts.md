# Path patterns for different docks

These are patterns, not measured settings for any particular printer. They show how to describe where the carriage comes from and how it leaves. Put them into `variable_approach`, `variable_pickup_out` and `variable_dropoff_out` (shared in `_MOSAIC_DOCK_SETTINGS`, or per tool). All distances are relative to the dock position of that tool (`park_x`, `park_y`, `park_z`). Always check with `DRY=1` first.

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

Add `v` as the fifth field of the pickup step where the pin should already show the tool:

```
variable_pickup_out: "0,0,12,6,v/0,-25,12"
```

If the pin does not show the tool there, klipper-toolchanger raises an error before the carriage drags anything away. Needs a `detection_pin` on the tools. Nothing happens when no pin is configured.

## 7. Different path for one dock only

Per tool section, e.g. the dock at the end of the row has a wall on the right:

```
[gcode_macro _MOSAIC_DOCK_T5]
variable_approach: "-20,-25,0/-3,-5,0"
```

Docks without their own path keep using the shared one.
