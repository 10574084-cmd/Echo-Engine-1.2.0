# Echo Mods – formato de mods propio de Echo Engine (propuesta v0.1)

Objetivo: que hacer un mod (o portar uno de Psych Engine) sea fácil, que corra igual en web, PC y celular, y que los eventos más usados vengan **ya hechos dentro del motor** (sin depender de Lua/HScript, que en la web son una emulación).

Esta propuesta parte de la estructura que armaste (`PicoMixNose/…`, `browser-engine/…`) y la adapta al motor que ya existe (Haxe/OpenFL), para no perder lo que funciona.

## 1. Idea general

```
Mod (carpeta o .zip)  ──►  EchoModLoader  ──►  el juego (PlayState, menús, audio)
                              ▲
        convertidor  psych2echo  (mods Psych → formato Echo)
```

* Un mod Echo es una carpeta con datos **JSON** y archivos de imagen/audio. No hace falta programar para un mod normal.
* El `EchoModLoader` (Haxe, dentro del motor) lee el mod, lo valida y lo entrega al juego. Reutiliza el motor actual (notas, audio, cámara), así que cada mod nuevo ya hereda lo que funciona hoy.
* Los **eventos** son una biblioteca nativa (`echo/events/`). Un chart los pide por nombre y con argumentos en JSON.
* Cuando un mod necesite algo muy propio, puede traer un `events/custom-events.js` pequeño (ver §5). Es opcional.

## 2. Estructura de un mod

Se mantiene tu árbol; la diferencia es que los datos son `.json` (se validan solos, se pueden editar con cualquier editor y no ejecutan código) y los `.js` quedan solo para eventos propios.

```
PicoMixNose/
├── mod.json                  ← nombre, autor, versión, versión mínima de Echo, créditos
├── menu/
│   ├── menu.json             ← pestañas, orden de semanas, textos
│   ├── backgrounds/  character-icons/  menu-images/  freeplay-icons/
├── characters/
│   ├── pico.json             ← animaciones, offsets, escala, icono, color de la barra
│   ├── pico.webp  (+ pico.xml o pico.atlas.json)
├── charts/
│   └── bopeebo/  easy.json  normal.json  hard.json
├── songs/
│   └── bopeebo/  song.json  Inst.ogg/.m4a/.mp3  Voices-Player.*  Voices-Opponent.*
├── stages/
│   ├── stage.json            ← capas (imagen, posición, scroll, animación), posiciones de personajes, zoom
│   └── images/
├── images/  (notas, efectos, iconos de vida, pausa, game over)
├── animations/               ← spritesheets compartidos
├── events/
│   ├── events.json           ← qué eventos usa el mod y sus valores por defecto
│   └── custom-events.js      ← (opcional) eventos propios
├── dialogues/                ← senpai.json, roses.json, dialogue-settings.json
├── weeks/                    ← weeks.json
├── data/                     ← achievements.json, settings.json, metadata.json
└── fonts/
```

Reglas:
* Nombres en minúsculas y con guiones (`philly-nice`), sin parentéis ni espacios. El convertidor se encarga de renombrar.
* Imágenes `.webp` o `.png`; audio `.ogg` o `.m4a` (el `.mp3` solo como respaldo).
* Una sola carpeta `songs/<cancion>/` por canción; el chart de cada dificultad vive en `charts/<cancion>/<dificultad>.json`.

## 3. Formatos de datos

### mod.json
```json
{ "id": "pico-mix", "name": "Pico Mix", "version": "1.0.0", "echo": ">=1.3.0",
  "authors": ["…"], "description": "…", "runsGlobally": false }
```

### charts/<cancion>/<dificultad>.json
Tiempos en **milisegundos**, carriles `0–3` = jugador y `4–7` = oponente (fijo, sin `mustHitSection`; la cámara se controla con eventos).
```json
{ "bpm": 100, "speed": 1.8, "stage": "stage-erect",
  "player": "pico", "opponent": "dad", "girlfriend": "nene",
  "notes":  [ { "t": 600, "lane": 1, "len": 0, "type": "" } ],
  "events": [ { "t": 0, "name": "camera.target", "args": { "who": "dad" } } ] }
```
(Es la misma idea que el formato `psych_v1` de Psych 1.0, que hoy ya se entiende y se invierte a mano para Pico Mix.)

