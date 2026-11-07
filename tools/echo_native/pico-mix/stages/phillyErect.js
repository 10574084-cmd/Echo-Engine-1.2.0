// Philly (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "week3",
 "zoom": 1.05,
 "pixel": false,
 "bf": [
  860,
  100
 ],
 "gf": [
  415,
  130
 ],
 "dad": [
  180,
  100
 ],
 "bfCamera": [
  -75,
  0
 ],
 "dadCamera": [
  -60,
  0
 ],
 "gfCamera": [
  10,
  0
 ],
 "cameraSpeed": 1,
 "layers": [
  {
   "id": "sky",
   "image": "philly/erect/sky",
   "x": -100,
   "y": 0,
   "scroll": [
    0.1,
    0.1
   ],
   "quality": "high"
  },
  {
   "id": "city",
   "image": "philly/erect/city",
   "x": -10,
   "y": 0,
   "scale": 0.85,
   "scroll": [
    0.3,
    0.3
   ]
  },
  {
   "id": "window",
   "image": "philly/window",
   "x": -10,
   "y": 0,
   "scale": 0.85,
   "scroll": [
    0.3,
    0.3
   ],
   "alpha": 0
  },
  {
   "id": "behindTrain",
   "image": "philly/erect/behindTrain",
   "x": -40,
   "y": 50,
   "quality": "high"
  },
  {
   "id": "train",
   "image": "philly/train",
   "x": 2000,
   "y": 360
  },
  {
   "id": "street",
   "image": "philly/erect/street",
   "x": -40,
   "y": 50
  }
 ],
 "filters": [
  {
   "target": "bf",
   "shader": "adjustColor",
   "hue": -26,
   "saturation": -16,
   "contrast": 0,
   "brightness": -5
  },
  {
   "target": "dad",
   "shader": "adjustColor",
   "hue": -26,
   "saturation": -16,
   "contrast": 0,
   "brightness": -5
  },
  {
   "target": "gf",
   "shader": "adjustColor",
   "hue": -26,
   "saturation": -16,
   "contrast": 0,
   "brightness": -5
  },
  {
   "target": "train",
   "shader": "adjustColor",
   "hue": -26,
   "saturation": -16,
   "contrast": 0,
   "brightness": -5
  }
 ],
 "behaviors": [
  {
   "type": "philly",
   "window": "window",
   "train": "train",
   "street": "street"
  }
 ]
}
