extends Area2D

@export var camera_path: NodePath
@export var target_node: Node2D
@export var look_offset: Vector2 = Vector2.ZERO
@export var hover_speed: float = 12.0
@export var hover_priority: int = 0
@export var click_snap_zoom: Vector2 = Vector2(0.75, 0.75)
@export var click_snap_speed: float = 22.0

var _camera: TableCameraController


func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_camera = _resolve_camera()


func _on_mouse_entered() -> void:
	var camera := _resolve_camera()
	if camera == null:
		return

	camera.enter_hover_zone(self, _target_position(), hover_speed, hover_priority)


func _on_mouse_exited() -> void:
	var camera := _resolve_camera()
	if camera == null:
		return

	camera.exit_hover_zone(self)


func _input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := _resolve_camera()
		if camera == null:
			return

		camera.snap_to_zone(_target_position(), click_snap_zoom, click_snap_speed)
		get_viewport().set_input_as_handled()


func _target_position() -> Vector2:
	if target_node != null and is_instance_valid(target_node):
		return target_node.global_position + look_offset
	return global_position + look_offset


func _resolve_camera() -> TableCameraController:
	if _camera != null and is_instance_valid(_camera):
		return _camera

	if camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as TableCameraController

	if _camera == null:
		_camera = get_viewport().get_camera_2d() as TableCameraController

	return _camera
