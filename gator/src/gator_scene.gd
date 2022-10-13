tool
class_name GatorScene
extends Spatial

export(String, FILE, "*.txt") var data_file: String = ""
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
			if self.value.begins_with("Vector3(") || self.value.begins_with("Vector2("):
				self.value = str2var(self.value)
			elif self.value == "true":
				self.value = true
			elif self.value == "false":
				self.value = false

class GatorEntityObject extends Reference:
	var name: String
	var entity_tag: String
	var type: String
	var properties_uuid_map: Dictionary
	var properties: Dictionary
	var is_valid: bool
	
	func _init(name: String) -> void:
		self.name = name
		self.entity_tag = ""
		self.type = "scene"
		self.properties_uuid_map = {}
		self.properties = {}
		self.is_valid = true
	
	func is_tag_valid() -> bool:
		return self.is_valid && self.entity_tag != ""
	
	func is_type_valid() -> bool:
		return self.is_valid && (self.type == "scene" || self.type == "ignore" || self.type == "empty")
	
	func get_property_from_uuid(uuid: String) -> GatorEntityProperty:
		return properties[properties_uuid_map[uuid]]
	
	func add_property(data: Dictionary) -> void:
		var pname: String = data["name"]
		
		if data["type"] == "object":
			if pname == "gt_tag":
				if data["valueType"] == "string":
					self.entity_tag = data["value"]
					return
				else:
					print("gt_tag is not a string")
					self.is_valid = false
			elif pname == "gt_type":
				if data["valueType"] == "string":
					self.type = data["value"]
					return
				else:
					print("gt_type is not a string")
					self.is_valid = false
		
		properties_uuid_map[data["uuid"]] = pname
		properties[pname] = GatorEntityProperty.new(pname, data)

class GatorEntityInstance extends Reference:
	var name: String
	var uuid: String
	var object: WeakRef
	var parent_uuid: String
	var properties: Dictionary
	var pos: Vector3
	var rot: Vector3
	var scene: WeakRef
	
	func _init(name: String, uuid: String, object: WeakRef, data: Dictionary) -> void:
		self.name = name
		self.uuid = uuid
		self.object = object
		
		var raw_parent = data["parent"]
		if raw_parent == null:
			self.parent_uuid = "null"
		else:
			self.parent_uuid = raw_parent
		
		var raw_pos_rot: Dictionary = data["pos"]
		self.pos = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		raw_pos_rot = data["rot"]
		self.rot = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		self.scene = weakref(null)
	
	func set_properties(tag_map: Dictionary, entity_collection: GatorEntityCollection, data: Dictionary) -> void:
		var obj: GatorEntityObject = self.object.get_ref() as GatorEntityObject
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
		printerr("Gator: entity_collection is empty")
		return false
	
	var raw_data: Dictionary = _extract_json_data()
	if raw_data.empty():
		return false
	
	# extract object and instance data
	var entity_objects: Array = []
	var entity_instances: Dictionary = {}
	for raw_obj in raw_data["objects"]:
		var obj: GatorEntityObject = GatorEntityObject.new(raw_obj["name"])
		
		for raw_property in raw_obj["custom"]:
			obj.add_property(raw_property)
		
		if !obj.is_tag_valid():
			print("bad tag")
			return false
		
		if !obj.is_type_valid():
			print("bad type")
			return false
		
		for raw_instance in raw_obj["instances"]:
			var instance: GatorEntityInstance = GatorEntityInstance.new(
				raw_instance["name"],
				raw_instance["uuid"],
				weakref(obj),
				raw_instance
			)
			instance.set_properties(tag_map, entity_collection as GatorEntityCollection, raw_instance)
			entity_instances[instance.uuid] = instance
		
		entity_objects.append(obj)
	
	# construct scene
	for instance in entity_instances.values():
		# create this instance if it doesn't exist already
		var scene = instance.scene.get_ref()
		if scene == null:
			var obj: GatorEntityObject = instance.object.get_ref()
			var entity_def: GatorEntityDefinition = entity_collection.entity_definitions[tag_map[obj.entity_tag]]
			var new_scene = entity_def.scene.instance()
			new_scene.name = instance.name
			scene = new_scene
			instance.scene = weakref(new_scene)
		
		# instance parent (if needed), then add current instance as a child
		if instance.parent_uuid != "null":
			var parent: GatorEntityInstance = entity_instances[instance.parent_uuid]
			var parent_scene = parent.scene.get_ref()
			
			if parent_scene == null:
				var obj: GatorEntityObject = parent.object.get_ref()
				var entity_def: GatorEntityDefinition = entity_collection.entity_definitions[tag_map[obj.entity_tag]]
				var new_scene = entity_def.scene.instance()
				new_scene.name = parent.name
				parent_scene = new_scene
				parent.scene = weakref(new_scene)
			
			parent_scene.add_child(scene)
			scene.owner = get_tree().edited_scene_root
		else:
			add_child(scene)
			scene.owner = get_tree().edited_scene_root
		
		# set properties
		if scene is Spatial:
			scene.global_translation = instance.pos * scene_scale
			scene.global_rotation = instance.rot

		if "properties" in scene:
			scene.properties = instance.properties
	
	return true

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
