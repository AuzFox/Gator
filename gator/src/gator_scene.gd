tool
class_name GatorScene
extends Spatial

export(String, FILE, GLOBAL, "*.txt") var data_file: String = ""
export (Resource) var entity_collection
export var scene_scale: float = 1.0

class GatorEntityProperty extends Reference:
	var name: String
	var type: String
	var valueType: String
	var value
	
	func _init(name: String, data: Dictionary) -> void:
		self.name = name
		self.type = data["type"]
		self.valueType = data["valueType"]
		self.value = data["value"]
		
		if self.valueType == "string":
			self.value = str2var(self.value)

class GatorEntityObject extends Reference:
	var name: String
	var entity_tag: String
	var properties_uuid_map: Dictionary
	var properties: Dictionary
	var points: Dictionary
	var ignore: bool
	
	func _init(data: Dictionary, scene_scale: float) -> void:
		self.name = data["name"]
		self.entity_tag = ""
		self.properties_uuid_map = {}
		self.properties = {}
		self.points = {}
		self.ignore = false
		
		for raw_property in data["custom"]:
			var pname: String = raw_property["name"]
			
			if raw_property["type"] == "object":
				if pname == "gt-tag":
					if raw_property["valueType"] == "string":
						self.entity_tag = raw_property["value"]
					else:
						printerr("Gator: Object \"%s\" property \"gt-tag\" must be a string. Instances will be ignored" % self.name)
						self.ignore = true
					continue
				elif pname == "gt-ignore":
					self.ignore = true
					continue
			
			self.properties_uuid_map[raw_property["uuid"]] = pname
			self.properties[pname] = GatorEntityProperty.new(pname, raw_property)
		
		for raw_point in data["points"]:
			var pos: Dictionary = raw_point["pos"]
			self.points[raw_point["name"]] = Vector3(pos["x"], pos["y"], pos["z"]) * scene_scale
	
	func get_property_from_uuid(uuid: String) -> GatorEntityProperty:
		return self.properties[self.properties_uuid_map[uuid]]

class GatorEntityInstance extends Reference:
	var name: String
	var uuid: String
	var object: WeakRef
	var parent_uuid: String
	var properties: Dictionary
	var pos: Vector3
	var rot: Vector3
	var scene: WeakRef
	
	func _init(object: WeakRef, data: Dictionary, scene_scale: float) -> void:
		self.name = data["name"]
		self.uuid = data["uuid"]
		self.object = object
		
		var raw_parent = data["parent"]
		if raw_parent == null:
			self.parent_uuid = "null"
		else:
			self.parent_uuid = raw_parent
		
		var raw_pos_rot: Dictionary = data["pos"]
		self.pos = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"]) * scene_scale
		
		raw_pos_rot = data["rot"]
		self.rot = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		self.scene = weakref(null)
	
	func set_properties(tag_map: Dictionary, entity_collection: GatorEntityCollection, data: Dictionary) -> void:
		var obj: GatorEntityObject = self.object.get_ref() as GatorEntityObject
		if obj.ignore:
			self.properties = {}
			return
		
		var entity_def: GatorEntityDefinition = entity_collection.entity_definitions[tag_map[obj.entity_tag]]
		
		self.properties = entity_def.properties.duplicate(true)
		for raw_property in data["custom"]:
			var obj_property: GatorEntityProperty = obj.get_property_from_uuid(raw_property["uuid"])
			self.properties[obj_property.name] = raw_property["value"]

func build() -> bool:
	_free_children()
	
	var tag_map: Dictionary = {}
	for i in entity_collection.entity_definitions.size():
		var def: GatorEntityDefinition = entity_collection.entity_definitions[i] as GatorEntityDefinition
		tag_map[def.entity_tag] = i
	
	if tag_map.empty():
		printerr("Gator: Entity collection is empty")
		return false
	
	var raw_data: Dictionary = _extract_json_data()
	if raw_data.empty():
		return false
	
	# extract object and instance data
	var entity_objects: Array = []
	var entity_instances: Dictionary = {}
	for raw_obj in raw_data["objects"]:
		var obj: GatorEntityObject = GatorEntityObject.new(raw_obj, scene_scale)
		
		if obj.entity_tag == "":
			obj.ignore = true
		elif !tag_map.has(obj.entity_tag):
			printerr("Gator: Entity tag \"%s\" on object \"%s\" does not exist in the entity collection. Instances will be ignored" % [obj.entity_tag, obj.name])
			obj.ignore = true
		
		for raw_instance in raw_obj["instances"]:
			var instance: GatorEntityInstance = GatorEntityInstance.new(weakref(obj), raw_instance, scene_scale)
			instance.set_properties(tag_map, entity_collection as GatorEntityCollection, raw_instance)
			entity_instances[instance.uuid] = instance
		
		entity_objects.append(obj)
	
	# construct scene
	for instance in entity_instances.values():
		# create this instance if it doesn't exist already
		var scene = instance.scene.get_ref()
		if scene == null:
			scene = _spawn_instance(tag_map, instance)
		
		# instance parent (if needed), then add current instance as a child
		if instance.parent_uuid != "null":
			var parent: GatorEntityInstance = entity_instances[instance.parent_uuid]
			var parent_scene = parent.scene.get_ref()
			
			if parent_scene == null:
				parent_scene = _spawn_instance(tag_map, parent)
			
			parent_scene.add_child(scene)
			scene.owner = get_tree().edited_scene_root
		elif scene:
			add_child(scene)
			scene.owner = get_tree().edited_scene_root
		
		# set properties
		if scene:
			if scene is Spatial:
				scene.global_translation = instance.pos
				scene.global_rotation = instance.rot
			
			if "properties" in scene:
				scene.properties = instance.properties
			
			if "points" in scene:
				scene.points = instance.object.get_ref().points.duplicate(true)
	
	return true

func _spawn_instance(tag_map: Dictionary, instance: GatorEntityInstance):
	var obj: GatorEntityObject = instance.object.get_ref()
	var new_scene
	
	if obj.ignore:
		if instance.parent_uuid != "null":
			new_scene = Spatial.new()
			new_scene.name = "! ignored object !"
			instance.scene = weakref(new_scene)
			return new_scene
		else:
			return null
	
	var entity_def: GatorEntityDefinition = entity_collection.entity_definitions[tag_map[obj.entity_tag]]
	
	if entity_def.entity_type == GatorEntityDefinition.EntityType.SCENE:
		new_scene = entity_def.scene.instance()
	else:
		new_scene = Spatial.new()
	
	new_scene.name = instance.name
	instance.scene = weakref(new_scene)
	return new_scene

func _free_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _extract_json_data() -> Dictionary:
	var fp: File = File.new()
	if fp.open(data_file, File.READ) != OK:
		printerr("Gator: Failed to open data file \"%s\"" % data_file)
		return {}
	
	var raw_text: String = fp.get_as_text()
	fp.close()
	
	var result: JSONParseResult = JSON.parse(raw_text)
	if result.error != OK:
		printerr("Gator: Failed to parse data file \"%s\"" % data_file)
		return {}
	
	return result.result
