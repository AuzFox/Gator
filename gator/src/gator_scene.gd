tool
class_name GatorScene
extends Spatial

signal build_progress
signal build_success
signal build_fail

enum BuildMode {DATA, CROCOTILE}
enum EntityType {SCENE, EMPTY, IGNORE}

export (String, FILE, GLOBAL, "*.txt, *.TXT, *.crocotile, *.CROCOTILE") var data_file: String = ""
export var entity_collection: Resource
export var scene_scale: float = 1.0
export var use_global_origin: bool = false

class GatorBuildContext extends Reference:
	var build_mode: int
	var entity_objects: Array
	var entity_instances: Dictionary
	var toplevel_nodes: Array
	var instances_to_keep: Array
	var json_data: Dictionary
	var tag_map: Dictionary
	
	func _init():
		self.build_mode = BuildMode.DATA
		self.entity_objects = []
		self.entity_instances = {}
		self.toplevel_nodes = []
		self.instances_to_keep = []
		self.json_data = {}
		self.tag_map = {}

class GatorProperty extends Reference:
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

class GatorObject extends Reference:
	var name: String
	var entity_tag: String
	var entity_def: WeakRef
	var entity_type: int
	var properties_uuid_map: Dictionary
	var properties: Dictionary
	var points: Dictionary
	
	func _init(ctx: GatorBuildContext, data: Dictionary, scene_scale: float) -> void:
		self.name = data["name"]
		self.entity_tag = ""
		self.entity_def = weakref(null)
		self.entity_type = EntityType.IGNORE
		self.properties_uuid_map = {}
		self.properties = {}
		self.points = {}
		
		var raw_properties: Array
		match ctx.build_mode:
			BuildMode.DATA:
				raw_properties = data["custom"]
			BuildMode.CROCOTILE:
				raw_properties = data["properties"]["custom"]
		
		for raw_property in raw_properties:
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
			self.properties[pname] = GatorProperty.new(pname, raw_property)
		
		if self.entity_type == EntityType.SCENE:
			if ctx.tag_map.has(self.entity_tag):
				self.entity_def = weakref(ctx.tag_map[self.entity_tag])
			else:
				printerr("Gator: Entity tag \"%s\" on object \"%s\" does not exist in the entity collection. Instances will be ignored" % [self.entity_tag, self.name])
				self.entity_type = EntityType.IGNORE
		
		for raw_point in data["points"]:
			var pos: Dictionary = raw_point["pos"]
			self.points[raw_point["name"]] = Vector3(pos["x"], pos["y"], pos["z"]) * scene_scale
	
	func get_property_from_uuid(uuid: String) -> GatorProperty:
		return self.properties[self.properties_uuid_map[uuid]]

