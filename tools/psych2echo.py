#!/usr/bin/env python3
"""psych2echo: turns a Psych Engine mod (0.7 or 1.0) into the Echo Mods structure (see ECHO_MODS.md).

usage: psych2echo.py <psych mod folder> <output folder> [--songs a,b,c] [--webp] [--json]

  --songs   only these songs (folder names of the Psych mod, e.g. "bopeebo-(pico-mix)")
  --webp    write the images of characters and stages as .webp (smaller; the game converts them back after the import)
  --json    write the data files as .json instead of .js ("export default { ... }")

What is translated: mod info, characters (all their atlases), simple stages (the sprites that a stage .lua makes with makeLuaSprite /
makeAnimatedLuaSprite), songs (audio), charts (lanes, camera and the events that Echo has), weeks and health icons.
What is not: Lua / HScript code. It is listed in the report ("legacy") so nothing is lost silently.
"""
import argparse, json, os, re, shutil, sys

# ---------------------------------------------------------------------------------------------------------------------------------
def slug(name):
    s = name.lower().replace(' ', '-')
    s = re.sub(r'[^a-z0-9\-_]', '', s)
    return re.sub(r'-+', '-', s).strip('-')

def read_json(path):
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)

def write_data(out, rel, value, as_json):
    path = os.path.join(out, rel + ('.json' if as_json else '.js'))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = json.dumps(value, indent=1, ensure_ascii=False)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text if as_json else 'export default ' + text + ';\n')

def copy_image(src_root, name, dst_root, dst_name, webp, report):
    """images/<name>.png (+ .xml / .json / .txt) -> <dst_root>/<dst_name>.png|webp ; returns True if the image exists"""
    src = os.path.join(src_root, name + '.png')
    if not os.path.exists(src):
        return False
    dst_base = os.path.join(dst_root, dst_name)
    os.makedirs(os.path.dirname(dst_base), exist_ok=True)
    if webp:
        from PIL import Image
        Image.open(src).save(dst_base + '.webp', 'WEBP', lossless=True, quality=100, method=4)
    else:
        shutil.copyfile(src, dst_base + '.png')
    for ext in ('.xml', '.json', '.txt'):
        if os.path.exists(os.path.join(src_root, name + ext)):
            shutil.copyfile(os.path.join(src_root, name + ext), dst_base + ext)
    return True

# ---------------------------------------------------------------------------------------------------------------------------------
def convert_mod_info(mod, out, as_json, report):
    pack = {}
    p = os.path.join(mod, 'pack.json')
    if os.path.exists(p):
        pack = read_json(p)
    name = pack.get('name') or os.path.basename(os.path.abspath(mod))
    info = {'id': slug(name), 'name': name, 'version': '1.0.0', 'description': pack.get('description', ''),
            'echo': '>=1.3.0', 'runsGlobally': bool(pack.get('runsGlobally', False))}
    if 'color' in pack:
        info['color'] = pack['color']
    write_data(out, 'mod', info, as_json)
    report.append('mod: ' + name)

def convert_characters(mod, out, as_json, webp, report, used):
    cdir = os.path.join(mod, 'characters')
    if not os.path.isdir(cdir):
        return
    for fn in sorted(os.listdir(cdir)):
        full = os.path.join(cdir, fn)
        if fn.endswith('.lua') or fn.endswith('.hx'):
            report.append('legacy: characters/' + fn + ' (script, not translated)')
            continue
        if not fn.endswith('.json') or not os.path.isfile(full):
            continue
        cid = fn[:-5]
        if used is not None and cid not in used:
            continue
        c = read_json(full)
        images = [i.strip() for i in str(c.get('image', 'characters/' + cid)).split(',')]
        names = []
        for img in images:
            short = img[len('characters/'):] if img.startswith('characters/') else img
            if copy_image(os.path.join(mod, 'images'), img, os.path.join(out, 'characters'), short, webp, report):
                names.append(short)
            else:
                report.append('missing image: %s (needed by character %s)' % (img, cid))
                names.append(short)
        anims = []
        for a in c.get('animations', []):
            anims.append({'name': a['anim'], 'prefix': a.get('name', a['anim']), 'fps': a.get('fps', 24),
                          'loop': bool(a.get('loop', False)), 'indices': a.get('indices', []),
                          'offset': a.get('offsets', [0, 0])})
        bar = c.get('healthbar_colors', [161, 161, 161])
        data = {'image': names if len(names) > 1 else names[0], 'scale': c.get('scale', 1), 'flipX': bool(c.get('flip_x', False)),
                'antialiasing': not c.get('no_antialiasing', False), 'icon': c.get('healthicon', cid),
                'barColor': '#%02X%02X%02X' % tuple(int(v) for v in bar[:3]), 'camera': c.get('camera_position', [0, 0]),
                'position': c.get('position', [0, 0]), 'singDuration': c.get('sing_duration', 4), 'anims': anims}
        write_data(out, 'characters/' + cid, data, as_json)
        report.append('character: ' + cid)

        icon = c.get('healthicon', cid)
        for icon_file in ('icons/icon-' + icon, 'icons/' + icon):
            if copy_image(os.path.join(mod, 'images'), icon_file, os.path.join(out, 'images', 'health-icons'), icon, False, report):
                break

