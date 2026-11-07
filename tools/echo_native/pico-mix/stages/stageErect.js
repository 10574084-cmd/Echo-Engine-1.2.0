// Main stage (erect) of Pico Mix
// Native Echo stage: layers, filters and behaviors. No script runs for it.
{
 "directory": "",
 "zoom": 0.9,
 "pixel": false,
 "bf": [
  800,
  120
 ],
 "gf": [
  150,
  150
 ],
 "dad": [
  -160,
  90
 ],
 "bfCamera": [
  -50,
  -30
 ],
 "dadCamera": [
  80,
  0
 ],
 "gfCamera": [
  125,
  -10
 ],
 "cameraSpeed": 1,
 "layers": [
  {
   "id": "darkBG",
   "image": "mainStage/erect/backDark",
   "x": 729,
   "y": -170
  },
  {
   "id": "crowd",
   "image": "mainStage/erect/crowd",
   "x": 560,
   "y": 290,
   "scroll": [
    0.8,
    0.8
   ],
   "anim": {
    "name": "idle",
    "prefix": "Symbol 2 instance 1",
    "fps": 12,
    "loop": true
   }
  },
  {
   "id": "smallLight",
   "image": "mainStage/erect/brightLightSmall",
   "x": 967,
   "y": -103,
   "scroll": [
    1.2,
    1.2
   ],
   "blend": "add",
   "quality": "high"
  },
  {
   "id": "backStage",
   "image": "mainStage/erect/bg",
   "x": -603,
   "y": -187
  },
  {
   "id": "server",
   "image": "mainStage/erect/server",
   "x": -361,
   "y": 205,
   "quality": "high"
  },
  {
   "id": "redServerLight",
   "image": "mainStage/erect/lightred",
   "x": -101,
   "y": 560,
   "blend": "add",
   "quality": "high"
  },
  {
   "id": "greenServerLight",
   "image": "mainStage/erect/lightgreen",
   "x": -171,
   "y": 242,
   "blend": "add",
   "quality": "high"
  },
  {
   "id": "orangeHue",
   "image": "mainStage/erect/orangeLight",
   "x": 189,
   "y": -195,
   "blend": "add"
  },
  {
   "id": "stageLights",
   "image": "mainStage/erect/lights",
   "x": -601,
   "y": -147,
   "scroll": [
    1.2,
    1.2
   ],
   "front": true,
   "quality": "high"
  },
  {
   "id": "light",
   "image": "mainStage/erect/lightAbove",
   "x": 804,
   "y": -117,
   "blend": "add",
   "front": true,
   "quality": "high"
  }
 ],
 "filters": [
  {
   "target": "bf",
   "shader": "adjustColor",
   "hue": 12,
   "saturation": 0,
   "contrast": 7,
   "brightness": -23
  },
  {
   "target": "dad",
   "shader": "adjustColor",
   "hue": -32,
   "saturation": 0,
   "contrast": -23,
   "brightness": -33
  },
  {
   "target": "gf",
   "shader": "adjustColor",
   "hue": -9,
   "saturation": 0,
   "contrast": -4,
   "brightness": -30
  }
 ],
 "behaviors": [
  {
   "type": "spotlight",
   "hide": [
    "smallLight",
    "light"
   ]
  }
 ]
}