class GatorInstance extends Reference:
	var name: String
	var uuid: String
	var object: WeakRef
	var parent_uuid: String
	var properties: Dictionary
	var pos: Vector3
	var rot: Vector3
	var scene: WeakRef
	var keep: bool
	
	func _init(ctx: GatorBuildContext, object: WeakRef, data: Dictionary) -> void:
		var uuid_tag: String
		var parent_uuid_tag: String
		var pos_tag: String
		var rot_tag: String
		var rot_x_tag: String
		var rot_y_tag: String
		var rot_z_tag: String
		var raw_properties: Array
		
		# common initialization
		self.name = data["name"]
		self.object = object
		self.scene = weakref(null)
		self.keep = self.object.get_ref().entity_type != EntityType.IGNORE
		
		# .crocotile files stor data using different property names
		match ctx.build_mode:
			BuildMode.DATA:
				uuid_tag = "uuid"
				parent_uuid_tag = "parent"
				pos_tag = "pos"
				rot_tag = "rot"
				rot_x_tag = "x"
				rot_y_tag = "y"
				rot_z_tag = "z"
				raw_properties = data["custom"]
			BuildMode.CROCOTILE:
				uuid_tag = "id"
				parent_uuid_tag = "parentID"
				pos_tag = "position"
				rot_tag = "rotation"
				rot_x_tag = "_x"
				rot_y_tag = "_y"
				rot_z_tag = "_z"
				raw_properties = data["properties"]["custom"]
		
		# set uuid
		var raw_uuid = data[uuid_tag]
		if typeof(raw_uuid) == TYPE_STRING:
			self.uuid = raw_uuid
		else:
			self.uuid = str(int(raw_uuid))
		
		# set parent_uuid
		var raw_parent = data[parent_uuid_tag]
		if raw_parent == null:
			self.parent_uuid = "null"
		elif typeof(raw_parent) == TYPE_REAL:
			self.parent_uuid = str(int(raw_parent))
		else:
			self.parent_uuid = raw_parent
		
		# set properties
		var obj: GatorObject = self.object.get_ref() as GatorObject
		if obj.entity_type == EntityType.SCENE:
			var entity_def: GatorEntityDefinition = obj.entity_def.get_ref()
			
			self.properties = entity_def.properties.duplicate(true)
			for raw_property in raw_properties:
				var obj_property: GatorProperty = obj.get_property_from_uuid(raw_property["uuid"])
				self.properties[obj_property.name] = raw_property["value"]
		else:
			self.properties = {}
		
		# set pos and rot
		var raw_pos_rot: Dictionary = data[pos_tag]
		self.pos = Vector3(raw_pos_rot["x"], raw_pos_rot["y"], raw_pos_rot["z"])
		
		raw_pos_rot = data[rot_tag]
		self.rot = Vector3(
			raw_pos_rot[rot_x_tag],
			raw_pos_rot[rot_y_tag],
			raw_pos_rot[rot_z_tag]
		)

func build() -> void:
	var ctx: GatorBuildContext = GatorBuildContext.new()
	
	if entity_collection.entity_definitions.empty():
		printerr("Gator: Entity collection is empty")
		emit_signal("build_fail")
		return
	
	if data_file.ends_with(".crocotile") || data_file.ends_with(".CROCOTILE"):
		ctx.build_mode = BuildMode.CROCOTILE
	
	# build tag map
	for def in entity_collection.entity_definitions:
		ctx.tag_map[def.entity_tag] = def
	
	var build_steps: Array = [
		"_free_children",
		"_extract_json_data",
		"_parse_json_data",
		"_create_scene_tree",
		"_mark_branches_to_keep",
		"_prune_scene_tree",
		"_call_build_completed_callbacks"
	]
	
	var build_progress_percentage: float = 0.0
	for i in build_steps.size():
		var step: String = build_steps[i]
		if call(step, ctx) == false:
			emit_signal("build_fail")
			return
		
		build_progress_percentage = (float(i) / build_steps.size()) * 100.0
		emit_signal("build_progress", build_progress_percentage)
		yield(GatorUtil.idle_frame(self), "timeout")
	
	emit_signal("build_success")

####################
# HELPER FUNCTIONS #
####################

func _spawn_instance(instance: GatorInstance):
	var obj: GatorObject = instance.object.get_ref() as GatorObject
	var new_scene
	
	match obj.entity_type:
		EntityType.SCENE:
			var entity_def: GatorEntityDefinition = instance.object.get_ref().entity_def.get_ref()
			new_scene = entity_def.scene.instance()
			new_scene.name = instance.name
		EntityType.EMPTY:
			new_scene = Spatial.new()
			new_scene.name = instance.name
		EntityType.IGNORE:
			new_scene = Spatial.new()
			new_scene.name = "%s (ignored)" % instance.name
	
	instance.scene = weakref(new_scene)
	return new_scene

###############
# BUILD STEPS #
###############

func _free_children(ctx: GatorBuildContext) -> bool:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	return true

