# Echo Mods – formato de mods propio de Echo Engine (v0.2, Fase 1 lista)

Objetivo: que hacer un mod (o portar uno de Psych Engine) sea fácil, que corra igual en web, PC y celular, y que los eventos más usados vengan **ya hechos dentro del motor**, sin depender de Lua/HScript (que en la web son una emulación).

## 1. Cómo funciona

```
Mod Echo (carpeta o .zip)  ──►  EchoModLoader  ──►  archivos en forma Psych  ──►  el juego de siempre
                                    (al importar)
```

* El motor sigue siendo Haxe. Al **importar** un zip, si trae un `mod.js`/`mod.json` en la raíz, el `EchoModLoader` lo lee, lo valida y lo traduce a los archivos que el juego ya entiende (personajes, charts, canciones, escenarios, semanas). Por eso todo lo que ya funciona (notas, audio, cámara, iconos, Freeplay) lo heredan los mods nuevos sin tocar nada.
* Los datos son archivos **`.js` que solo contienen un objeto** (como en tu estructura) o `.json`. Se **leen, nunca se ejecutan**: se permiten comentarios, claves sin comillas, comillas simples y comas finales, pero no código (ni llamadas ni variables). Un mod no puede ejecutar nada solo por importarse.
* Se aceptan envoltorios comunes: `export default {…}`, `module.exports = {…}`, `Echo.define({…})`, `const x = {…}`.
* Los mods Psych normales siguen funcionando igual que antes.

## 2. Estructura de un mod (la tuya, sin cambios)

```
PicoMix/
├── mod.js                    ← nombre, autor, versión
├── characters/               ← <id>.js + <imagen>.webp|png + .xml
├── charts/<cancion>/         ← easy.js  normal.js  hard.js
├── songs/<cancion>/          ← song.js, Inst.ogg|m4a|mp3, Voices-*.ogg|m4a|mp3
├── stages/                   ← <id>.js (capas) + images/
├── images/  animations/  events/  dialogues/  weeks/  data/  fonts/  menu/
```

Reglas: nombres de carpeta sin espacios ni paréntesis; imágenes `.webp` o `.png`; en la web las `.webp` se convierten a `.png` justo después de importar (el aviso "Preparando imágenes…" indica que hay que esperar a "Ready to play").

## 3. Formatos

### charts/<cancion>/<dificultad>.js
Tiempos en ms, carriles `0–3` = jugador y `4–7` = oponente; la cámara sale del evento `camera.target` (el cargador lo convierte a `mustHitSection`). Mismo espíritu que `psych_v1` de Psych 1.0.

### characters/<id>.js
`image` (puede ser una lista de atlas), `scale`, `flipX`, `antialiasing`, `icon`, `barColor`, `camera`, `position`, `anims: [{ name, prefix, fps, loop, offset }]`. El icono se busca en `images/health-icons`.

### stages/<id>.js
`zoom`, posiciones `bf` / `dad` / `gf`, y `layers: [{ image, x, y, scale, scroll, front, anim, alpha, flipX }]`. Las dibuja `EchoStage` (nativo, sin Lua).

### weeks/weeks.js, songs.js
Lista de semanas y canciones (se convierten a las semanas que muestra Freeplay).

## 4. Eventos (Fase 2)

Biblioteca nativa `echo.events` con nombres como `camera.target`, `camera.zoom`, `camera.bop`, `camera.shake`, `screen.flash`, `char.anim`, `char.change`, `gameplay.speed`, `stage.layer`, `dialogue.start`; los eventos propios irán en `events/custom-events.js` dentro de un entorno restringido. Hoy está implementado `camera.target`.

## 5. Convertidor `tools/psych2echo.py`

Convierte un mod Psych (0.7 / 1.0) a este formato y da un informe de qué no pudo traducir. Probado con Pico Mix (17 elementos: 4 personajes, 2 escenarios, 2 canciones con 6 charts, 2 semanas).

## 6. Estado

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Lector de datos, cargador, convertidor, importación en la web, escenarios por capas, conversión webp | **Hecha**; Pico Mix (Bopeebo y Guns) probado importado y jugando en Chromium |
| 2 | Biblioteca de eventos nativa + `custom-events.js` | Pendiente |
| 3 | Diálogos y menús del mod | Pendiente |
| 4 | Validador con mensajes claros, plantilla de mod vacía, guía para creadores | Pendiente |

Pendiente de tu lado: las imágenes base `Nene`, `Pico_FNF_assetss`, `Pico_Intro`, `Pico_Shooting`, `tankmanCaptain` (el cargador avisa de ellas en la consola y usa la copia del juego si existe).

Para probar: `tools/test/EchoModTest.hx` (corre con `haxe --interp`) y el parámetro de desarrollo `?autosong=<cancion>&mod=<carpeta>&bot=1`.
