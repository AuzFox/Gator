class_name GatorEntityDefinition
extends Resource

enum EntityType {SCENE, EMPTY}

export var entity_tag: String = ""
export (EntityType) var entity_type: int = EntityType.SCENE
export var scene: PackedScene
export (Dictionary) var properties: Dictionary = {}
