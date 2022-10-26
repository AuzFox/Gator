tool
extends EditorPlugin

var gator_scene_controls: Control = null
var build_progress_bar: WeakRef = weakref(null)
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
	if gator_scene_controls:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, gator_scene_controls)
		gator_scene_controls.queue_free()
		gator_scene_controls = null

func create_gator_scene_controls() -> Control:
	var separator: VSeparator = VSeparator.new()

	var build_button: ToolButton = ToolButton.new()
	build_button.text = "Build"
	build_button.connect("pressed", self, "build_gator_scene")
	
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.rect_min_size = Vector2(100, 0)
	progress_bar.rounded = true
	progress_bar.set_visible(false)
	build_progress_bar = weakref(progress_bar)

	var control: HBoxContainer = HBoxContainer.new()
	control.add_child(build_button)
	control.add_child(separator)
	control.add_child(progress_bar)
	
	return control

func disable_gator_scene_controls(disable: bool) -> void:
	if !gator_scene_controls:
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
	
	var progress_bar: ProgressBar = build_progress_bar.get_ref()
	progress_bar.set_visible(true)
	progress_bar.value = 0.0
	
	edited_object.connect("build_progress", self, "on_build_progress")
	edited_object.connect("build_success", self, "on_build_success", [edited_object])
	edited_object.connect("build_fail", self, "on_build_fail", [edited_object])
	
	print("Building %s..." % edited_object.data_file)
	
	edited_object.build()

func disconnect_gator_scene(gator_scene: GatorScene) -> void:
	if gator_scene.is_connected("build_progress", self, "on_build_progress"):
		gator_scene.disconnect("build_progress", self, "on_build_progress")
	
	if gator_scene.is_connected("build_success", self, "on_build_success"):
		gator_scene.disconnect("build_success", self, "on_build_success")
	
	if gator_scene.is_connected("build_fail", self, "on_build_fail"):
		gator_scene.disconnect("build_fail", self, "on_build_fail")

func on_build_progress(progress: float) -> void:
	var progress_bar: ProgressBar = build_progress_bar.get_ref()
	
	progress_bar.value = progress

func on_build_success(gator_scene: GatorScene) -> void:
	disconnect_gator_scene(gator_scene)
	disable_gator_scene_controls(false)
	build_progress_bar.get_ref().set_visible(false)
	print("Done")

func on_build_fail(gator_scene: GatorScene) -> void:
	disconnect_gator_scene(gator_scene)
	disable_gator_scene_controls(false)
	build_progress_bar.get_ref().set_visible(false)
	printerr("Gator: Build failed")
