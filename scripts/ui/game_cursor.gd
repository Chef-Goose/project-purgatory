extends CanvasLayer

enum CursorState {
	POINTER,
	HOVER,
	GRABBING,
	CLICK
}

@export var click_action: StringName = &"leftClick"
@export var hotspot_offset: Vector2 = Vector2.ZERO
@export var use_ui_hover: bool = false
@export var use_physics_hover: bool = true
@export var hover_collision_layers: PackedInt32Array = PackedInt32Array([4])
@export var pointer_texture: Texture2D = preload("res://assets/art/cursor/cursorplaceholderpointer.png")
@export var hover_texture: Texture2D = preload("res://assets/art/cursor/cursorplaceholderhover.png")
@export var grabbing_texture: Texture2D = preload("res://assets/art/cursor/cursorplaceholdergrab.png")
@export var click_texture: Texture2D = preload("res://assets/art/cursor/cursorplaceholderclick.png")

@onready var cursor_sprite: Sprite2D = $CursorSprite

var _current_state: CursorState = CursorState.POINTER
var _grab_sources: Dictionary = {}
var _hover_sources: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_update_cursor_visual(CursorState.POINTER)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta: float) -> void:
	_update_cursor_position()
	_update_cursor_state()


func set_grabbing(is_grabbing: bool, source: Node = null) -> void:
	var source_id: int = source.get_instance_id() if source != null else -1

	if is_grabbing:
		_grab_sources[source_id] = true
	else:
		_grab_sources.erase(source_id)


func begin_grab(source: Node = null) -> void:
	set_grabbing(true, source)


func end_grab(source: Node = null) -> void:
	set_grabbing(false, source)


func set_hovering(is_hovering: bool, source: Node = null) -> void:
	var source_id: int = source.get_instance_id() if source != null else -1

	if is_hovering:
		_hover_sources[source_id] = true
	else:
		_hover_sources.erase(source_id)


func begin_hover(source: Node = null) -> void:
	set_hovering(true, source)


func end_hover(source: Node = null) -> void:
	set_hovering(false, source)


func _update_cursor_position() -> void:
	if cursor_sprite == null:
		return

	cursor_sprite.global_position = get_viewport().get_mouse_position() + hotspot_offset


func _update_cursor_state() -> void:
	var next_state := _resolve_cursor_state()
	if next_state == _current_state:
		return

	_current_state = next_state
	_update_cursor_visual(_current_state)


func _resolve_cursor_state() -> CursorState:
	if _is_grabbing_active():
		return CursorState.GRABBING

	if _is_hovering_interactable():
		return CursorState.HOVER

	if Input.is_action_pressed(click_action):
		return CursorState.CLICK

	return CursorState.POINTER


func _is_grabbing_active() -> bool:
	if _grab_sources.is_empty():
		return false

	for source_id in _grab_sources.keys():
		if source_id == -1:
			return true

		var instance := instance_from_id(int(source_id))
		if instance != null:
			return true

	return false


func _is_hovering_interactable() -> bool:
	if _is_hover_source_active():
		return true

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false

	if use_ui_hover:
		var hovered_control: Control = viewport.gui_get_hovered_control()
		if hovered_control != null and hovered_control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true

	if !use_physics_hover:
		return false

	var world_2d: World2D = viewport.world_2d
	if world_2d == null:
		return false

	var world_mouse_position: Vector2 = _get_world_mouse_position()
	if _has_hoverable_hit_at(world_2d, world_mouse_position):
		return true

	# Fallback for projects with unusual canvas transforms.
	var viewport_mouse_position: Vector2 = viewport.get_mouse_position()
	if world_mouse_position.is_equal_approx(viewport_mouse_position):
		return false

	return _has_hoverable_hit_at(world_2d, viewport_mouse_position)


func _is_hover_source_active() -> bool:
	if _hover_sources.is_empty():
		return false

	for source_id in _hover_sources.keys():
		if source_id == -1:
			return true

		var instance := instance_from_id(int(source_id))
		if instance != null:
			return true

	return false


func _has_hoverable_hit_at(world_2d: World2D, point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hits: Array[Dictionary] = world_2d.direct_space_state.intersect_point(query, 16)
	for hit: Dictionary in hits:
		var collider_object: Object = hit.get("collider") as Object
		if collider_object == null:
			continue

		if collider_object is Node and (collider_object as Node).is_in_group("cursor_hoverable"):
			return true

		if collider_object is CollisionObject2D and _is_hover_collision_layer(collider_object as CollisionObject2D):
			return true

		if not (collider_object is Node):
			continue

		var parent_node: Node = (collider_object as Node).get_parent()
		if parent_node != null and parent_node.is_in_group("cursor_hoverable"):
			return true

	return false


func _is_hover_collision_layer(collider: CollisionObject2D) -> bool:
	for collision_layer in hover_collision_layers:
		if collision_layer < 1 or collision_layer > 32:
			continue

		if collider.get_collision_layer_value(collision_layer):
			return true

	return false


func _get_world_mouse_position() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO

	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()


func _update_cursor_visual(state: CursorState) -> void:
	if cursor_sprite == null:
		return

	match state:
		CursorState.POINTER:
			cursor_sprite.texture = pointer_texture
		CursorState.HOVER:
			cursor_sprite.texture = hover_texture
		CursorState.GRABBING:
			cursor_sprite.texture = grabbing_texture
		CursorState.CLICK:
			cursor_sprite.texture = click_texture
