#!/usr/bin/env python
"""Renames the 'Italiano' language menu entry to 'Türkçe' inside a K3SysUi binary.

The language names live in .rodata as NUL-terminated strings in fixed 12-byte slots
("Italiano" + 4 NUL). "Türkçe" is 8 bytes in UTF-8, so it fits in place and no
offsets change. Works on any K3SysUi version (searches instead of using fixed offsets)
and is idempotent. Usage: patch_label.py <K3SysUi> [--revert]
"""
import sys

OLD = b"Italiano\x00\x00\x00\x00"
NEW = u"Türkçe".encode("utf-8") + b"\x00\x00\x00\x00"
assert len(OLD) == len(NEW) == 12

path = sys.argv[1]
revert = "--revert" in sys.argv[2:]
src, dst = (NEW, OLD) if revert else (OLD, NEW)

with open(path, "rb") as f:
    data = f.read()

n = data.count(src)
if n == 0:
    print("%s: nothing to do (%d occurrences of target already present)" % (path, data.count(dst)))
    sys.exit(0)

with open(path, "wb") as f:
    f.write(data.replace(src, dst))
print("%s: replaced %d occurrence(s)" % (path, n))
