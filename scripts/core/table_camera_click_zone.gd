extends Area2D

@export var camera_path: NodePath
@export var target_node: Node2D
@export var look_offset: Vector2 = Vector2.ZERO
@export var click_target_node: Node2D
@export var click_look_offset: Vector2 = Vector2.ZERO
@export var hover_speed: float = 10.0
@export var hover_priority: int = 0
@export var click_snap_zoom: Vector2 = Vector2(1.25, 1.25)
@export var click_snap_speed: float = 22.0

var _camera: TableCameraController
var _hovering: bool = false


func _ready() -> void:
	input_pickable = true
	# collision_layer is a bitmask, so use per-layer setters to avoid accidental layer 2+4.
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_layer_value(10, true)
	_camera = _resolve_camera()


func _process(_delta: float) -> void:
	var mouse_in_zone := _is_mouse_in_zone()
	
	if mouse_in_zone and not _hovering:
		_hovering = true
		_on_mouse_entered()
	elif not mouse_in_zone and _hovering:
		_hovering = false
		_on_mouse_exited()


func _on_mouse_entered() -> void:
	var camera := _resolve_camera()
	if camera == null:
		return

	camera.enter_hover_zone(self, _hover_target_position(), hover_speed, hover_priority)


func _on_mouse_exited() -> void:
	var camera := _resolve_camera()
	if camera == null:
		return

	camera.exit_hover_zone(self)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := _resolve_camera()
		if camera == null:
			return

		camera.snap_to_zone(_click_target_position(), click_snap_zoom, click_snap_speed)


func _hover_target_position() -> Vector2:
	if target_node != null and is_instance_valid(target_node):
		return target_node.global_position + look_offset
	return global_position + look_offset


func _click_target_position() -> Vector2:
	if click_target_node != null and is_instance_valid(click_target_node):
		return click_target_node.global_position + click_look_offset

	# Fallback preserves previous behavior when no dedicated click target is configured.
	return _hover_target_position()


func _resolve_camera() -> TableCameraController:
	if _camera != null and is_instance_valid(_camera):
		return _camera

	if camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as TableCameraController

	if _camera == null:
		_camera = get_viewport().get_camera_2d() as TableCameraController

	return _camera


func _is_mouse_in_zone() -> bool:
	var mouse_pos := get_global_mouse_position()
	for child in get_children():
		if child is CollisionShape2D:
			var shape := child as CollisionShape2D
			var local_mouse := mouse_pos - (global_position + shape.position)
			if shape.shape.get_rect().has_point(local_mouse):
				return true
	return false