func _extract_json_data(ctx: GatorBuildContext) -> bool:
	var file: File = File.new()
	if file.open(data_file, File.READ) != OK:
		printerr("Gator: Failed to open data file \"%s\"" % data_file)
		return false
	
	var raw_text: String = file.get_as_text()
	file.close()
	
	var parse_result: JSONParseResult = JSON.parse(raw_text)
	if parse_result.error != OK:
		printerr("Gator: Failed to parse data file \"%s\"" % data_file)
		return false
	
	ctx.json_data = parse_result.result
	
	return true

func _parse_json_data(ctx: GatorBuildContext) -> bool:
	var objects_tag: String
	
	match ctx.build_mode:
		BuildMode.DATA:
			objects_tag = "objects"
		BuildMode.CROCOTILE:
			objects_tag = "prefabs"
	
	var objects: Array = ctx.json_data[objects_tag]
	for raw_obj in objects:
		if raw_obj.has("type") && raw_obj["type"] == "instance":
			continue
		
		var obj: GatorObject = GatorObject.new(ctx, raw_obj, scene_scale)
		
		for raw_instance in raw_obj["instances"]:
			var instance: GatorInstance = GatorInstance.new(ctx, weakref(obj), raw_instance)
			
			if instance.keep:
				ctx.instances_to_keep.append(instance)
			
			ctx.entity_instances[instance.uuid] = instance
		
		ctx.entity_objects.append(obj)
	
	if ctx.build_mode == BuildMode.CROCOTILE:
		# toplevel instances have parent_uuids pointing to invalid objects,
		# replace them with "null"
		for instance in ctx.entity_instances.values():
			if !ctx.entity_instances.has(instance.parent_uuid):
				instance.parent_uuid = "null"
	
	return true

func _create_scene_tree(ctx: GatorBuildContext) -> bool:
	for instance in ctx.entity_instances.values():
		# create this instance if it doesn't exist already
		var scene = instance.scene.get_ref()
		if scene == null:
			scene = _spawn_instance(instance)
		
		# instance parent (if needed), then add current instance as a child
		if instance.parent_uuid != "null":
			var parent: GatorInstance = ctx.entity_instances[instance.parent_uuid]
			var parent_scene = parent.scene.get_ref()
			
			if parent_scene == null:
				parent_scene = _spawn_instance(parent)
			
			parent_scene.add_child(scene)
		else:
			add_child(scene)
			ctx.toplevel_nodes.append(scene)
		
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

func _mark_branches_to_keep(ctx: GatorBuildContext) -> bool:
	for instance in ctx.instances_to_keep:
		var prev: GatorInstance = instance as GatorInstance
		var parent_uuid = instance.parent_uuid
		while parent_uuid != "null":
			var parent: GatorInstance = ctx.entity_instances[parent_uuid]
			
			if prev.keep:
				parent.keep = true
			
			prev = parent
			parent_uuid = parent.parent_uuid
	return true

func _prune_scene_tree(ctx: GatorBuildContext) -> bool:
	var edited_root = get_tree().edited_scene_root
	var node_stack: Array = []
	
	if ctx.toplevel_nodes.empty(): # sanity check, maybe not needed?
		return true
	
	for i in range(ctx.toplevel_nodes.size() - 1, -1, -1): # iterate backwards to allow removal
		var top_node = ctx.toplevel_nodes[i]
		node_stack.append(top_node)
		while !node_stack.empty():
			var current = node_stack.pop_back()
			var keep: bool = true
			
			if current.has_meta("gt_instance"):
				var instance: GatorInstance = current.get_meta("gt_instance") as GatorInstance
				keep = instance.keep
				current.remove_meta("gt_instance")
			
			if keep:
				current.owner = edited_root
			
				if current.get_child_count() > 0:
					var children: Array = current.get_children()
					children.invert()
					node_stack.append_array(children)
			else:
				if current == top_node:
					ctx.toplevel_nodes.remove(i)
				current.get_parent().remove_child(current)
				current.queue_free()
	
	return true

func _call_build_completed_callbacks(ctx: GatorBuildContext) -> bool:
	var edited_root = get_tree().edited_scene_root
	var node_stack: Array = []
	for node in ctx.toplevel_nodes:
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
