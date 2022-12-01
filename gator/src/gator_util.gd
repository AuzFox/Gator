class_name GatorUtil
extends RefCounted

enum GeometryFlag {VISUAL=1, COLLISION=2}
enum CollisionShape {CONVEX, CONCAVE}
enum CollisionType {STATICBODY, AREA, RIGIDBODY, CHARACTERBODY}

class GatorFrameTimer extends Node:
	signal timeout
	
	var frames: int = 1
	
	func _init(frames: int):
		self.frames = frames
	
	func _ready() -> void:
		get_tree().process_frame.connect(on_idle_frame)
	
	func on_idle_frame() -> void:
		self.frames -= 1
		
		if self.frames == 0:
			timeout.emit()
			queue_free()

static func idle_frame(node: Node, frames: int = 1) -> GatorFrameTimer:
	var timer: GatorFrameTimer = GatorFrameTimer.new(frames)
	node.add_child(timer)
	return timer

static func catagory(name: String) -> Dictionary:
	return property(name, TYPE_NIL, PROPERTY_HINT_NONE, "", PROPERTY_USAGE_CATEGORY)

static func property(
		name: String,
		type: int,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = "",
		usage: int = PROPERTY_USAGE_DEFAULT) -> Dictionary:
	return {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
		"usage": usage
	}

static func array_swap(array: Array, a: int, b: int) -> void:
	var temp: Variant = array[a]
	array[a] = array[b]
	array[b] = temp

static func load_texture_data(raw_texture: String) -> Variant:
	var data_start: int = raw_texture.find(",")
	var ext_start: int = raw_texture.find("/")
	var ext_end: int = raw_texture.find(";")
	var texture_ext: String = raw_texture.substr(ext_start + 1, ext_end - ext_start - 1)
	var texture_bin: PackedByteArray = Marshalls.base64_to_raw(raw_texture.substr(data_start + 1))
	var image: Image = Image.new()
	var result: int
	
	match texture_ext:
		"png":
			result = image.load_png_from_buffer(texture_bin)
		"jpg":
			result = image.load_jpg_from_buffer(texture_bin)
		"webp":
			result = image.load_webp_from_buffer(texture_bin)
		"tga":
			result = image.load_tga_from_buffer(texture_bin)
		"bmp":
			result = image.load_bmp_from_buffer(texture_bin)
		_:
			printerr("Gator: Unsupported image format \"%s\"", texture_ext)
			return null
	
	if result == OK:
		return ImageTexture.create_from_image(image)
	else:
		return null
