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
Un escenario es **datos**, sin script. Lo dibuja `EchoStage` (nativo, en Haxe):

```js
{
  directory: "week3",              // librería de imágenes del juego base que usa (opcional)
  zoom: 1.05, pixel: false,
  bf: [860, 100], dad: [180, 100], gf: [415, 130],
  bfCamera: [-75, 0], dadCamera: [-60, 0], gfCamera: [10, 0], cameraSpeed: 1,
  layers: [
    { id: "sky", image: "philly/erect/sky", x: -100, y: 0, scroll: [0.1, 0.1], quality: "high" },
    { id: "crowd", image: "mainStage/erect/crowd", x: 560, y: 290,
      anim: { name: "idle", prefix: "Symbol 2 instance 1", fps: 12, loop: true }, beat: "idle" },
    { id: "glow", image: "x/glow", x: 0, y: 0, blend: "add", front: true },
    { id: "veil", color: "000000", size: [2560, 1440], x: -800, y: -400, scroll: [0, 0], alpha: 0.25 }
  ],
  filters: [ { target: "bf", shader: "adjustColor", hue: 12, contrast: 7, brightness: -23 } ],
  behaviors: [ { type: "lightning", lit: ["corridor"], flash: "flash" } ],
  gameOver: { character: "bf-pixel-dead", deathSound: "fnf_loss_sfx-pixel" }
}
```

**Capas** (`layers`, en orden; van detrás de los personajes salvo `front: true`): `id`, `image` (de `images/` del mod o del juego) o `color`+`size` (rectángulo liso), `x`, `y`, `scale` (número o `[x, y]`), `scroll`, `alpha`, `visible`, `flipX`, `antialiasing`, `blend` (`add`, `multiply`, `screen`…), `tint`, `anim` / `anims` (`prefix` o `frames`, `fps`, `loop`; `atlas: "packer"`), `beat` (`"idle"` o `{ anim, every, offset }`: la anima en cada beat), `quality: "high"` (no se dibuja en calidad baja) y `flashing: true` (solo con luces parpadeantes activadas).

**Filtros** (`filters`): un shader del mod (`shaders/<nombre>.frag`) sobre `bf`, `dad`, `gf` o una capa por su `id`; el resto de claves son los valores del shader (colores en 0–255, `angDeg` en grados, `mask: true` usa `characters/masks/<imagen>_mask.png`, `time: "uTime"` le da el tiempo cada frame). `if` / `unless` los limitan a un personaje concreto (`gf-pixel`…).

**Comportamientos** (`behaviors`, bloques ya hechos en el motor): `lightning` (rayos del Spooky Mansion), `spotlight` (evento *Dadbattle Spotlight*), `boppers` (el público del mall reacciona a *Hey!*), `sniper` (el francotirador del tank), `philly` (ventana, tren y evento *Philly Glow*).

### weeks/weeks.js, songs.js
Lista de semanas y canciones (se convierten a las semanas que muestra Freeplay).

## 4. Eventos

Biblioteca nativa `echo.EchoEvents` (se activa sola en los mods Echo, que llevan `echo: true` en su `pack.json`), con el mismo comportamiento que los eventos de Pico Mix pero sin Lua:

| Evento | value1 | value2 |
|---|---|---|
| `Set Camera Zoom` | `zoom[,stage]` | `pasos[,ease]` |
| `Set Camera Bop` | `ritmo[,desfase]` | `intensidad` |
| `Set Camera Target` | `quién[,x[,y]]` (vacío = vuelve a las secciones) | `pasos[,ease]` |
| `Set Scroll Speed` | `velocidad[,absolute]` | `pasos[,ease]` |

En el chart de Echo los eventos del motor tienen nombre propio (`camera.target`, `camera.zoom`, `camera.shake`, `char.anim`, `char.hey`, `char.change`, `gameplay.speed`, `gameplay.bpm`, `sound.play`…) y cualquier otro conserva su nombre con `v1` / `v2`. Los eventos propios de un mod (`custom-events.js`) siguen pendientes (Fase 2b).

