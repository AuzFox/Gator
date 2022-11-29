# Gator

Crocotile3D Scene Importer Plugin for Godot.

## Overview

Gator is a plugin for Godot imports the custom data defined on Crocotile3D objects, and can recreate the C3D scene using Godot assets.

## Features

- Recreate Crocotile3D scenes in Godot
    - Import geometry from the Crocotile3D scene
    - Use Crocotile3D objects as placeholders for Godot scenes/nodes
    - Crocotile3D's object heirarchy is preserved when instancing scenes
- Import custom object properties and use them in Godot scripts
    - Define multiple Entity types, each with unique properties to import from Crocotile3D
    - Automatically convert to any Godot data type that can be parsed by `str2var()`

## Installation

Download a release from the releases page and follow these steps:
- Extract the `gator` folder into the `res://addons` directory of your Godot project (Create one if needed)
- Open the project in Godot
- Go to `Project > Project Settings` and open the `Plugins` tab
- Check the `Enable` checkbox for the Gator plugin

## Documentation

Check out the [User Guide](https://github.com/AuzFox/Gator/wiki/User-Guide)!

## Demos

See the (WIP) [Gator Demos](https://github.com/AuzFox/Gator-Demos) Godot 3 project.

## Special Thanks 

[Alex Hanson-White](http://www.alexhw.com/) - For creating [Crocotile3D](http://www.crocotile3d.com/), and offering helpful support for the program

[Shfty](https://github.com/Shfty) - For creating [Qodot](https://github.com/QodotPlugin/qodot-plugin), the inspiration for this plugin
