class_name GatorUtil
extends Reference

enum GeometryFlag {VISUAL=1, COLLISION=2}
enum CollisionShape {CONVEX, CONCAVE}
enum CollisionType {STATICBODY, AREA, RIGIDBODY, KINEMATICBODY}

class GatorFrameTimer extends Node:
	signal timeout
	
	var frames: int = 1
	
	func _init(frames: int):
		self.frames = frames
	
	func _ready() -> void:
		get_tree().connect("idle_frame", self, "on_idle_frame")
	
	func on_idle_frame() -> void:
		self.frames -= 1
		
		if self.frames == 0:
			emit_signal("timeout")
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
	var temp = array[a]
	array[a] = array[b]
	array[b] = temp

static func load_texture_data(raw_texture: String, texture_flags: int):
	var start: int = raw_texture.find(",")
	raw_texture = raw_texture.substr(start + 1)
	var texture_bin: PoolByteArray = Marshalls.base64_to_raw(raw_texture)
	var image: Image = Image.new()
	var result: int = image.load_png_from_buffer(texture_bin)
	if result == OK:
		var tex: ImageTexture = ImageTexture.new()
		tex.create_from_image(image, texture_flags)
		return tex
	else:
		return null