LUA_SPRITE = re.compile(r"make(Animated)?LuaSprite\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*(?:,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+))?")
LUA_SCALE = re.compile(r"scaleObject\(\s*['\"]([^'\"]+)['\"]\s*,\s*(-?[\d.]+)")
LUA_ADD = re.compile(r"addLuaSprite\(\s*['\"]([^'\"]+)['\"](\s*,\s*true)?")
LUA_SCROLL = re.compile(r"setScrollFactor\(\s*['\"]([^'\"]+)['\"]\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)")
LUA_ANIM = re.compile(r"addAnimationByPrefix\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*(?:,\s*(\d+))?\s*(?:,\s*(true|false))?")

def convert_stages(mod, out, as_json, webp, report, used):
    sdir = os.path.join(mod, 'stages')
    if not os.path.isdir(sdir):
        return
    for fn in sorted(os.listdir(sdir)):
        if not fn.endswith('.json'):
            continue
        sid = fn[:-5]
        if used is not None and sid not in used:
            continue
        s = read_json(os.path.join(sdir, fn))
        layers = []
        lua = os.path.join(sdir, sid + '.lua')
        if os.path.exists(lua):
            text = open(lua, encoding='utf-8', errors='ignore').read()
            text = re.sub(r'--\[\[.*?\]\]', '', text, flags=re.S)
            text = re.sub(r'--[^\n]*', '', text)
            sprites, order = {}, []
            for m in LUA_SPRITE.finditer(text):
                sprites[m.group(2)] = {'tag': m.group(2), 'image': m.group(3), 'x': float(m.group(4) or 0), 'y': float(m.group(5) or 0),
                                       'animated': bool(m.group(1)), 'scale': 1.0, 'scroll': [1, 1], 'front': False, 'anims': []}
            for m in LUA_SCALE.finditer(text):
                if m.group(1) in sprites: sprites[m.group(1)]['scale'] = float(m.group(2))
            for m in LUA_SCROLL.finditer(text):
                if m.group(1) in sprites: sprites[m.group(1)]['scroll'] = [float(m.group(2)), float(m.group(3))]
            for m in LUA_ANIM.finditer(text):
                if m.group(1) in sprites:
                    sprites[m.group(1)]['anims'].append({'name': m.group(2), 'prefix': m.group(3), 'fps': int(m.group(4) or 24), 'loop': m.group(5) == 'true'})
            for m in LUA_ADD.finditer(text):
                if m.group(1) in sprites:
                    sprites[m.group(1)]['front'] = bool(m.group(2))
                    order.append(m.group(1))
            for tag in order:
                sp = sprites[tag]
                short = sp['image']
                if not copy_image(os.path.join(mod, 'images'), short, os.path.join(out, 'stages', 'images'), short, webp, report):
                    report.append('missing image: %s (stage %s)' % (short, sid)); continue
                layer = {'image': short, 'x': sp['x'], 'y': sp['y'], 'scale': sp['scale'], 'scroll': sp['scroll'], 'front': sp['front']}
                if sp['animated'] and sp['anims']:
                    layer['anim'] = sp['anims'][0]
                layers.append(layer)
            if re.search(r'runHaxeCode|createRuntimeShader|setSpriteShader|initLuaShader', text):
                report.append('legacy: stages/%s.lua uses code or shaders that were not translated (only its sprites)' % sid)
        stage = {'zoom': s.get('defaultZoom', 0.9), 'pixel': bool(s.get('isPixelStage', False)),
                 'bf': s.get('boyfriend', [770, 100]), 'gf': s.get('girlfriend', [400, 130]), 'dad': s.get('opponent', [100, 100]),
                 'hideGf': bool(s.get('hide_girlfriend', False)), 'layers': layers}
        for k, e in (('bfCamera', 'camera_boyfriend'), ('dadCamera', 'camera_opponent'), ('gfCamera', 'camera_girlfriend')):
            if s.get(e): stage[k] = s[e]
        write_data(out, 'stages/' + sid, stage, as_json)
        report.append('stage: %s (%d layers)' % (sid, len(layers)))

