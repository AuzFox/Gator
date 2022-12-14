tool
class_name GatorScene
extends Spatial

enum BuildMode {DATA, CROCOTILE}
enum EntityType {SCENE_NODE, GEOMETRY, EMPTY, IGNORE}

signal build_progress
signal build_success
signal build_fail

var data_file: String = "" setget set_data_file
var entity_collection: GatorEntityCollection setget set_entity_collection
var scene_scale: float = 1.0
var use_global_origin: bool = false
var textures_directory: String = ""
var embedded_texture_flags: int = Texture.FLAGS_DEFAULT
var default_material: Material = null setget set_default_material
var default_albedo_uniform: String = ""
var scene_geometry_flags: int = 0 setget set_scene_geometry_flags
var scene_collision_shape: int = GatorUtil.CollisionShape.CONCAVE
var scene_collision_type: int = GatorUtil.CollisionType.STATICBODY

func set_data_file(value):
	data_file = value
	update_configuration_warning()

func set_entity_collection(value):
	entity_collection = value
	update_configuration_warning()

func set_scene_geometry_flags(value):
	scene_geometry_flags = value
	property_list_changed_notify()

func set_default_material(value):
	default_material = value
	property_list_changed_notify()

class GatorBuildContext extends Reference:
	var build_mode: int
	var entity_objects: Array
	var entity_instances: Dictionary
	var toplevel_nodes: Array
	var instances_to_keep: Array
	var json_data: Dictionary
	var tag_map: Dictionary
	var tilesets: Array
	var scene_tiles: Array
	
	func _init():
		self.build_mode = BuildMode.DATA
		self.entity_objects = []
		self.entity_instances = {}
		self.toplevel_nodes = []
		self.instances_to_keep = []
		self.json_data = {}
		self.tag_map = {}
		self.tilesets = []
		self.scene_tiles = []

class GatorTileset extends Reference:
	var texture_name: String
	var embedded_data: String
	
	func _init(data: Dictionary) -> void:
		self.texture_name = data["imgFile"]["name"]
		self.embedded_data = data["texture"]
	
	func generate_material(textures_dir: String, default_material: Material, default_albedo_uniform: String, texture_flags: int) -> Material:
		if !self.texture_name.empty():
			if !textures_dir.empty():
				var texture_name_no_ext: String = texture_name.rsplit(texture_name, false, 1)[1]
				var mat_tres_path: String = "%s/%s.tres" % [textures_dir, texture_name_no_ext]
				var mat_material_path: String = "%s/%s.material" % [textures_dir, texture_name_no_ext]
				var mat_res_path: String = "%s/%s.res" % [textures_dir, texture_name_no_ext]
				var image_path: String = "%s/%s" % [textures_dir, self.texture_name]
				
				if ResourceLoader.exists(mat_tres_path, "Material"):
					return load(mat_tres_path) as Material
				elif ResourceLoader.exists(mat_material_path, "Material"):
					return load(mat_material_path) as Material
				elif ResourceLoader.exists(mat_res_path, "Material"):
					return load(mat_res_path) as Material
				elif ResourceLoader.exists(image_path, "Texture"):
					var texture: Texture = load(image_path) as Texture
					var mat: Material
					
					if default_material != null:
						mat = default_material.duplicate()
					else:
						mat = SpatialMaterial.new()
					
					if mat is SpatialMaterial:
						mat.albedo_texture = texture
					elif mat is ShaderMaterial && default_albedo_uniform != "":
						mat.set_shader_parameter(default_albedo_uniform, texture)
					
					return mat
		
		var texture = GatorUtil.load_texture_data(self.embedded_data, texture_flags)
		if texture != null:
			var mat: Material
			
			if default_material != null:
				mat = default_material.duplicate()
			else:
				mat = SpatialMaterial.new()
			
			if mat is SpatialMaterial:
				mat.albedo_texture = texture
			elif mat is ShaderMaterial && default_albedo_uniform != "":
				mat.set_shader_parameter(default_albedo_uniform, texture)
			
			return mat
		else:
			printerr("Gator: Failed to load embedded image data")
			if default_material != null:
				return default_material.duplicate() as Material
			else:
				return SpatialMaterial.new()

