class_name GatorUtil
extends RefCounted

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
