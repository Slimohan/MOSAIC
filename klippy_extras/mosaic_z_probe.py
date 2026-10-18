# Z offset switch of the MOSAIC camera module
#
# Adapted from RatOS z_offset_probe.py, Copyright (C) 2017-2021 Kevin O'Connor
# <kevin@koconnor.net> and Helge Keck <HelgeKeck@hotmail.com>. This standalone
# version for Klipper and Kalico does not depend on Klipper's probe module, so
# it can live next to a Beacon, Cartographer or any other [probe]. It drives a
# plain switch (the MOSAIC Z switch) that the nozzle presses from above and
# reports the toolhead Z at which it triggers.
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Config:
#   [mosaic_z_probe]
#   pin: ^PA3                  # switch pin
#   x_offset: 37.5             # switch centre relative to the camera centre
#   y_offset: 0
#   speed: 3                   # probing speed in mm/s
#   lift_speed: 10
#   samples: 5
#   sample_retract_dist: 2
#   samples_result: median     # median or average
#   samples_tolerance: 0.02    # max spread of the samples in mm
#   samples_tolerance_retries: 3
#   max_travel: 15             # how far down to look for the switch in mm
#
# Commands:
#   MOSAIC_Z_PROBE [PROBE_SPEED=] [LIFT_SPEED=] [SAMPLES=] [SAMPLE_RETRACT_DIST=]
#                [SAMPLES_TOLERANCE=] [SAMPLES_TOLERANCE_RETRIES=]
#                [SAMPLES_RESULT=] [MAX_TRAVEL=] [SAMPLES_DROP=]
#   MOSAIC_Z_QUERY             state of the switch
#   MOSAIC_Z_PROBE_ACCURACY    repeatability test at the current XY position

import logging

HINT_TIMEOUT = """
If the switch did not trigger, the nozzle may not be above it, or max_travel is
too small, or the Z axis minimum position does not allow enough travel
(the Z minimum position can be negative).
"""


