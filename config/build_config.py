#!/usr/bin/env python3
"""Builds your mosaic.cfg from the template (config/mosaic.cfg).

    build_config.py [--calibration nudge|camera] [--tools N] [--template FILE] [-o FILE]

The installer runs this once, with your answers to its two questions. The template holds
everything; the build only switches parts of it on or off:

  * calibration blocks:   #@@ begin nudge  ...  #@@ end nudge   (same for camera)
        The block of the chosen method has one hash sign removed from the start of every
        line, so it is live. The other block stays as it is, switched off, with a banner
        that says how to switch it on.
  * #@@ each tool / dockswitch / dockmacro ... #@@ end each
        The lines in between are written once for every tool (T0 ... T<N-1>),
        {n} is the tool number, {extruder} the name of its [extruder] section.
  * #@@ note ...   a line for readers of the template, left out of your file.
  * #@@ tcommands
        The include of the T commands: all ten, or only T0 ... T<N-1> when you have
        fewer tools, so that Mainsail shows only the tool buttons you need.

The first line of the result records the answers, so a later template can be built the
same way:  # MOSAIC-INSTALL: calibration=nudge tools=4
Standard library only.
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
METHODS = ("nudge", "camera")
TITLES = {"nudge": "NUDGE", "camera": "CAMERA"}
RECORD = re.compile(r"^# MOSAIC-INSTALL: calibration=(\w+) tools=(\d+)\s*$")


def tcommands(n):
    if n >= 10:
        return ("[include core/mosaic_tools.cfg]\n"
                "# Only ten tools exist (T0 ... T9). With fewer tools Mainsail would show tool\n"
                "# buttons for tools you do not have; the installer loads only the T commands of\n"
                "# your tools then.\n")
    if n == 1:
        last, pattern = "T0", "T0"
    else:
        last, pattern = "T%d" % (n - 1), "T[0-%d]" % (n - 1)
    return ("# Only the T commands of your %d tool%s are loaded (T0%s), so that Mainsail shows\n"
            "# %s tool button%s and not ten. If you add a tool later, change the number in\n"
            "# the second line (T[0-%d] = T0 to T%d), or replace both lines with\n"
            "#   [include core/mosaic_tools.cfg]\n"
            "# to load all ten T commands.\n"
            "[include core/mosaic_tools_core.cfg]\n"
            "[include core/t_commands/%s.cfg]\n"
            % (n, "" if n == 1 else "s", "" if n == 1 else " ... " + last,
               "one" if n == 1 else str(n), "" if n == 1 else "s",
               max(n, 2) - 1, max(n, 2) - 1, pattern))


def build(template, calibration, tools):
    lines = template.split("\n")
    out = []
    i = 0
    seen = set()
    while i < len(lines):
        line = lines[i]
        if line.startswith("#@@ note"):
            i += 1          # a note for readers of the template, not part of your file
            continue
        m = re.match(r"^#@@ (begin|end|each|tcommands)(?: (\w+))?\s*$", line)
        if not m:
            if line.startswith("#@@"):
                raise SystemExit("unknown marker: " + line)
            out.append(line)
            i += 1
            continue
        kind, name = m.group(1), m.group(2)
        if kind == "tcommands":
            out.extend(tcommands(tools).rstrip("\n").split("\n"))
            i += 1
        elif kind == "begin":
            if name not in METHODS:
                raise SystemExit("unknown block: " + line)
            j = i + 1
            while not re.match(r"^#@@ end %s\s*$" % name, lines[j]):
                j += 1
            body = lines[i + 1:j]
            on = name == calibration
            seen.add(name)
            title = TITLES[name]
            if on:
                out.append("# ------ %s calibration: ON (chosen at the installation) ------" % title)
            else:
                other = TITLES[[x for x in METHODS if x != name][0]]
                out.append("# ------ %s calibration: OFF. To use it, remove ONE hash sign from the start of every line" % title)
                out.append("# ------ up to the line 'end of %s calibration', and put a hash sign in front of every line of the" % title)
                out.append("# ------ %s blocks. Such blocks are in sections 1, 2 and 3. Then restart Klipper. ------" % other)
            for b in body:
                if on:
                    if b.strip() == "":
                        out.append(b)
                    elif b.startswith("#"):
                        out.append(b[1:])
                    else:
                        raise SystemExit("line in a calibration block does not start with #: " + b)
                else:
                    out.append(b)
            out.append("# ------ end of %s calibration ------" % title)
            i = j + 1
        elif kind == "each":
            j = i + 1
            while not re.match(r"^#@@ end each\s*$", lines[j]):
                j += 1
            body = "\n".join(lines[i + 1:j]) + "\n"
            for n in range(tools):
                out.extend(body.replace("{n}", str(n))
                               .replace("{extruder}", "extruder" if n == 0 else "extruder%d" % n)
                               .rstrip("\n").split("\n") + [""])
            i = j + 1
        else:
            raise SystemExit("marker in the wrong place: " + line)
    if seen != set(METHODS):
        raise SystemExit("template lacks a calibration block")
    text = "\n".join(out)
    return "# MOSAIC-INSTALL: calibration=%s tools=%d\n%s" % (calibration, tools, text)


def recorded(path):
    """(calibration, tools) recorded in a built file, or None."""
    try:
        with open(path) as f:
            for _ in range(5):
                m = RECORD.match(f.readline())
                if m:
                    return m.group(1), int(m.group(2))
    except OSError:
        pass
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--calibration", default="nudge", choices=METHODS)
    ap.add_argument("--tools", type=int, default=10)
    ap.add_argument("--template", default=os.path.join(HERE, "mosaic.cfg"))
    ap.add_argument("--record-of", metavar="FILE", help="print 'calibration tools' recorded in FILE and exit")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()
    if a.record_of:
        r = recorded(a.record_of)
        if r:
            print("%s %d" % r)
        return
    if not 1 <= a.tools <= 10:
        raise SystemExit("--tools must be between 1 and 10")
    with open(a.template) as f:
        text = build(f.read(), a.calibration, a.tools)
    if a.output:
        with open(a.output, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
