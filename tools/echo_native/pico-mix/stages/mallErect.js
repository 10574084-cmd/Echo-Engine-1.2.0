// Mall (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "week5",
 "zoom": 0.8,
 "pixel": false,
 "bf": [
  970,
  100
 ],
 "gf": [
  400,
  130
 ],
 "dad": [
  100,
  100
 ],
 "bfCamera": [
  0,
  -100
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
   "id": "mallWall",
   "image": "christmas/erect/bgWalls",
   "x": -1000,
   "y": -440,
   "scale": 0.9,
   "scroll": [
    0.2,
    0.2
   ]
  },
  {
   "id": "topBoppers",
   "image": "christmas/erect/upperBop",
   "x": -240,
   "y": -40,
   "scale": 0.85,
   "scroll": [
    0.33,
    0.33
   ],
   "quality": "high",
   "anim": {
    "name": "idle",
    "prefix": "upperBop",
    "fps": 24,
    "loop": false
   },
   "beat": "idle"
  },
  {
   "id": "escalators",
   "image": "christmas/erect/bgEscalator",
   "x": -1100,
   "y": -540,
   "scale": 0.9,
   "scroll": [
    0.3,
    0.3
   ],
   "quality": "high"
  },
  {
   "id": "christmasTree",
   "image": "christmas/erect/christmasTree",
   "x": 370,
   "y": -250,
   "scroll": [
    0.4,
    0.4
   ]
  },
  {
   "id": "fog",
   "image": "christmas/erect/white",
   "x": -1000,
   "y": 100,
   "scale": 0.9,
   "scroll": [
    0.85,
    0.85
   ],
   "quality": "high"
  },
  {
   "id": "bottomBoppers",
   "image": "christmas/erect/bottomBop",
   "x": -410,
   "y": 100,
   "scroll": [
    0.9,
    0.9
   ],
   "anims": [
    {
     "name": "idle",
     "prefix": "bop0",
     "fps": 24,
     "loop": false
    },
    {
     "name": "hey",
     "prefix": "hey0",
     "fps": 24,
     "loop": false
    }
   ],
   "beat": "idle"
  },
  {
   "id": "snowGround",
   "image": "christmas/fgSnow",
   "x": -600,
   "y": 680
  },
  {
   "id": "santa",
   "image": "christmas/santa",
   "x": -840,
   "y": 150,
   "anim": {
    "name": "idle",
    "prefix": "santa idle in fear",
    "fps": 24,
    "loop": false
   },
   "beat": "idle"
  }
 ],
 "filters": [
  {
   "target": "bf",
   "shader": "adjustColor",
   "hue": 5,
   "saturation": 20,
   "contrast": 0,
   "brightness": 0
  },
  {
   "target": "dad",
   "shader": "adjustColor",
   "hue": 5,
   "saturation": 20,
   "contrast": 0,
   "brightness": 0
  },
  {
   "target": "gf",
   "shader": "adjustColor",
   "hue": 5,
   "saturation": 20,
   "contrast": 0,
   "brightness": 0
  },
  {
   "target": "santa",
   "shader": "adjustColor",
   "hue": 5,
   "saturation": 20,
   "contrast": 0,
   "brightness": 0
  }
 ],
 "behaviors": [
  {
   "type": "boppers",
   "layer": "bottomBoppers",
   "hey": "hey"
  }
 ]
}
