# Gator
Crocotile3D Custom Object Data Importer for Godot.

**This plugin is a work-in-progress**

## Overview

Gator is a plugin for Godot that can use the custom data defined on Crocotile3D objects to instance scenes automatically in Godot.

## Features
- Use Crocotile3D objects as placeholders for Godot Scenes/nodes within a scene
  - Crocotile3D's object heirarchy is preserved when instancing scenes
- Import custom object properties and use them in Godot scripts
  - Define multiple Entity types, each with unique properties to import from Crocotile3D
  - Automatically convert to `int`, `float`, `bool`, `String`, `Vector*`, and `Color` Godot data types (More to be implemented soon!)

## Installation

- Place the `gator` folder into the `res://addons` directory of your Godot project (Create one if needed)
- Open the project in Godot
- Go to `Project > Project Settings > Plugins tab` and check the `Enable` checkbox for the Gator plugin

## Special Thanks 

[Alex Hanson-White](http://www.alexhw.com/) - For creating [Crocotile3D](http://www.crocotile3d.com/), and offering helpful support for the program

[Shfty](https://github.com/Shfty) - For creating [Qodot](https://github.com/QodotPlugin/qodot-plugin), the inspiration for this plugin
