#!/usr/bin/env python3
"""Writes <site>/update.json: the list of every file of the game with its SHA-256.
The PC and Android apps carry a copy of it; when they have Wi-Fi they download the new one from the web page and fetch only
the files whose hash changed (see apps/desktop/main.js and webshim/html5/echo-update.js). usage: make_update_manifest.py <site dir> <version>"""
import hashlib, json, os, sys, time

site, version = sys.argv[1], sys.argv[2]
files = {}
for root, _, names in os.walk(site):
    for name in names:
        path = os.path.join(root, name)
        rel = os.path.relpath(path, site).replace(os.sep, '/')
        if rel == 'update.json':
            continue
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        files[rel] = {'h': h.hexdigest(), 's': os.path.getsize(path)}

with open(os.path.join(site, 'update.json'), 'w') as f:
    json.dump({'version': version, 'built': int(time.time()), 'files': files}, f, separators=(',', ':'))
print('update.json:', len(files), 'files,', sum(v['s'] for v in files.values()) // (1 << 20), 'MB')