### characters/<id>.json
```json
{ "image": "pico", "scale": 1, "flipX": false, "antialiasing": true,
  "icon": "pico", "barColor": "#B7D855", "camera": [0, 0], "position": [0, 0],
  "anims": [ { "name": "idle", "prefix": "Idle", "fps": 24, "loop": false, "offset": [0, 0] } ] }
```
`image` puede ser una lista (varios atlas por personaje, como pide Pico Mix; ya está soportado).

### stages/<id>.json
```json
{ "zoom": 0.9, "layers": [ { "image": "bg", "x": -985, "y": -805, "scale": 1.15, "scroll": [1, 1] } ],
  "bf": [800, 420], "dad": [100, 420], "gf": [500, 300] }
```

## 4. Eventos portados (biblioteca nativa)

Los eventos de Psych / Pico Mix más usados pasan a ser eventos nativos de Echo. El convertidor traduce los nombres.

| Evento Echo | Equivale a (Psych) | Argumentos |
|---|---|---|
| `camera.target` | Set Camera Target / Camera Follow Pos | `who`, `x`, `y`, `duration`, `ease` |
| `camera.zoom` | Set Camera Zoom / Add Camera Zoom | `zoom`, `duration`, `ease`, `mode` |
| `camera.bop` | Set Camera Bop | `every`, `intensity` |
| `camera.shake` | Screen Shake | `duration`, `intensity` |
| `screen.flash` | (flash) | `color`, `duration` |
| `char.anim` | Play Animation | `who`, `anim`, `force` |
| `char.hey` | Hey! | `who` |
| `char.change` | Change Character | `who`, `to` |
| `gameplay.speed` | Change Scroll Speed | `speed`, `duration`, `ease` |
| `gameplay.bpm` | Change BPM | `bpm` |
| `stage.layer` | Set Property / mostrar-ocultar capa | `layer`, `prop`, `value` |
| `dialogue.start` | dialogueBox.lua | `file` |

## 5. Eventos propios (opcional, `custom-events.js`)

Un archivo pequeño, sin acceso a nada fuera de la API de Echo:

```js
Echo.event('mi-evento', (ctx, args) => {
  ctx.char('bf').play('hey');
  ctx.camera.zoomTo(1.2, 0.5);
  ctx.tween(ctx.stage.layer('luces'), { alpha: 1 }, 0.3);
});
```
API mínima `ctx`: `char(id)`, `camera`, `stage.layer(id)`, `tween(obj, props, seg, ease)`, `sound(id)`, `time` (ms de la canción). Se ejecuta en un entorno restringido; si hay un error, se ignora ese evento y la canción sigue.

## 6. Convertidor `psych2echo`

`tools/psych2echo.py` (se usa en local o en CI):
1. Renombra y copia imágenes/audio (`Voices-Player` → `Voices-Player`, quita paréntesis y espacios).
2. Convierte charts Psych (0.7 y 1.0) al chart Echo (carriles fijos, eventos con nombres Echo).
3. Convierte `characters/*.json`, `stages/*.json`/`.lua` (las capas simples) y `weeks/*.json`.
4. Los `.lua` que no se pueden traducir se copian aparte (`legacy/`) y se siguen ejecutando con fengari mientras exista "Mod Scripts".
5. Imprime un **informe** de qué se convirtió y qué quedó sin traducir.

## 7. Fases

1. **Fase 1 – Base**: `mod.json`, cargador, validador y los formatos de §3 para personajes, charts, canciones, escenarios y semanas. Pico Mix convertido de prueba.
2. **Fase 2 – Eventos**: biblioteca nativa de §4 (cámara, personajes, pantalla, gameplay) + `custom-events.js`.
3. **Fase 3 – Diálogos y menús**: `dialogues/*.json`, `menu.json` y la pestaña de mods en Freeplay.
4. **Fase 4 – Herramientas**: validador con mensajes claros, plantilla de mod vacía y documentación para creadores.

## 8. Decisiones abiertas

* ¿`.json` para datos (recomendado) o `.js` como en tu esquema? Con `.js` los mods podrían traer código en cualquier archivo, lo que complica la seguridad y los errores.
* ¿Nombre oficial del formato? (`Echo Mods`, `.echomod` para el zip).
* ¿Los mods viejos de Psych seguirán funcionando como hasta ahora (sí, esa es la idea) o se quiere pedir conversión siempre?
