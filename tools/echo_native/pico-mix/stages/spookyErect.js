// Spooky Mansion (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "week2",
 "zoom": 1.05,
 "pixel": false,
 "bf": [
  990,
  100
 ],
 "gf": [
  490,
  130
 ],
 "dad": [
  170,
  100
 ],
 "bfCamera": [
  -30,
  0
 ],
 "dadCamera": [
  0,
  0
 ],
 "gfCamera": [
  0,
  0
 ],
 "cameraSpeed": 1,
 "layers": [
  {
   "id": "outdoorTrees",
   "image": "spookyMansion/erect/bgtrees",
   "x": 190,
   "y": 30,
   "scroll": [
    0.85,
    0.85
   ],
   "anim": {
    "name": "anim",
    "prefix": "bgtrees",
    "fps": 5,
    "loop": true
   }
  },
  {
   "id": "corridorDark",
   "image": "spookyMansion/erect/bgDark",
   "x": -360,
   "y": -220
  },
  {
   "id": "corridor",
   "image": "spookyMansion/erect/bgLight",
   "x": -360,
   "y": -220,
   "alpha": 0,
   "quality": "high"
  },
  {
   "id": "stairsDark",
   "image": "spookyMansion/erect/stairsDark",
   "x": 966,
   "y": -225,
   "front": true,
   "quality": "high"
  },
  {
   "id": "stairs",
   "image": "spookyMansion/erect/stairsLight",
   "x": 966,
   "y": -225,
   "alpha": 0,
   "front": true,
   "quality": "high"
  },
  {
   "id": "lightingFlash",
   "color": "FFFFFF",
   "size": [
    2560,
    1440
   ],
   "x": -800,
   "y": -400,
   "scroll": [
    0,
    0
   ],
   "blend": "add",
   "alpha": 0,
   "front": true,
   "flashing": true
  }
 ],
 "filters": [
  {
   "target": "outdoorTrees",
   "shader": "rain",
   "time": "uTime",
   "uScale": 7.2,
   "uIntensity": 0.4,
   "uSpriteMode": true,
   "uRainColor": [
    102,
    128,
    204
   ],
   "uScreenResolution": [
    1280,
    720
   ],
   "uCameraBounds": [
    0,
    0,
    1280,
    720
   ]
  }
 ],
 "behaviors": [
  {
   "type": "lightning",
   "lit": [
    "corridor",
    "stairs"
   ],
   "flash": "lightingFlash",
   "tintOthers": "0x070711"
  }
 ]
}