# ---------------------------------------------------------------------------------------------------------------------------------
HEY = {'bf': 'bf', 'boyfriend': 'bf', 'gf': 'gf', 'girlfriend': 'gf', 'both': 'both'}

def who_name(v):
    v = str(v).strip().lower()
    if v in ('0', 'bf', 'boyfriend', 'player'): return 'bf'
    if v in ('2', 'gf', 'girlfriend'): return 'gf'
    return 'dad'

def convert_event(name, v1, v2):
    """a Psych event -> (Echo name, args) or None when it has no Echo equivalent"""
    if name == 'Set Camera Target':
        parts = [p.strip() for p in str(v1).split(',')]
        if not parts or parts[0] == '':
            return None
        args = {'who': who_name(parts[0])}
        if len(parts) > 2:
            try: args['x'], args['y'] = float(parts[1]), float(parts[2])
            except ValueError: pass
        return 'camera.target', args
    if name == 'Camera Follow Pos':
        try: return 'camera.target', {'x': float(v1 or 0), 'y': float(v2 or 0)}
        except ValueError: return None
    if name == 'Add Camera Zoom':
        return 'camera.zoom', {'mode': 'add', 'zoom': float(v1 or 0.015), 'hud': float(v2 or 0.03)}
    if name == 'Hey!':
        who = str(v1).strip().lower()
        return 'char.hey', {'who': HEY.get(who, 'both'), 'duration': float(v2 or 0.6) if str(v2).replace('.', '').isdigit() else 0.6}
    if name == 'Play Animation':
        return 'char.anim', {'who': who_name(v2), 'anim': v1}
    if name == 'Change Character':
        return 'char.change', {'who': who_name(v1), 'to': v2}
    if name == 'Change Scroll Speed':
        try: return 'gameplay.speed', {'speed': float(v1 or 1), 'duration': float(v2 or 0)}
        except ValueError: return None
    if name == 'Screen Shake':
        try:
            d, i = [float(x) for x in str(v1).split(',')[:2]]
            return 'camera.shake', {'duration': d, 'intensity': i}
        except ValueError: return None
    return None

def convert_chart(path, events_extra):
    d = read_json(path)
    if isinstance(d.get('song'), dict): d = d['song']
    fmt = str(d.get('format', ''))
    v1 = fmt.startswith('psych_v1')
    notes, cam, bpm_events = [], [], []
    bpm = d.get('bpm', 100)
    t = 0.0
    cur = bpm
    secs = d.get('notes', [])
    for sec in secs:
        if sec.get('changeBPM') and sec.get('bpm'):
            cur = sec['bpm']
            bpm_events.append({'t': round(t, 3), 'name': 'gameplay.bpm', 'args': {'bpm': cur}})
        mh = bool(sec.get('mustHitSection'))
        who = 'gf' if sec.get('gfSection') else ('bf' if mh else 'dad')
        cam.append((t, who))
        for n in sec.get('sectionNotes', []):
            if n[1] < 0: continue
            data = int(n[1])
            if v1:
                lane = data
            else:
                lane = data % 4 + (0 if ((data < 4) == mh) else 4)
            item = {'t': n[0], 'lane': lane, 'len': n[2] if len(n) > 2 and isinstance(n[2], (int, float)) else 0}
            if len(n) > 3 and isinstance(n[3], str) and n[3]: item['type'] = n[3]
            notes.append(item)
        t += sec.get('sectionBeats', 4) * 60000.0 / cur
    events, saw_target = [], False
    raw_events = list(d.get('events', [])) + list(events_extra)
    for ev in raw_events:
        for e in ev[1]:
            conv = convert_event(e[0], e[1] if len(e) > 1 else '', e[2] if len(e) > 2 else '')
            if conv:
                events.append({'t': ev[0], 'name': conv[0], 'args': conv[1]})
                if conv[0] == 'camera.target' and 'who' in conv[1]: saw_target = True
    if not saw_target:  # classic charts: the camera follows mustHitSection
        last = None
        for ts, who in cam:
            if who != last:
                events.append({'t': round(ts, 3), 'name': 'camera.target', 'args': {'who': who}})
                last = who
    events += bpm_events
    events.sort(key=lambda e: e['t'])
    notes.sort(key=lambda n: n['t'])
    chart = {'bpm': bpm, 'speed': d.get('speed', 1), 'stage': d.get('stage', 'stage'), 'player': d.get('player1', 'bf'),
             'opponent': d.get('player2', 'dad'), 'girlfriend': d.get('gfVersion', 'gf'), 'needsVoices': bool(d.get('needsVoices', True)),
             'offset': d.get('offset', 0), 'notes': notes, 'events': events}
    return chart, d

