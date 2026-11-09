#!/usr/bin/env python3
"""
a1tool.py - build helper for ca65/ld65 projects on the Apple 1.

One file, five subcommands; the Makefile calls each with one line:

  woz      .bin -> Woz Monitor lines "7800: A9 00 ..." to paste into the monitor
  info     da65 info file: labels, ROM symbols, data RANGEs from the map
  report   build summary: run/load range, size, segments
  abslist  ca65 listing with segment-relative addresses ("000012r") replaced
           by the real addresses from the ld65 map
  help     list the "## " documented targets of a Makefile

Run "a1tool.py <command> --help" for the options of each.

Shared parsing (addresses, the ld65 map and label files) lives in one place
below, so every command reads the files the same way. Errors stop with
"a1tool: file:line: message" and a non-zero exit code, so make stops too.

Standard library only; Python 3.6 or later (macOS ships 3.9).
"""

import argparse
import io
import os
import re
import sys


# ===========================================================================
# shared helpers
# ===========================================================================

def fail(msg):
    """Print 'a1tool: message' and stop with exit code 1."""
    sys.exit("a1tool: " + msg)


def parse_addr(text, where, limit=0xFFFF):
    """Plain hex ('C800', '00C800') -> int, checked against limit.
    The Makefile already strips $ / 0x, so plain hex is all we accept."""
    if not re.fullmatch(r"[0-9A-Fa-f]{1,6}", text):
        fail("%s: bad hex value '%s' (plain hex expected, e.g. C800)" % (where, text))
    value = int(text, 16)
    if value > limit:
        fail("%s: $%X is above $%X" % (where, value, limit))
    return value


def read_lines(path):
    """Yield (line_number, line) from a text file; clean error if missing.
    latin-1 decodes any byte, so odd characters never crash the tool."""
    try:
        with open(path, encoding="latin-1") as f:
            for number, line in enumerate(f, start=1):
                yield number, line.rstrip("\r\n")
    except OSError as e:
        fail("cannot read %s: %s" % (path, e.strerror))


