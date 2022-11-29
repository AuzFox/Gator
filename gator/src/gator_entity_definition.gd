tool
class_name GatorEntityDefinition
extends Resource

enum InstanceType {SCENE, NODE}

var entity_tag: String = ""
var instance_type: int = InstanceType.SCENE setget set_instance_type
var scene: PackedScene
var geometry_flags: int = 0 setget set_geometry_flags
var collision_shape: int = GatorUtil.CollisionShape.CONVEX
var collision_type: int = GatorUtil.CollisionType.STATICBODY
var node_type: String = ""
var node_script: Script
var properties: Dictionary = {}

func set_instance_type(value):
	instance_type = value
	property_list_changed_notify()

func set_geometry_flags(value):
	geometry_flags = value
	property_list_changed_notify()

func _get_property_list() -> Array:
	var p: Array = [
		GatorUtil.catagory("GatorEntityDefinition"),
		GatorUtil.property("entity_tag", TYPE_STRING),
		GatorUtil.property("instance_type", TYPE_INT, PROPERTY_HINT_ENUM, "Scene,Node")
	]
	match instance_type:
		InstanceType.SCENE:
			p.append(GatorUtil.property("scene", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "PackedScene"))
		InstanceType.NODE:
			p.append(GatorUtil.property("node_type", TYPE_STRING))
			p.append(GatorUtil.property("node_script", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Script"))
	p.append(GatorUtil.property("geometry_flags", TYPE_INT, PROPERTY_HINT_FLAGS, "Visual,Collision"))
	if geometry_flags & GatorUtil.GeometryFlag.COLLISION:
		p.append(GatorUtil.property("collision_shape", TYPE_INT, PROPERTY_HINT_ENUM, "Convex,Concave"))
		p.append(GatorUtil.property("collision_type", TYPE_INT, PROPERTY_HINT_ENUM, "StaticBody,Area,RigidBody,KinematicBody"))
	p.append(GatorUtil.property("properties", TYPE_DICTIONARY))
	
	return p