def convert_songs(mod, out, as_json, report, only):
    sdir = os.path.join(mod, 'songs')
    ddir = os.path.join(mod, 'data')
    used_chars, used_stages, ids = set(), set(), {}
    if not os.path.isdir(sdir):
        return used_chars, used_stages, ids
    for folder in sorted(os.listdir(sdir)):
        if only is not None and folder not in only: continue
        src = os.path.join(sdir, folder)
        if not os.path.isdir(src): continue
        sid = slug(folder)
        ids[folder] = sid
        for fn in os.listdir(src):
            if fn.lower().endswith(('.ogg', '.mp3', '.m4a', '.wav')):
                os.makedirs(os.path.join(out, 'songs', sid), exist_ok=True)
                shutil.copyfile(os.path.join(src, fn), os.path.join(out, 'songs', sid, fn))
        data_dir = os.path.join(ddir, folder)
        if not os.path.isdir(data_dir):
            report.append('no chart folder for ' + folder); continue
        extra = []
        ep = os.path.join(data_dir, 'events.json')
        if os.path.exists(ep):
            extra = read_json(ep).get('events', [])
        meta = {}
        for fn in sorted(os.listdir(data_dir)):
            if not fn.endswith('.json') or fn == 'events.json': continue
            base = fn[:-5]
            diff = 'normal' if base == folder else base[len(folder) + 1:] if base.startswith(folder + '-') else None
            if diff is None: continue
            chart, raw = convert_chart(os.path.join(data_dir, fn), extra)
            chart['stage'] = chart['stage']
            write_data(out, 'charts/%s/%s' % (sid, diff), chart, as_json)
            used_chars.update([chart['player'], chart['opponent'], chart['girlfriend']])
            used_stages.add(chart['stage'])
            meta = {'title': raw.get('song', folder), 'artist': raw.get('artist', ''), 'bpm': chart['bpm'], 'needsVoices': chart['needsVoices']}
        write_data(out, 'songs/%s/song' % sid, meta, as_json)
        report.append('song: %s -> %s' % (folder, sid))
    return used_chars, used_stages, ids

def convert_weeks(mod, out, as_json, report, ids):
    wdir = os.path.join(mod, 'weeks')
    if not os.path.isdir(wdir): return
    weeks = []
    for fn in sorted(os.listdir(wdir)):
        if not fn.endswith('.json'): continue
        w = read_json(os.path.join(wdir, fn))
        songs = []
        for s in w.get('songs', []):
            match = slug(s[0]) if slug(s[0]) in ids.values() else None
            if match is None: continue
            songs.append({'id': match, 'name': s[0], 'icon': s[1], 'color': s[2]})
        if not songs: continue
        weeks.append({'id': fn[:-5], 'title': w.get('storyName', fn[:-5]), 'songs': songs,
                      'characters': w.get('weekCharacters', ['', 'bf', 'gf']), 'background': w.get('weekBackground', 'stage'),
                      'hideStory': bool(w.get('hideStoryMode', False)), 'hideFreeplay': bool(w.get('hideFreeplay', False))})
    write_data(out, 'weeks/weeks', {'weeks': weeks}, as_json)
    report.append('weeks: %d' % len(weeks))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mod'); ap.add_argument('out')
    ap.add_argument('--songs'); ap.add_argument('--webp', action='store_true'); ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    only = [s.strip() for s in a.songs.split(',')] if a.songs else None
    report = []
    if os.path.exists(a.out): shutil.rmtree(a.out)
    os.makedirs(a.out)
    convert_mod_info(a.mod, a.out, a.json, report)
    chars, stages, ids = convert_songs(a.mod, a.out, a.json, report, only)
    convert_characters(a.mod, a.out, a.json, a.webp, report, chars if only else None)
    convert_stages(a.mod, a.out, a.json, a.webp, report, stages if only else None)
    convert_weeks(a.mod, a.out, a.json, report, ids)
    print('\n'.join(report))

if __name__ == '__main__':
    main()
