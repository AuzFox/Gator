tool
class_name GatorScene
extends Spatial

signal build_progress
signal build_success
signal build_fail

export(String, FILE, GLOBAL, "*.txt") var data_file: String = ""
export (Resource) var entity_collection
export var scene_scale: float = 1.0
export var use_global_origin: bool = false

var entity_objects: Array = []
var entity_instances: Dictionary = {}
var toplevel_nodes: Array = []
var instances_to_keep: Array = []

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
	enum EntityType {SCENE, EMPTY, IGNORE}
	
	var name: String
	var entity_tag: String
	var entity_def: WeakRef
	var entity_type: int # EntityType value
	var properties_uuid_map: Dictionary
	var properties: Dictionary
	var points: Dictionary
	
	func _init(tag_map: Dictionary, data: Dictionary, scene_scale: float) -> void:
		self.name = data["name"]
		self.entity_tag = ""
		self.entity_def = weakref(null)
		self.entity_type = EntityType.IGNORE
		self.properties_uuid_map = {}
		self.properties = {}
		self.points = {}
		
		for raw_property in data["custom"]:
			var pname: String = raw_property["name"]
			
			if raw_property["type"] == "object":
				if pname == "gt-tag":
					if raw_property["valueType"] == "string":
						self.entity_tag = raw_property["value"]
						self.entity_type = EntityType.SCENE
					else:
						printerr("Gator: Object \"%s\" property \"gt-tag\" must be a string. Instances will be ignored" % self.name)
					continue
				elif pname == "gt-empty":
					self.entity_type = EntityType.EMPTY
					continue
				elif pname == "gt-ignore":
					self.entity_type = EntityType.IGNORE
					continue
			
			self.properties_uuid_map[raw_property["uuid"]] = pname
			self.properties[pname] = GatorEntityProperty.new(pname, raw_property)
		
		if self.entity_type == EntityType.SCENE:
			if tag_map.has(self.entity_tag):
				self.entity_def = weakref(tag_map[self.entity_tag])
			else:
				printerr("Gator: Entity tag \"%s\" on object \"%s\" does not exist in the entity collection. Instances will be ignored" % [self.entity_tag, self.name])
				self.entity_type = EntityType.IGNORE
		
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
	var keep: bool
	
	func _init(object: WeakRef, data: Dictionary) -> void:
		self.name = data["name"]
		self.uuid = data["uuid"]
		self.object = object
		
		var raw_parent = data["parent"]
		if !raw_parent:
			self.parent_uuid = "null"
		else:
			self.parent_uuid = raw_parent
		
		var obj: GatorEntityObject = self.object.get_ref() as GatorEntityObject
		if obj.entity_type == GatorEntityObject.EntityType.SCENE:
			var entity_def: GatorEntityDefinition = obj.entity_def.get_ref()
			
			self.properties = entity_def.properties.duplicate(true)
			for raw_property in data["custom"]:
				var obj_property: GatorEntityProperty = obj.get_property_from_uuid(raw_property["uuid"])
				self.properties[obj_property.name] = raw_property["value"]
		else:
			self.properties = {}
		
		var raw_pos_rot: Dictionary = data["pos"]
		self.pos = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		raw_pos_rot = data["rot"]
		self.rot = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		self.scene = weakref(null)
		self.keep = self.object.get_ref().entity_type != GatorEntityObject.EntityType.IGNORE

func build() -> void:
	var build_progress: float = 0.0
	var build_steps: Array = [
		"_free_children",
		"_parse_object_data",
		"_create_scene_tree",
		"_mark_branches_to_keep",
		"_prune_scene_tree",
		"_call_build_completed_callbacks"
	]
	
	if entity_collection.entity_definitions.empty():
		printerr("Gator: Entity collection is empty")
		emit_signal("build_fail")
		return
	
	for i in build_steps.size():
		var step: String = build_steps[i]
		if call(step) == false:
			emit_signal("build_fail")
			return
		
		build_progress = (float(i) / build_steps.size()) * 100.0
		emit_signal("build_progress", build_progress)
		yield(GatorUtil.idle_frame(self), "timeout")
	
	_clear_buffers()
	emit_signal("build_success")

func _clear_buffers() -> void:
	entity_objects.clear()
	entity_instances.clear()
	toplevel_nodes.clear()
	instances_to_keep.clear()

func _extract_object_data() -> Dictionary:
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