class GatorTileMesh extends Reference:
	var pos: Vector3
	var vertices: Array
	var indices: Array
	var uvs: Array
	var colors: Array
	var tileset_index: int
	
	func _init(data: Dictionary, scene_scale: float) -> void:
		var raw_pos: Dictionary = data["position"]
		self.pos = Vector3(raw_pos["x"], raw_pos["y"], raw_pos["z"]) * scene_scale
		self.vertices = []
		self.indices = []
		self.uvs = []
		self.colors = []
		
		if data.has("texture"):
			self.tileset_index = int(data["texture"])
		
		for raw_vert in data["vertices"]:
			self.vertices.append(self.pos + (Vector3(raw_vert["x"], raw_vert["y"], raw_vert["z"]) * scene_scale))
		
		for tri_indices in data["faces"]:
			for raw_index in tri_indices:
				self.indices.append(int(raw_index))
		
		# swap winding order
		GatorUtil.array_swap(self.indices, 1, 2)
		GatorUtil.array_swap(self.indices, 4, 5)
		
		var raw_uvs: Array = data["uvs"]
		GatorUtil.array_swap(raw_uvs[0], 1, 2)
		GatorUtil.array_swap(raw_uvs[1], 1, 2)
		
		self.uvs.resize(4)
		for i in self.indices.size():
			var index: int = self.indices[i]
			if index < 4:
				var raw_uv: Dictionary = raw_uvs[int(i / 3)][i % 3]
				# flip uv Y coordinate:
				# C3D uses (0, 0) for bottom-left corner
				# Godot uses (0, 0) for top-left corner
				self.uvs[index] = Vector2(raw_uv["x"], 1.0 - raw_uv["y"])
		
		for raw_color in data["colors"]:
			self.colors.append(Color(raw_color["r"], raw_color["g"], raw_color["b"]))

class GatorMeshSurface extends Reference:
	var vertex_array: PoolVector3Array
	var index_array: PoolIntArray
	var uv_array: PoolVector2Array
	var color_array: PoolColorArray
	
	func _init() -> void:
		self.vertex_array = PoolVector3Array()
		self.index_array = PoolIntArray()
		self.uv_array = PoolVector2Array()
		self.color_array = PoolColorArray()
	
	func get_vertex_count() -> int:
		return self.vertex_array.size()
	
	func add_vertex(vertex: Vector3) -> void:
		self.vertex_array.append(vertex)
	
	func add_index(index: int) -> void:
		self.index_array.append(index)
	
	func add_uv(uv: Vector2) -> void:
		self.uv_array.append(uv)
	
	func add_color(color: Color) -> void:
		self.color_array.append(color)

