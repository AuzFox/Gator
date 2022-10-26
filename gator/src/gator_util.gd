extends Reference
class_name GatorUtil

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
