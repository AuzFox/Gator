tool
extends EditorPlugin

var gator_scene_controls: Control = null
var edited_object_ref: WeakRef = weakref(null)

func get_plugin_name() -> String:
	return "Gator"

func handles(object: Object) -> bool:
	return object is GatorScene

func edit(object: Object) -> void:
	edited_object_ref = weakref(object)

func make_visible(visible: bool) -> void:
	if gator_scene_controls:
		gator_scene_controls.set_visible(visible)

func _enter_tree():
	gator_scene_controls = create_gator_scene_controls()
	gator_scene_controls.set_visible(false)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, gator_scene_controls)

func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, gator_scene_controls)
	gator_scene_controls.queue_free()
	gator_scene_controls = null

func create_gator_scene_controls() -> Control:
	var separator = VSeparator.new()

	var build_button = ToolButton.new()
	build_button.text = "Build"
	build_button.connect("pressed", self, "build_gator_scene")

	var control = HBoxContainer.new()
	control.add_child(separator)
	control.add_child(build_button)
	
	return control

func disable_gator_scene_controls(disable: bool) -> void:
	if not gator_scene_controls:
		return

	for child in gator_scene_controls.get_children():
		if child is ToolButton:
			child.set_disabled(disable)

func build_gator_scene() -> void:
	var edited_object = edited_object_ref.get_ref()
	if !edited_object:
		return

	if !(edited_object is GatorScene):
		return
	
	disable_gator_scene_controls(true)
	edited_object.connect("build_success", self, "on_build_success", [], CONNECT_ONESHOT)
	edited_object.connect("build_fail", self, "on_build_fail", [], CONNECT_ONESHOT)
	
	print("Building %s..." % edited_object.data_file)
	
	edited_object.build()

func on_build_success() -> void:
	disable_gator_scene_controls(false)
	print("Done")

func on_build_fail() -> void:
	disable_gator_scene_controls(false)
	printerr("Gator: Build failed")
