extends Camera2D

class_name TableCameraController

@export_group("Base")
@export var base_follow_speed: float = 6.0
@export var base_zoom: Vector2 = Vector2.ONE

@export_group("Snap")
@export var snap_default_speed: float = 22.0

var _base_position: Vector2
var _hover_entries: Dictionary = {}
var _active_hover_target: Vector2 = Vector2.ZERO
var _active_hover_speed: float = 10.0

var _snap_active: bool = false
var _snap_target: Vector2 = Vector2.ZERO
var _snap_zoom: Vector2 = Vector2(0.8, 0.8)
var _snap_speed: float = 22.0


func _ready() -> void:
	_base_position = global_position

	zoom = base_zoom


func _process(delta: float) -> void:
	var base_target_position := _base_position

	if _snap_active:
		global_position = global_position.lerp(_snap_target, _smoothing_weight(_snap_speed, delta))
		zoom = zoom.lerp(_snap_zoom, _smoothing_weight(_snap_speed, delta))
		return

	if not _hover_entries.is_empty():
		global_position = global_position.lerp(_active_hover_target, _smoothing_weight(_active_hover_speed, delta))
		zoom = zoom.lerp(base_zoom, _smoothing_weight(base_follow_speed, delta))
		return

	global_position = global_position.lerp(base_target_position, _smoothing_weight(base_follow_speed, delta))
	zoom = zoom.lerp(base_zoom, _smoothing_weight(base_follow_speed, delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clear_snap()


func enter_hover_zone(zone: Node2D, target_position: Vector2, speed: float = 10.0, priority: int = 0) -> void:
	if zone == null:
		return

	_hover_entries[zone.get_instance_id()] = {
		"zone": zone,
		"target": target_position,
		"speed": maxf(speed, 0.1),
		"priority": priority,
	}
	_refresh_active_hover_zone()


func exit_hover_zone(zone: Node2D) -> void:
	if zone == null:
		return

	_hover_entries.erase(zone.get_instance_id())
	_refresh_active_hover_zone()


func snap_to_zone(target_position: Vector2, snap_zoom_level: Vector2, speed: float = -1.0) -> void:
	_snap_target = target_position
	_snap_zoom = snap_zoom_level
	_snap_speed = snap_default_speed if speed <= 0.0 else speed
	_snap_active = true


func clear_snap() -> void:
	_snap_active = false


func is_snap_active() -> bool:
	return _snap_active


func clear_hover_zones() -> void:
	_hover_entries.clear()
	_active_hover_target = _base_position
	_active_hover_speed = base_follow_speed


func _refresh_active_hover_zone() -> void:
	var top_entry: Dictionary = {}
	var has_top := false

	for key in _hover_entries.keys():
		var entry: Dictionary = _hover_entries[key]
		var zone: Node2D = entry.get("zone") as Node2D
		if zone == null or not is_instance_valid(zone):
			_hover_entries.erase(key)
			continue

		if not has_top or int(entry.get("priority", 0)) >= int(top_entry.get("priority", -2147483648)):
			top_entry = entry
			has_top = true

	if has_top:
		_active_hover_target = top_entry.get("target", _base_position)
		_active_hover_speed = float(top_entry.get("speed", 10.0))


func _smoothing_weight(speed: float, delta: float) -> float:
	return clampf(1.0 - exp(-speed * delta), 0.0, 1.0)
