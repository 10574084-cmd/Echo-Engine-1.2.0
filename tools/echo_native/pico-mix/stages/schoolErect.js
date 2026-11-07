// School (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "week6",
 "zoom": 1.05,
 "pixel": true,
 "bf": [
  1050,
  320
 ],
 "gf": [
  610,
  430
 ],
 "dad": [
  100,
  100
 ],
 "bfCamera": [
  -150,
  -100
 ],
 "dadCamera": [
  0,
  0
 ],
 "gfCamera": [
  -60,
  0
 ],
 "cameraSpeed": 1,
 "layers": [
  {
   "id": "sky",
   "image": "weeb/erect/weebSky",
   "x": -164,
   "y": -78,
   "scroll": [
    0.2,
    0.2
   ],
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "treesBackground",
   "image": "weeb/erect/weebBackTrees",
   "x": -242,
   "y": -80,
   "scroll": [
    0.5,
    0.5
   ],
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "schoolBuilding",
   "image": "weeb/erect/weebSchool",
   "x": -216,
   "y": -38,
   "scroll": [
    0.75,
    0.75
   ],
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "schoolStreet",
   "image": "weeb/erect/weebStreet",
   "x": -200,
   "y": 6,
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "treesBack",
   "image": "weeb/erect/weebTreesBack",
   "x": -200,
   "y": 6,
   "quality": "high",
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "trees",
   "image": "weeb/erect/weebTrees",
   "x": -806,
   "y": -1050,
   "atlas": "packer",
   "anim": {
    "name": "anim",
    "frames": [
     0,
     1,
     2,
     3,
     4,
     5,
     6,
     7,
     8,
     9,
     10,
     11,
     12,
     13,
     14,
     15,
     16,
     17,
     18
    ],
    "fps": 12,
    "loop": true
   },
   "scale": 6,
   "antialiasing": false
  },
  {
   "id": "fallingPetals",
   "image": "weeb/erect/petals",
   "x": -20,
   "y": -40,
   "quality": "high",
   "anim": {
    "name": "anim",
    "prefix": "PETALS ALL",
    "fps": 24,
    "loop": true
   },
   "scale": 6,
   "antialiasing": false
  }
 ],
 "filters": [
  {
   "target": "bf",
   "shader": "dropShadow",
   "hue": -10,
   "saturation": -23,
   "contrast": 24,
   "brightness": -66,
   "angDeg": 90,
   "str": 1,
   "dist": 5,
   "thr": 0.1,
   "AA_STAGES": 0,
   "dropColor": [
    82,
    53,
    29
   ],
   "mask": true
  },
  {
   "target": "dad",
   "shader": "dropShadow",
   "hue": -10,
   "saturation": -23,
   "contrast": 24,
   "brightness": -66,
   "angDeg": 90,
   "str": 1,
   "dist": 5,
   "thr": 0.1,
   "AA_STAGES": 0,
   "dropColor": [
    82,
    53,
    29
   ],
   "mask": true
  },
  {
   "target": "gf",
   "unless": "gf-pixel",
   "shader": "dropShadow",
   "hue": -10,
   "saturation": -23,
   "contrast": 24,
   "brightness": -66,
   "angDeg": 90,
   "str": 1,
   "dist": 5,
   "thr": 0.1,
   "AA_STAGES": 0,
   "dropColor": [
    82,
    53,
    29
   ],
   "mask": true
  },
  {
   "target": "gf",
   "if": "gf-pixel",
   "shader": "dropShadow",
   "hue": -10,
   "saturation": -25,
   "contrast": 5,
   "brightness": -42,
   "angDeg": 90,
   "str": 1,
   "dist": 3,
   "thr": 0.3,
   "AA_STAGES": 0,
   "dropColor": [
    82,
    53,
    29
   ],
   "mask": true
  }
 ],
 "gameOver": {
  "character": "bf-pixel-dead",
  "deathSound": "fnf_loss_sfx-pixel",
  "loopSound": "gameOver-pixel",
  "endSound": "gameOverEnd-pixel"
 }
}
