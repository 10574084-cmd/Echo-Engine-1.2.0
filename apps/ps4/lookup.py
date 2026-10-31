#!/usr/bin/env python3
"""Turns the numbers of a PS4 crash report (addresses relative to echo_anchor) into function names.
usage: lookup.py symbols.txt "d1 d2 d3 ..."   (symbols.txt = output of `nm -n` of the PS4 ELF)"""
import bisect
import subprocess
import sys

syms = []
anchor = None
for line in open(sys.argv[1], errors='replace'):
    parts = line.split()
    if len(parts) == 3 and parts[1] in 'tTwWiI':
        addr = int(parts[0], 16)
        syms.append((addr, parts[2]))
        if parts[2] == 'echo_anchor':
            anchor = addr
syms.sort()
addrs = [a for a, _ in syms]
deltas = sys.argv[2].split() if len(sys.argv) > 2 else []
if not deltas:
    sys.exit(0)
if anchor is None:
    print('echo_anchor not found in the symbols')
    sys.exit(0)
for d in deltas:
    try:
        target = anchor + int(d)
    except ValueError:
        continue
    i = bisect.bisect_right(addrs, target) - 1
    if i < 0:
        print(f'{d}: before the first symbol')
        continue
    name = syms[i][1]
    try:
        name = subprocess.run(['c++filt', name], capture_output=True, text=True).stdout.strip() or name
    except Exception:
        pass
    print(f'{d}: {name} +{target - syms[i][0]}')
