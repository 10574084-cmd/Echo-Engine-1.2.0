// Tank (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "week7",
 "zoom": 0.7,
 "pixel": false,
 "bf": [
  1130,
  120
 ],
 "gf": [
  340,
  130
 ],
 "dad": [
  10,
  80
 ],
 "bfCamera": [
  -130,
  0
 ],
 "dadCamera": [
  50,
  50
 ],
 "gfCamera": [
  50,
  -50
 ],
 "cameraSpeed": 1,
 "layers": [
  {
   "id": "bar",
   "image": "tankmanBattlefield/erect/bg",
   "x": -985,
   "y": -805,
   "scale": 1.15
  },
  {
   "id": "sniper",
   "image": "tankmanBattlefield/erect/sniper",
   "x": -127,
   "y": 349,
   "scale": 1.15,
   "quality": "high",
   "anims": [
    {
     "name": "idle",
     "prefix": "Tankmanidlebaked instance 1",
     "fps": 24,
     "loop": false
    },
    {
     "name": "sip",
     "prefix": "tanksippingBaked instance 1",
     "fps": 24,
     "loop": false
    }
   ]
  },
  {
   "id": "tankguy",
   "image": "tankmanBattlefield/erect/guy",
   "x": 1398,
   "y": 407,
   "scale": 1.15,
   "quality": "high",
   "anim": {
    "name": "idle",
    "prefix": "BLTank2 instance 1",
    "fps": 24,
    "loop": false
   }
  }
 ],
 "filters": [
  {
   "target": "bf",
   "shader": "dropShadow",
   "hue": -38,
   "saturation": -20,
   "contrast": -25,
   "brightness": -46,
   "angDeg": 90,
   "str": 1,
   "dist": 15,
   "thr": 0.1,
   "AA_STAGES": 2,
   "dropColor": [
    223,
    239,
    60
   ],
   "mask": true
  },
  {
   "target": "gf",
   "unless": "gf-tankmen",
   "shader": "dropShadow",
   "hue": -38,
   "saturation": -20,
   "contrast": -25,
   "brightness": -46,
   "angDeg": 90,
   "str": 1,
   "dist": 15,
   "thr": 0.1,
   "AA_STAGES": 2,
   "dropColor": [
    223,
    239,
    60
   ],
   "mask": true
  },
  {
   "target": "gf",
   "if": "gf-tankmen",
   "thr2": 0.4,
   "shader": "dropShadow",
   "hue": -38,
   "saturation": -20,
   "contrast": -25,
   "brightness": -46,
   "angDeg": 90,
   "str": 1,
   "dist": 15,
   "thr": 0.1,
   "AA_STAGES": 2,
   "dropColor": [
    223,
    239,
    60
   ],
   "mask": true
  },
  {
   "target": "dad",
   "shader": "dropShadow",
   "hue": -38,
   "saturation": -20,
   "contrast": -25,
   "brightness": -46,
   "angDeg": 135,
   "str": 1,
   "dist": 15,
   "thr": 0.3,
   "AA_STAGES": 2,
   "dropColor": [
    223,
    239,
    60
   ],
   "mask": true
  }
 ],
 "behaviors": [
  {
   "type": "sniper",
   "sniper": "sniper",
   "guy": "tankguy"
  }
 ]
}