## 4b. Editor de charts

El botón **Save (Echo)** del editor guarda `<dificultad>.json` en formato Echo (JSON normal: `notes` con `t`, `lane`, `len`, `type`; `events` con `t`, `name`, `args`). La cámara de cada sección y los cambios de tempo salen como eventos. **Save Psych** sigue guardando el formato antiguo. Probado: los 45 charts de Pico Mix hacen la ida y vuelta Echo → motor → Echo sin perder una nota (`tools/test/EchoModTest.hx`).

## 5. Convertidor `tools/psych2echo.py`

Convierte un mod Psych (0.7 / 1.0) a este formato y da un informe de qué no pudo traducir. Probado con Pico Mix (17 elementos: 4 personajes, 2 escenarios, 2 canciones con 6 charts, 2 semanas).

## 6. Modo híbrido (así está portado Pico Mix)

`psych2echo.py` convierte los **datos** (mod, personajes, charts, canciones, semanas) al formato Echo y deja **tal cual** todo lo que es código o recursos: escenarios con `.lua`, scripts de personajes (Nene, bocina Abot), `scripts/`, `custom_events/`, `custom_notetypes/`, shaders, imágenes, sonidos, videos, fuentes y diálogos. Los eventos del chart pasan con su nombre y sus valores (el cargador los entrega a los scripts) y `camera.target` además le dice al chart de qué lado es cada sección. Con `--no-hybrid` solo se traducen los datos.

Los 6 escenarios de Pico Mix se reemplazan por su versión **nativa** (`tools/echo_native/pico-mix/stages/*.js`, con `--no-native` se dejan los `.lua`); del tank solo queda un script con las voces de Tankman al perder. Además aplica unos pocos **arreglos a errores del propio mod** que fallaban en cada frame (`PATCHES` en el script): `phillyErect.lua` (degradado inexistente sin el evento Philly Glow), `spookyErect.lua` (variable mal escrita) y los `dialogueBox.lua` de Senpai y Roses.

Comprobado sobre las 15 canciones (45 dificultades): 0 notas perdidas y los mismos eventos, tiempos y valores que el original.

El juego trae Pico Mix ya convertido: en el despliegue (`tools/add_builtin.sh`) se descarga el zip Psych de la release `CLAUDE`, se convierte y se publica.

## 7. Estado

| Fase | Contenido | Estado |
|---|---|---|
| 1 | Lector de datos, cargador, convertidor, importación en la web, escenarios por capas, conversión webp | **Hecha**; Pico Mix (Bopeebo y Guns) probado importado y jugando en Chromium |
| 1b | Pico Mix completo en modo híbrido (15 canciones, 7 escenarios, Nene/Abot) | **Hecho**; auditoría de las 15 canciones en el navegador |
| 2 | Escenarios nativos (capas, filtros, comportamientos) y eventos de cámara nativos | **Hecha** para Pico Mix (ver pruebas) |
| 2b | `custom-events.js` (eventos propios de cada mod, en un entorno restringido) y scripts de personajes nativos (Nene/Abot) | Pendiente |
| 3 | Diálogos y menús del mod | Pendiente |
| 4 | Validador con mensajes claros, plantilla de mod vacía, guía para creadores | Pendiente |

Pendiente de tu lado: las imágenes base `Nene`, `Pico_FNF_assetss`, `Pico_Intro`, `Pico_Shooting`, `Pico_Death`, `tankmanCaptain` (no están en ningún zip del mod) (el cargador avisa de ellas en la consola y usa la copia del juego si existe).

Para probar: `tools/test/EchoModTest.hx` (corre con `haxe --interp`) y el parámetro de desarrollo `?autosong=<cancion>&mod=<carpeta>&bot=1`.