class MosaicZProbe:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        self.gcode = self.printer.lookup_object("gcode")
        self.x_offset = config.getfloat("x_offset", 0.0)
        self.y_offset = config.getfloat("y_offset", 0.0)
        self.speed = config.getfloat("speed", 3.0, above=0.0)
        self.lift_speed = config.getfloat("lift_speed", self.speed, above=0.0)
        self.sample_count = config.getint("samples", 3, minval=1)
        self.sample_retract_dist = config.getfloat("sample_retract_dist", 2.0,
                                                   above=0.0)
        self.samples_result = config.getchoice(
            "samples_result", {"median": "median", "average": "average"},
            "median")
        self.samples_tolerance = config.getfloat("samples_tolerance", 0.05,
                                                 minval=0.0)
        self.samples_retries = config.getint("samples_tolerance_retries", 3,
                                             minval=0)
        self.max_travel = config.getfloat("max_travel", 15.0, above=0.0)
        self.last_z_result = 0.0
        self.last_range = 0.0
        self.last_retries = 0
        self.last_state = False
        # The switch is a plain endstop that stops the Z steppers
        ppins = self.printer.lookup_object("pins")
        self.mcu_endstop = ppins.setup_pin("endstop", config.get("pin"))
        self.printer.register_event_handler("klippy:mcu_identify",
                                            self._handle_mcu_identify)
        self.gcode.register_command("MOSAIC_Z_PROBE", self.cmd_MOSAIC_Z_PROBE,
                                    desc=self.cmd_MOSAIC_Z_PROBE_help)
        self.gcode.register_command("MOSAIC_Z_QUERY", self.cmd_MOSAIC_Z_QUERY,
                                    desc=self.cmd_MOSAIC_Z_QUERY_help)
        self.gcode.register_command(
            "MOSAIC_Z_PROBE_ACCURACY", self.cmd_MOSAIC_Z_PROBE_ACCURACY,
            desc=self.cmd_MOSAIC_Z_PROBE_ACCURACY_help)

    def _handle_mcu_identify(self):
        kin = self.printer.lookup_object("toolhead").get_kinematics()
        for stepper in kin.get_steppers():
            if stepper.is_active_axis("z"):
                self.mcu_endstop.add_stepper(stepper)

    # --- probing ---
    def _probe(self, speed, max_travel):
        toolhead = self.printer.lookup_object("toolhead")
        curtime = self.printer.get_reactor().monotonic()
        if "z" not in toolhead.get_status(curtime)["homed_axes"]:
            raise self.printer.command_error("Must home before probing")
        phoming = self.printer.lookup_object("homing")
        pos = toolhead.get_position()
        pos[2] = pos[2] - max_travel
        try:
            epos = phoming.probing_move(self.mcu_endstop, pos, speed)
        except self.printer.command_error as e:
            reason = str(e)
            if "Timeout during endstop homing" in reason:
                reason += HINT_TIMEOUT
            raise self.printer.command_error(reason)
        toolhead.set_position(epos)
        self.printer.lookup_object("gcode_move").reset_last_position()
        self.gcode.respond_info("MOSAIC switch at %.3f,%.3f triggered at z=%.6f"
                                % (epos[0], epos[1], epos[2]))
        return epos[:3]

    def _move(self, coord, speed):
        self.printer.lookup_object("toolhead").manual_move(coord, speed)
        self.printer.lookup_object("gcode_move").reset_last_position()

    @staticmethod
    def _mean(values):
        return sum(values) / float(len(values))

    @staticmethod
    def _median(values):
        ordered = sorted(values)
        middle = len(ordered) // 2
        if len(ordered) & 1:
            return ordered[middle]
        return (ordered[middle - 1] + ordered[middle]) / 2.0

    def run_probe(self, gcmd):
        speed = gcmd.get_float("PROBE_SPEED", self.speed, above=0.0)
        lift_speed = gcmd.get_float("LIFT_SPEED", self.lift_speed, above=0.0)
        count = gcmd.get_int("SAMPLES", self.sample_count, minval=1)
        retract = gcmd.get_float("SAMPLE_RETRACT_DIST",
                                 self.sample_retract_dist, above=0.0)
        tolerance = gcmd.get_float("SAMPLES_TOLERANCE", self.samples_tolerance,
                                   minval=0.0)
        retries_max = gcmd.get_int("SAMPLES_TOLERANCE_RETRIES",
                                   self.samples_retries, minval=0)
        method = gcmd.get("SAMPLES_RESULT", self.samples_result).lower()
        if method not in ("median", "average"):
            raise gcmd.error("SAMPLES_RESULT must be median or average")
        drop = gcmd.get_int("SAMPLES_DROP", 0, minval=0)
        max_travel = gcmd.get_float("MAX_TRAVEL", self.max_travel, above=0.0)
        toolhead = self.printer.lookup_object("toolhead")
        start = toolhead.get_position()
        xy = start[:2]
        retries = 0
        zs = []
        while len(zs) < count:
            # every sample starts from the same height
            pos = self._probe(speed, max_travel)
            if drop > 0:
                drop -= 1
                self._move(xy + [start[2]], lift_speed)
                continue
            zs.append(pos[2])
            if max(zs) - min(zs) > tolerance:
                if retries >= retries_max:
                    raise gcmd.error(
                        "MOSAIC switch samples exceed samples_tolerance "
                        "(%.4f > %.4f)" % (max(zs) - min(zs), tolerance))
                gcmd.respond_info("MOSAIC switch samples exceed tolerance, "
                                  "retrying...")
                retries += 1
                zs = []
            if len(zs) < count:
                self._move(xy + [min(pos[2] + retract, start[2])], lift_speed)
        self.last_retries = retries
        self.last_range = max(zs) - min(zs)
        return self._median(zs) if method == "median" else self._mean(zs)

    cmd_MOSAIC_Z_PROBE_help = ("Press the MOSAIC Z switch with the nozzle and "
                             "report the toolhead Z where it triggers")

    def cmd_MOSAIC_Z_PROBE(self, gcmd):
        z = self.run_probe(gcmd)
        self.last_z_result = z
        gcmd.respond_info("MOSAIC Z result is z=%.6f (sample range %.4f)"
                          % (z, self.last_range))

    cmd_MOSAIC_Z_QUERY_help = "Report whether the MOSAIC Z switch is triggered"

    def cmd_MOSAIC_Z_QUERY(self, gcmd):
        toolhead = self.printer.lookup_object("toolhead")
        print_time = toolhead.get_last_move_time()
        res = self.mcu_endstop.query_endstop(print_time)
        self.last_state = bool(res)
        gcmd.respond_info("MOSAIC Z switch: %s" % (
            "TRIGGERED" if res else "open",))

    cmd_MOSAIC_Z_PROBE_ACCURACY_help = ("Repeatability test of the MOSAIC Z "
                                      "switch at the current XY position")

    def cmd_MOSAIC_Z_PROBE_ACCURACY(self, gcmd):
        speed = gcmd.get_float("PROBE_SPEED", self.speed, above=0.0)
        lift_speed = gcmd.get_float("LIFT_SPEED", self.lift_speed, above=0.0)
        count = gcmd.get_int("SAMPLES", 10, minval=2)
        retract = gcmd.get_float("SAMPLE_RETRACT_DIST",
                                 self.sample_retract_dist, above=0.0)
        max_travel = gcmd.get_float("MAX_TRAVEL", self.max_travel, above=0.0)
        toolhead = self.printer.lookup_object("toolhead")
        start = toolhead.get_position()
        xy = start[:2]
        gcmd.respond_info("MOSAIC_Z_PROBE_ACCURACY at X:%.3f Y:%.3f Z:%.3f "
                          "(samples=%d retract=%.3f speed=%.1f)"
                          % (start[0], start[1], start[2], count, retract,
                             speed))
        zs = []
        while len(zs) < count:
            pos = self._probe(speed, max_travel)
            zs.append(pos[2])
            self._move(xy + [min(pos[2] + retract, start[2])], lift_speed)
        avg = self._mean(zs)
        sigma = (sum((z - avg) ** 2 for z in zs) / len(zs)) ** 0.5
        gcmd.respond_info(
            "MOSAIC switch accuracy: maximum %.6f, minimum %.6f, range %.6f, "
            "average %.6f, median %.6f, standard deviation %.6f"
            % (max(zs), min(zs), max(zs) - min(zs), avg, self._median(zs),
               sigma))

    def get_status(self, eventtime):
        return {"name": self.name,
                "last_query": self.last_state,
                "last_z_result": self.last_z_result,
                "last_range": self.last_range,
                "last_retries": self.last_retries,
                "x_offset": self.x_offset,
                "y_offset": self.y_offset}


def load_config(config):
    return MosaicZProbe(config)