def read_bin(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except OSError as e:
        fail("cannot read %s: %s" % (path, e.strerror))


def write_output(path, text):
    """Write all at once, only after everything succeeded: a failed run
    never leaves a half-written file that make would think is current."""
    if path:
        with open(path, "w") as f:
            f.write(text)
    else:
        sys.stdout.write(text)


# ===========================================================================
# ld65 map file
# ===========================================================================

class Map:
    """The two tables we need from an ld65 map file (ld65 -m):

    Modules list:                      -> which part of a segment each .o got
    -------------
    build/apple1_hello.o:
        CODE              Offs=000000  Size=000015  Align=00001  Fill=0000
        RODATA            Offs=000000  Size=00000E  Align=00001  Fill=0000

    Segment list:                      -> where each segment ended up
    -------------
    Name                   Start     End    Size  Align
    ----------------------------------------------------
    CODE                  000280  000294  000015  00001
    RODATA                000295  0002A2  00000E  00001
    """

    def __init__(self, path):
        self.path = path
        self.segments = []          # [(name, start, end, size)] in map order
        self.seg_start = {}         # name -> start
        self.modules = {}           # module path -> {segment: offset}
        self._parse()

    def _parse(self):
        section = None
        dashes = 0
        module = None
        for number, line in read_lines(self.path):
            where = "%s:%d" % (self.path, number)

            # a title line at column 0 starts a new section
            if line.endswith(":") and not line.startswith(" ") and line[:-1] in (
                    "Modules list", "Segment list"):
                section, dashes = line[:-1], 0
                continue
            if section is None:
                continue
            if line.startswith("-"):
                dashes += 1
                continue

            if section == "Modules list":
                if not line.strip():
                    if dashes and self.modules:
                        section = None      # blank line after the list: done
                    continue
                if not line.startswith(" "):
                    module = line.rstrip(":").strip()   # "build/x.o:" or "lib(x.o):"
                    self.modules.setdefault(module, {})
                    continue
                m = re.match(r"\s+(\S+)\s+Offs=([0-9A-Fa-f]+)", line)
                if m and module is not None:
                    self.modules[module][m.group(1)] = parse_addr(m.group(2), where)
                continue

            if section == "Segment list":
                if dashes < 2:              # still in the header
                    continue
                fields = line.split()
                if not fields:              # blank line ends the table
                    section = None
                    continue
                if len(fields) < 4:
                    fail("%s: unexpected segment line '%s'" % (where, line))
                name = fields[0]
                start, end, size = (parse_addr(f, where) for f in fields[1:4])
                self.segments.append((name, start, end, size))
                self.seg_start[name] = start

        if not self.segments:
            fail("%s: no 'Segment list:' table found -- is this an ld65 map file?" % self.path)

    def module_offsets(self, objname):
        """Segment offsets for one object file, matched on its file name
        (the map may list it as 'build/x.o'). Unknown -> all offsets 0."""
        base = os.path.basename(objname)
        for module, offsets in self.modules.items():
            if os.path.basename(module) == base:
                return offsets
        return {}


# ===========================================================================
# woz
# ===========================================================================

def cmd_woz(args):
    data = read_bin(args.bin)
    load = parse_addr(args.load, "--load")
    if load + len(data) > 0x10000:
        fail("%s: %d bytes at $%04X run past $FFFF" % (args.bin, len(data), load))
    lines = []
    for i in range(0, len(data), args.cols):
        chunk = data[i:i + args.cols]
        lines.append("%04X: %s" % (load + i, " ".join("%02X" % b for b in chunk)))
    write_output(args.output, "\n".join(lines) + "\n")


# ===========================================================================
# info  (da65 info file)
# ===========================================================================

class Labels:
    """Ordered (name, addr, comment) list. First one wins per address and
    per name, because da65 refuses duplicates."""

    def __init__(self):
        self.items, self.addrs, self.names = [], set(), set()

    def add(self, name, addr, comment=""):
        if addr in self.addrs or name in self.names:
            return
        self.addrs.add(addr)
        self.names.add(name)
        self.items.append((name, addr, comment))


def read_lbl(path, labels):
    """ld65 -Ln file: 'al 000280 ._start'. Linker names (__X__) skipped."""
    for number, line in read_lines(path):
        f = line.split()
        if len(f) == 3 and f[0] == "al":
            name = f[2].lstrip(".")
            if not name.startswith("__"):
                labels.add(name, parse_addr(f[1], "%s:%d" % (path, number)))


EQUATE = re.compile(r"^\s*([A-Za-z_]\w*)\s*:?=\s*\$([0-9A-Fa-f]+)\s*$")


def read_sym(path, labels):
    """Equates 'NAME = $hhhh ; comment' or 'NAME := $hhhh'. Nothing else."""
    for number, line in read_lines(path):
        code, _, comment = line.partition(";")
        m = EQUATE.match(code)
        if m:
            labels.add(m.group(1), parse_addr(m.group(2), "%s:%d" % (path, number)),
                       comment.strip())


def quote(text):
    """Make text safe inside a da65 "string"."""
    return text.replace('"', "'").replace("\\", "/")


def cmd_info(args):
    start = parse_addr(args.start, "--start")
    datasegs = args.datasegs.split()

    labels = Labels()
    read_lbl(args.lbl, labels)          # 1st: program labels
    for path in args.sym:               # 2nd: equates, in the order given
        read_sym(path, labels)
    themap = Map(args.map)

    out = io.StringIO()
    out.write("GLOBAL {\n")
    out.write('\tinputname\t"%s";\n' % args.bin)
    out.write("\tstartaddr\t$%04X;\n" % start)
    out.write('\tcpu\t\t"%s";\n' % args.cpu)
    out.write("\tcomments\t4;\n};\n\n")

    for name, addr, comment in labels.items:
        out.write('LABEL { name "%s"; addr $%04X;' % (name, addr))
        if comment:
            out.write(' comment "%s";' % quote(comment))
        out.write(" };\n")
    out.write("\n")

    data = [(n, s, e) for n, s, e, size in themap.segments if n in datasegs and size > 0]
    if args.ranges:
        out.write("# hand-written ranges\n")
        out.write("\n".join(line for _, line in read_lines(args.ranges)) + "\n")
    elif data:
        out.write("# data ranges from the linker map (segments: %s)\n" % " ".join(datasegs))
        # no 'name' attribute: it would add a second label at the start
        # address and clash with the program's own label (e.g. 'text')
        for name, s, e in data:
            out.write("RANGE { start $%04X; end $%04X; type %s; };   # %s\n"
                      % (s, e, args.rangetype, name))
    else:
        out.write('# no data ranges: put strings/tables in .segment "RODATA" (or DATA),\n')
        out.write("# or write RANGE blocks in a .ranges file next to the source\n")

    write_output(args.output, out.getvalue())


# ===========================================================================
# report
# ===========================================================================

def cmd_report(args):
    size = len(read_bin(args.bin))
    origin = parse_addr(args.origin, "--origin")
    monload = parse_addr(args.monload, "--monload")
    themap = Map(args.map)

    def span(start):                     # last byte; size 0 -> start
        return start + max(size, 1) - 1

    print()
    print("  ---- %s ----" % args.name)
    print("  run    $%04X-$%04X   (ORIGIN)" % (origin, span(origin)))
    print("  load   $%04X-$%04X   (MONLOAD, .woz)" % (monload, span(monload)))
    print("  size   %d bytes = $%04X" % (size, size))
    if span(origin) > 0xFFFF:
        print("  WARNING: code runs past $FFFF")
    if span(monload) > 0xFFFF:
        print("  WARNING: .woz load runs past $FFFF")
    print("  segments:")
    for name, s, e, sz in themap.segments:
        print("    %-10s $%04X-$%04X  %5d bytes" % (name, s, e, sz))
    print("  start  %04XR on the Woz Monitor" % origin)
    print()


# ===========================================================================
# abslist
# ===========================================================================

# A ca65 listing line, e.g.
#   "000012r 1  A9 FF        continue:   lda #$FF"
#    ^^^^^^ offset (6 hex)   ^ source text starts at column 24
#          ^ 'r' = relocatable (segment-relative), ' ' = absolute (.org)
#            ^ include depth (1 = main file)
LST_LINE = re.compile(r"^([0-9A-Fa-f]{6})([r ]) (\d+)")
BYTES_COL = 11      # hex bytes field: columns 11-23 ("rr" = filled in by ld65)
SRC_COL = 24

# ".segment "NAME"" and the ca65 shorthands; comment removed before matching
SEG_DIRECTIVE = re.compile(r'^\s*(?:\w+:)?\s*\.segment\s+"(\w+)"', re.I)
SEG_SHORT = re.compile(r"^\s*(?:\w+:)?\s*\.(code|rodata|data|bss|zeropage)\b", re.I)


def fill_rr(line, offset, data):
    """Replace the 'rr' placeholders in the bytes field with the real bytes
    from the binary (offset = position of the line's first byte in it)."""
    field = line[BYTES_COL:SRC_COL]
    tokens = field.split()
    if "rr" not in tokens:
        return line
    for i, t in enumerate(tokens):
        if t == "rr" and 0 <= offset + i < len(data):
            tokens[i] = "%02X" % data[offset + i]
    return line[:BYTES_COL] + " ".join(tokens).ljust(len(field)) + line[SRC_COL:]


def cmd_abslist(args):
    themap = Map(args.map)
    obj = args.obj or os.path.splitext(os.path.basename(args.lst))[0] + ".o"
    offsets = themap.module_offsets(obj)
    data = read_bin(args.bin) if args.bin else None
    origin = parse_addr(args.origin, "--origin") if args.origin else None
    if (data is None) != (origin is None):
        fail("abslist: --bin and --origin go together")

    out = io.StringIO()
    segment = "CODE"                     # ca65 starts every file in CODE
    for number, line in read_lines(args.lst):
        m = LST_LINE.match(line)
        if m and m.group(2) == "r":
            if segment not in themap.seg_start:
                fail("%s:%d: segment %s is not in %s (empty or not linked?)"
                     % (args.lst, number, segment, args.map))
            addr = (themap.seg_start[segment] + offsets.get(segment, 0)
                    + int(m.group(1), 16))
            line = "%06X " % addr + line[7:]      # same width: 'r' becomes ' '
            if data is not None:
                line = fill_rr(line, addr - origin, data)

        # ca65 prints the address *before* a line executes, so the segment
        # switch applies from the next line on
        if m:
            src = line[SRC_COL:].split(";", 1)[0]
            d = SEG_DIRECTIVE.match(src) or SEG_SHORT.match(src)
            if d:
                segment = d.group(1).upper()
        out.write(line + "\n")

    write_output(args.output, out.getvalue())


# ===========================================================================
# help
# ===========================================================================

def cmd_help(args):
    """Print 'target: ... ## text' lines of the Makefile(s) as a table."""
    pattern = re.compile(r"^([A-Za-z_.-]+):.*?##\s+(.*)$")
    for path in args.makefiles:
        for _, line in read_lines(path):
            m = pattern.match(line)
            if m:
                print("  %-10s %s" % m.groups())


# ===========================================================================
# command line
# ===========================================================================

def main():
    p = argparse.ArgumentParser(description="Build helper for ca65/ld65 on the Apple 1.")
    sub = p.add_subparsers(dest="command")
    sub.required = True

    s = sub.add_parser("woz", help="binary -> Woz Monitor lines")
    s.add_argument("--bin", required=True)
    s.add_argument("--load", required=True, help="address the lines start at, plain hex")
    s.add_argument("--cols", type=int, default=8, help="bytes per line (default 8)")
    s.add_argument("-o", "--output")
    s.set_defaults(func=cmd_woz)

    s = sub.add_parser("info", help="da65 info file")
    s.add_argument("--bin", required=True, help="binary name written into the info file")
    s.add_argument("--start", required=True, help="load address, plain hex")
    s.add_argument("--cpu", default="6502")
    s.add_argument("--lbl", required=True, help="ld65 -Ln label file")
    s.add_argument("--map", required=True, help="ld65 -m map file")
    s.add_argument("--sym", nargs="*", default=[], help="sources/includes with equates")
    s.add_argument("--datasegs", default="RODATA DATA")
    s.add_argument("--rangetype", default="TextTable")
    s.add_argument("--ranges", help="hand-written RANGE file (replaces the map ranges)")
    s.add_argument("-o", "--output")
    s.set_defaults(func=cmd_info)

    s = sub.add_parser("report", help="build summary")
    s.add_argument("--name", required=True)
    s.add_argument("--bin", required=True)
    s.add_argument("--map", required=True)
    s.add_argument("--origin", required=True, help="plain hex")
    s.add_argument("--monload", required=True, help="plain hex")
    s.set_defaults(func=cmd_report)

    s = sub.add_parser("abslist", help="ca65 listing with absolute addresses")
    s.add_argument("--lst", required=True, help="ca65 -l listing")
    s.add_argument("--map", required=True, help="ld65 -m map file")
    s.add_argument("--obj", help="object file name in the map (default: from --lst)")
    s.add_argument("--bin", help="linked binary: fill in 'rr' bytes (needs --origin)")
    s.add_argument("--origin", help="address of the binary's first byte, plain hex")
    s.add_argument("-o", "--output")
    s.set_defaults(func=cmd_abslist)

    s = sub.add_parser("help", help="list documented Makefile targets")
    s.add_argument("makefiles", nargs="+")
    s.set_defaults(func=cmd_help)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