class GatorMeshBuilder extends Reference:
	var mesh: ArrayMesh
	var surfaces: Array
	var surface_map: Dictionary
	var surface_count: int
	
	func _init() -> void:
		self.mesh = ArrayMesh.new()
		self.surfaces = []
		self.surface_map = {}
		self.surface_count = 0
		
	func _add_surface(tileset_index: int) -> GatorMeshSurface:
		var surface: GatorMeshSurface = GatorMeshSurface.new()
		self.surfaces.append(surface)
		self.surface_count += 1
		self.surface_map[tileset_index] = self.surface_count - 1
		return surface
	
	func add_tile(tile: GatorTileMesh) -> void:
		var surface: GatorMeshSurface
		if surface_map.has(tile.tileset_index):
			surface = self.surfaces[self.surface_map[tile.tileset_index]]
		else:
			surface = self._add_surface(tile.tileset_index)
		
		var index_start: int = surface.get_vertex_count()
		
		for vertex in tile.vertices:
			surface.add_vertex(vertex)
		
		for index in tile.indices:
			surface.add_index(index_start + index)
		
		for uv in tile.uvs:
			surface.add_uv(uv)
		
		for color in tile.colors:
			surface.add_color(color)
	
	func commit() -> void:
		for surface in surfaces:
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			
			arr[Mesh.ARRAY_VERTEX] = surface.vertex_array
			arr[Mesh.ARRAY_INDEX] = surface.index_array
			arr[Mesh.ARRAY_TEX_UV] = surface.uv_array
			arr[Mesh.ARRAY_COLOR] = surface.color_array
			
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

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
	var geometry_flags: int # only used when 'gt-geometry' property is defined
	var collision_shape: int # only used when 'gt-geometry' property is defined
	var collision_type: int # only used when 'gt-geometry' property is defined
	var properties_uuid_map: Dictionary
	var properties: Dictionary
	var points: Dictionary
	var tiles: Array
	
	func _init(ctx: GatorBuildContext, data: Dictionary, scene_scale: float) -> void:
		self.name = data["name"]
		self.entity_tag = ""
		self.entity_def = weakref(null)
		self.entity_type = EntityType.IGNORE
		self.geometry_flags = 0
		self.collision_shape = GatorUtil.CollisionShape.CONVEX
		self.collision_type = GatorUtil.CollisionType.STATICBODY
		self.properties_uuid_map = {}
		self.properties = {}
		self.points = {}
		self.tiles = []
		
		var raw_properties: Array
		match ctx.build_mode:
			BuildMode.DATA:
				raw_properties = data["custom"]
			BuildMode.CROCOTILE:
				raw_properties = data["properties"]["custom"]
				for raw_tile in data["object"]:
					self.tiles.append(GatorTileMesh.new(raw_tile, scene_scale))
		
		for raw_property in raw_properties:
			var pname: String = raw_property["name"]
			
			if raw_property["type"] == "object":
				match pname:
					"gt-tag":
						if raw_property["valueType"] == "string":
							self.entity_tag = raw_property["value"]
							self.entity_type = EntityType.SCENE_NODE
						else:
							printerr("Gator: Object \"%s\" property \"gt-tag\" must be a string. Instances will be ignored" % self.name)
						continue
					"gt-geometry":
						if raw_property["valueType"] == "string":
							var flag_strings: PoolStringArray = raw_property["value"].split(",", false)
							for flag_string in flag_strings:
								var do_split = true
								
								if flag_string.begins_with("all:"):
									self.geometry_flags = (GatorUtil.GeometryFlag.VISUAL | GatorUtil.GeometryFlag.COLLISION)
								elif flag_string.begins_with("collision:"):
									self.geometry_flags |= GatorUtil.GeometryFlag.COLLISION
								else:
									do_split = false
								
								if do_split:
									var start: int = flag_string.find(":")
									flag_string = flag_string.substr(start + 1)
									
									var collision_flags: PoolStringArray = flag_string.split(":", false)
									for collision_flag in collision_flags:
										match collision_flag:
											"convex":
												self.collision_shape = GatorUtil.CollisionShape.CONVEX
											"concave":
												self.collision_shape = GatorUtil.CollisionShape.CONCAVE
											"staticbody":
												self.collision_type = GatorUtil.CollisionType.STATICBODY
											"area":
												self.collision_type = GatorUtil.CollisionType.AREA
											"rigidbody":
												self.collision_type = GatorUtil.CollisionType.RIGIDBODY
											"kinematicbody":
												self.collision_type = GatorUtil.CollisionType.KINEMATICBODY
											_:
												printerr("Gator: Object \"%s\": invalid gt-geometry collision flag \"%s\"" % [self.name, collision_flag])
								else:
									match flag_string:
										"all":
											self.geometry_flags = (GatorUtil.GeometryFlag.VISUAL | GatorUtil.GeometryFlag.COLLISION)
										"visual":
											self.geometry_flags |= GatorUtil.GeometryFlag.VISUAL
										"collision":
											self.geometry_flags |= GatorUtil.GeometryFlag.COLLISION
										_:
											printerr("Gator: Object \"%s\": invalid gt-geometry value flag \"%s\"" % [self.name, flag_string])
							
							self.entity_type = EntityType.GEOMETRY
						else:
							printerr("Gator: Object \"%s\" property \"gt-geometry\" must be a string. Instances will be ignored" % self.name)
						continue
					"gt-empty":
						self.entity_type = EntityType.EMPTY
						continue
					"gt-ignore":
						self.entity_type = EntityType.IGNORE
						continue
			
			self.properties_uuid_map[raw_property["uuid"]] = pname
			self.properties[pname] = GatorProperty.new(pname, raw_property)
		
		if self.entity_type == EntityType.SCENE_NODE:
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
		if obj.entity_type == EntityType.SCENE_NODE:
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

func _get_configuration_warning() -> String:
	var warnings: String = ""
	
	if data_file == "":
		warnings += "Missing data_file property"
	if !is_instance_valid(entity_collection):
		warnings += "\nMissing entity_collection property"
	
	return warnings