func _spawn_instance(instance: GatorEntityInstance):
	var obj: GatorEntityObject = instance.object.get_ref() as GatorEntityObject
	var new_scene
	
	match obj.entity_type:
		GatorEntityObject.EntityType.SCENE:
			var entity_def: GatorEntityDefinition = instance.object.get_ref().entity_def.get_ref()
			new_scene = entity_def.scene.instance()
			new_scene.name = instance.name
		GatorEntityObject.EntityType.EMPTY:
			new_scene = Spatial.new()
			new_scene.name = instance.name
		GatorEntityObject.EntityType.IGNORE:
			new_scene = Spatial.new()
			new_scene.name = "%s (ignored)" % instance.name
	
	instance.scene = weakref(new_scene)
	return new_scene

func _free_children() -> bool:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	return true

func _parse_object_data() -> bool:
	var data: Dictionary
	var tag_map: Dictionary = {}
	
	data = _extract_object_data()
	if data.empty():
		return false
	
	for def in entity_collection.entity_definitions:
		tag_map[def.entity_tag] = def
	
	for raw_obj in data["objects"]:
		var obj: GatorEntityObject = GatorEntityObject.new(tag_map, raw_obj, scene_scale)
		for raw_instance in raw_obj["instances"]:
			var instance: GatorEntityInstance = GatorEntityInstance.new(weakref(obj), raw_instance)
			
			if instance.keep:
				instances_to_keep.append(instance)
			
			entity_instances[instance.uuid] = instance
		
		entity_objects.append(obj)
	
	return true

func _create_scene_tree() -> bool:
	for instance in entity_instances.values():
		# create this instance if it doesn't exist already
		var scene = instance.scene.get_ref()
		if scene == null:
			scene = _spawn_instance(instance)
		
		# instance parent (if needed), then add current instance as a child
		if instance.parent_uuid != "null":
			var parent: GatorEntityInstance = entity_instances[instance.parent_uuid]
			var parent_scene = parent.scene.get_ref()
			
			if parent_scene == null:
				parent_scene = _spawn_instance(parent)
			
			parent_scene.add_child(scene)
		else:
			add_child(scene)
			toplevel_nodes.append(scene)
		
		scene.set_meta("gt_instance", instance)
		
		if scene is Spatial:
			if use_global_origin:
				if instance.parent_uuid == "null":
					scene.global_translation = instance.pos * scene_scale
					scene.global_rotation = instance.rot
				else:
					scene.translation = instance.pos * scene_scale
					scene.rotation = instance.rot
			else:
				scene.translation = instance.pos * scene_scale
				scene.rotation = instance.rot
		
		if "properties" in scene:
			scene.properties = instance.properties
		
		if "points" in scene:
			scene.points = instance.object.get_ref().points.duplicate(true)
	
	return true

func _mark_branches_to_keep() -> bool:
	for instance in instances_to_keep:
		var prev: GatorEntityInstance = instance as GatorEntityInstance
		var parent_uuid = instance.parent_uuid
		while parent_uuid != "null":
			var parent: GatorEntityInstance = entity_instances[parent_uuid]
			
			if prev.keep:
				parent.keep = true
			
			prev = parent
			parent_uuid = parent.parent_uuid
	return true

func _prune_scene_tree() -> bool:
	var edited_root = get_tree().edited_scene_root
	var node_stack: Array = []
	
	if toplevel_nodes.empty(): # sanity check, maybe not needed?
		return true
	
	for i in range(toplevel_nodes.size() - 1, -1, -1): # iterate backwards to allow removal
		var top_node = toplevel_nodes[i]
		node_stack.append(top_node)
		while !node_stack.empty():
			var current = node_stack.pop_back()
			var instance: GatorEntityInstance = current.get_meta("gt_instance") as GatorEntityInstance
			
			current.remove_meta("gt_instance")
			
			if instance.keep:
				current.owner = edited_root
			
				if current.get_child_count() > 0:
					var children: Array = current.get_children()
					children.invert()
					node_stack.append_array(children)
			else:
				if current == top_node:
					toplevel_nodes.remove(i)
				current.get_parent().remove_child(current)
				current.queue_free()
	
	return true

func _call_build_completed_callbacks() -> bool:
	var edited_root = get_tree().edited_scene_root
	var node_stack: Array = []
	for node in toplevel_nodes:
		node_stack.append(node)
		while !node_stack.empty():
			var current = node_stack.pop_back()
			
			var script = current.get_script()
			if script && script.is_tool() && current.has_method("_on_build_completed"):
				current._on_build_completed()
			
			if current.get_child_count() > 0:
				var children: Array = current.get_children()
				children.invert()
				node_stack.append_array(children)
	
	return true
