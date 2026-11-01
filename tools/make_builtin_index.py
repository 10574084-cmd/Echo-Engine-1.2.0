#!/usr/bin/env python3
"""Writes builtin/index.json for the built-in mods: every folder inside the given directory is a mod, with the list of its files.
usage: make_builtin_index.py <site>/builtin"""
import json
import os
import sys

root = sys.argv[1]
mods = []
for name in sorted(os.listdir(root)):
    folder = os.path.join(root, name)
    if not os.path.isdir(folder):
        continue
    files = []
    for base, _, names in os.walk(folder):
        for n in sorted(names):
            full = os.path.join(base, n)
            rel = os.path.relpath(full, folder).replace(os.sep, '/')
            files.append({'p': rel, 's': os.path.getsize(full)})
    files.sort(key=lambda f: f['p'])
    mods.append({'name': name, 'files': files})
with open(os.path.join(root, 'index.json'), 'w') as out:
    json.dump(mods, out, separators=(',', ':'))
print('built-in mods:', [(m['name'], len(m['files'])) for m in mods])