func _get_property_list() -> Array:
	var p: Array = [
		GatorUtil.catagory("GatorScene"),
		GatorUtil.property("data_file", TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE),
		GatorUtil.property("entity_collection", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Resource"),
		GatorUtil.property("scene_scale", TYPE_REAL),
		GatorUtil.property("use_global_origin", TYPE_BOOL),
		GatorUtil.property("textures_directory", TYPE_STRING, PROPERTY_HINT_GLOBAL_DIR),
		GatorUtil.property("embedded_texture_flags", TYPE_INT, PROPERTY_HINT_FLAGS, "Mipmaps,Repeat,Filter,Anisotropic Filter,Convert To Linear,Mirrored Repeat"),
		GatorUtil.property("default_material", TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "Material"),
	]
	
	if default_material != null && default_material is ShaderMaterial:
		p.append(GatorUtil.property("default_albedo_uniform", TYPE_STRING))
	
	p.append(GatorUtil.property("scene_geometry_flags", TYPE_INT, PROPERTY_HINT_FLAGS, "Visual,Collision"))
	
	if scene_geometry_flags & GatorUtil.GeometryFlag.COLLISION:
		p.append(GatorUtil.property("scene_collision_shape", TYPE_INT, PROPERTY_HINT_ENUM, "Convex,Concave"))
		p.append(GatorUtil.property("scene_collision_type", TYPE_INT, PROPERTY_HINT_ENUM, "StaticBody,Area,RigidBody,KinematicBody"))
	
	return p

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

func _position_node(node, is_toplevel: bool, pos: Vector3, rot: Vector3) -> void:
	if node == null:
		return
	
	if use_global_origin && is_toplevel:
		node.global_translation = pos * scene_scale
		node.global_rotation = rot
	else:
		node.translation = pos * scene_scale
		node.rotation = rot

func _build_geometry(
		parent: Node,
		set_owners: bool,
		tiles: Array,
		tilesets: Array,
		flags: int,
		collision_shape: int,
		collision_type: int) -> void:
	if flags == 0:
		return
	
	if flags & GatorUtil.GeometryFlag.VISUAL:
		var mb: GatorMeshBuilder = GatorMeshBuilder.new()
		for tile in tiles:
			mb.add_tile(tile)
		
		mb.commit()
		
		for tileset_index in mb.surface_map.keys():
			var tileset: GatorTileset = tilesets[tileset_index]
			var mat: Material = tileset.generate_material(textures_directory, default_material, default_albedo_uniform, embedded_texture_flags)
			mb.mesh.surface_set_material(mb.surface_map[tileset_index], mat)
		
		if parent is MeshInstance:
			parent.mesh = mb.mesh
		else:
			var mesh_instance: MeshInstance = MeshInstance.new()
			mesh_instance.mesh = mb.mesh
			mesh_instance.name = "mesh"
			
			parent.add_child(mesh_instance)
			
			if set_owners:
				mesh_instance.owner = get_tree().edited_scene_root
	if flags & GatorUtil.GeometryFlag.COLLISION:
		var col_shape: Shape
		
		var points: PoolVector3Array = PoolVector3Array()
		match collision_shape:
			GatorUtil.CollisionShape.CONVEX:
				for tile in tiles:
					for vert in tile.vertices:
						points.append(vert)
				
				col_shape = ConvexPolygonShape.new()
				col_shape.set_points(points)
			GatorUtil.CollisionShape.CONCAVE:
				for tile in tiles:
					for index in tile.indices:
						points.append(tile.vertices[index])
				
				col_shape = ConcavePolygonShape.new()
				col_shape.set_faces(points)
		
		if parent is CollisionShape:
			parent.shape = col_shape
		elif parent is CollisionObject:
			var shape_node: CollisionShape = null
			for child in parent.get_children():
				if child is CollisionShape:
					shape_node = child
					break
			
			if shape_node == null:
				shape_node = CollisionShape.new()
			
				shape_node.name = "collision_shape"
				
				parent.add_child(shape_node)
				
				if set_owners:
					shape_node.owner = get_tree().edited_scene_root
			
			shape_node.shape = col_shape
		else:
			var collision_node: CollisionObject
			match collision_type:
				GatorUtil.CollisionType.STATICBODY:
					collision_node = StaticBody.new()
				GatorUtil.CollisionType.AREA:
					collision_node = Area.new()
				GatorUtil.CollisionType.RIGIDBODY:
					collision_node = RigidBody.new()
				GatorUtil.CollisionType.KINEMATICBODY:
					collision_node = KinematicBody.new()
			
			collision_node.name = "collisions"
			
			var shape_node: CollisionShape = CollisionShape.new()
			shape_node.shape = col_shape
			shape_node.name = "collision_shape"
			
			parent.add_child(collision_node)
			collision_node.add_child(shape_node)
			
			if set_owners:
				shape_node.owner = get_tree().edited_scene_root
				collision_node.owner = get_tree().edited_scene_root

func _spawn_instance(instance: GatorInstance, tilesets: Array):
	var obj: GatorObject = instance.object.get_ref() as GatorObject
	var new_scene
	
	match obj.entity_type:
		EntityType.SCENE_NODE:
			var entity_def: GatorEntityDefinition = instance.object.get_ref().entity_def.get_ref()
			match entity_def.instance_type:
				GatorEntityDefinition.InstanceType.SCENE:
					new_scene = entity_def.scene.instantiate()
					new_scene.name = instance.name
				GatorEntityDefinition.InstanceType.NODE:
					if ClassDB.class_exists(entity_def.node_type) && ClassDB.can_instantiate(entity_def.node_type):
						new_scene = ClassDB.instantiate(entity_def.node_type)
						new_scene.name = instance.name
						if entity_def.node_script != null:
							if is_instance_valid(entity_def.node_script):
								new_scene.set_script(entity_def.node_script)
							else:
								printerr("Gator: Invalid script assigned to instance \"%s\"" % instance.name)
					else:
						printerr("Gator: Invalid node type in instance \"%s\". Using Node3D instead" % instance.name)
						new_scene = Spatial.new()
						new_scene.name = "%s (invalid node type)" % instance.name
			
			_build_geometry(
				new_scene,
				false,
				obj.tiles,
				tilesets,
				entity_def.geometry_flags,
				entity_def.collision_shape,
				entity_def.collision_type)
		EntityType.GEOMETRY:
			new_scene = Spatial.new()
			new_scene.name = instance.name
			
			_build_geometry(
				new_scene,
				false,
				obj.tiles,
				tilesets,
				obj.geometry_flags,
				obj.collision_shape,
				obj.collision_type)
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
			
			var models: Array = ctx.json_data["model"]
			for model in models:
				ctx.tilesets.append(GatorTileset.new(model))
				
				for raw_tile in model["object"]:
					var tile: GatorTileMesh = GatorTileMesh.new(raw_tile, scene_scale)
					tile.tileset_index = ctx.tilesets.size() - 1
					ctx.scene_tiles.append(tile)
	
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
	_build_geometry(
		self,
		true,
		ctx.scene_tiles,
		ctx.tilesets,
		scene_geometry_flags,
		scene_collision_shape,
		scene_collision_type)
	_position_node(get_node_or_null("mesh"), true, Vector3.ZERO, Vector3.ZERO)
	_position_node(get_node_or_null("collisions"), true, Vector3.ZERO, Vector3.ZERO)
	
	for instance in ctx.entity_instances.values():
		# create this instance if it doesn't exist already
		var scene = instance.scene.get_ref()
		if scene == null:
			scene = _spawn_instance(instance, ctx.tilesets)
		
		# instance parent (if needed), then add current instance as a child
		if instance.parent_uuid != "null":
			var parent: GatorInstance = ctx.entity_instances[instance.parent_uuid]
			var parent_scene = parent.scene.get_ref()
			
			if parent_scene == null:
				parent_scene = _spawn_instance(parent, ctx.tilesets)
			
			parent_scene.add_child(scene)
		else:
			add_child(scene)
			ctx.toplevel_nodes.append(scene)
		
		scene.set_meta("gt_instance", instance)
		
		if scene is Spatial:
			_position_node(scene, instance.parent_uuid == "null", instance.pos, instance.rot)
		
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
			if script && (!Engine.editor_hint || script.is_tool()) && current.has_method("_on_build_completed"):
				current._on_build_completed()
			
			if current.get_child_count() > 0:
				var children: Array = current.get_children()
				children.invert()
				node_stack.append_array(children)
	
	return true
