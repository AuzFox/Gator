# Gator
Crocotile3D Custom Object Data Importer for Godot 3.

## Overview

Gator is a plugin for Godot that can use the custom data defined on Crocotile3D objects to instance scenes automatically in Godot.

## Features
- Use Crocotile3D objects as placeholders for Godot scenes/nodes
  - Crocotile3D's object heirarchy is preserved when instancing scenes
- Import custom object properties and use them in Godot scripts
  - Define multiple Entity types, each with unique properties to import from Crocotile3D
  - Automatically convert to any Godot data type that can be parsed by `str2var()`

## Installation

- Place the `gator` folder into the `res://addons` directory of your Godot project (Create one if needed)
- Open the project in Godot
- Go to `Project > Project Settings > Plugins tab` and check the `Enable` checkbox for the Gator plugin

## Demos

See the (WIP) [Gator Demos](https://github.com/AuzFox/Gator-Demos) Godot 3 project.

## Special Thanks 

[Alex Hanson-White](http://www.alexhw.com/) - For creating [Crocotile3D](http://www.crocotile3d.com/), and offering helpful support for the program

[Shfty](https://github.com/Shfty) - For creating [Qodot](https://github.com/QodotPlugin/qodot-plugin), the inspiration for this plugin
