@tool
class_name GatorEntityDefinition
extends Resource

enum InstanceType {SCENE, NODE}

var entity_tag: String = ""
var instance_type: InstanceType = InstanceType.SCENE:
	set(value):
		instance_type = value
		notify_property_list_changed()
var scene: PackedScene
var geometry_flags: int = 0:
	set(value):
		geometry_flags = value
		notify_property_list_changed()
var collision_shape: GatorUtil.CollisionShape = GatorUtil.CollisionShape.CONVEX
var collision_type: GatorUtil.CollisionType = GatorUtil.CollisionType.STATICBODY
var node_type: String = ""
var node_script: Script
var properties: Dictionary = {}

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
			p.append(GatorUtil.property("node_type", TYPE_STRING, PROPERTY_HINT_TYPE_STRING))
			p.append(GatorUtil.property("node_script", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Script"))
	p.append(GatorUtil.property("geometry_flags", TYPE_INT, PROPERTY_HINT_FLAGS, "Visual,Collision"))
	if geometry_flags & GatorUtil.GeometryFlag.COLLISION:
		p.append(GatorUtil.property("collision_shape", TYPE_INT, PROPERTY_HINT_ENUM, "Convex,Concave"))
		p.append(GatorUtil.property("collision_type", TYPE_INT, PROPERTY_HINT_ENUM, "StaticBody3D,Area3D,RigidBody3D,CharacterBody3D"))
	p.append(GatorUtil.property("properties", TYPE_DICTIONARY))
	
	return p
