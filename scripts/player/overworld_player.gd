extends CharacterBody2D
class_name OverworldPlayer

signal interaction_target_changed(target: OverworldInteractable)
signal interaction_requested(target: OverworldInteractable)

@export_range(50.0, 600.0, 1.0) var move_speed: float = 220.0
@export var world_bounds: Rect2 = Rect2(-900, -500, 1800, 1000)
@export var forward_texture: Texture2D
@export var backward_texture: Texture2D
@export var side_texture: Texture2D

@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var interaction_area: Area2D = $InteractionArea

var _nearby_interactables: Array[OverworldInteractable] = []
var _current_target: OverworldInteractable
var _movement_locked: bool = false

enum FacingDirection {
	FORWARD,
	BACKWARD,
	SIDE,
}

var _current_facing: FacingDirection = FacingDirection.FORWARD


func _ready() -> void:
	add_to_group("overworld_player")
	if interaction_area != null:
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
	_update_sprite(Vector2.DOWN)


func _physics_process(_delta: float) -> void:
	if _movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector: Vector2 = _get_movement_input()
	velocity = input_vector * move_speed
	move_and_slide()
	position = position.clamp(world_bounds.position, world_bounds.position + world_bounds.size)
	global_position = global_position.round()

	if input_vector != Vector2.ZERO:
		_update_sprite(input_vector)


func _unhandled_input(event: InputEvent) -> void:
	if _movement_locked:
		return

	if _is_interact_input(event):
		_attempt_interaction()


func get_current_interactable() -> OverworldInteractable:
	return _current_target


func set_movement_locked(is_locked: bool) -> void:
	_movement_locked = is_locked
	if _movement_locked:
		velocity = Vector2.ZERO


func _get_movement_input() -> Vector2:
	var mapped_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if mapped_input != Vector2.ZERO:
		return mapped_input

	var x_input := int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
	var y_input := int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
	var raw_input := Vector2(float(x_input), float(y_input))
	if raw_input == Vector2.ZERO:
		return Vector2.ZERO

	return raw_input.normalized()


func _on_interaction_area_entered(area: Area2D) -> void:
	var interactable := _resolve_interactable(area)
	if interactable == null:
		return

	if _nearby_interactables.has(interactable):
		return

	_nearby_interactables.append(interactable)
	_update_current_target()


func _on_interaction_area_exited(area: Area2D) -> void:
	var interactable := _resolve_interactable(area)
	if interactable == null:
		return

	_nearby_interactables.erase(interactable)
	_update_current_target()


func _update_current_target() -> void:
	var best_target: OverworldInteractable = null
	var best_distance: float = INF

	for interactable: OverworldInteractable in _nearby_interactables:
		if interactable == null or not is_instance_valid(interactable):
			continue
		if not interactable.can_interact():
			continue

		var candidate_distance := global_position.distance_squared_to(interactable.global_position)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_target = interactable

	if best_target == _current_target:
		return

	_current_target = best_target
	interaction_target_changed.emit(_current_target)


func _attempt_interaction() -> void:
	if _current_target == null:
		return

	if not is_instance_valid(_current_target) or not _current_target.can_interact():
		_update_current_target()
		return

	interaction_requested.emit(_current_target)


func _is_interact_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			return true

	return false


func _resolve_interactable(area: Area2D) -> OverworldInteractable:
	var parent := area.get_parent()
	if parent is OverworldInteractable:
		return parent as OverworldInteractable

	return null


func _update_sprite(direction: Vector2) -> void:
	if player_sprite == null:
		return

	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	var dominant_margin := 0.08

	if abs_x > abs_y + dominant_margin:
		_current_facing = FacingDirection.SIDE
	elif abs_y > abs_x + dominant_margin:
		_current_facing = FacingDirection.BACKWARD if direction.y < 0.0 else FacingDirection.FORWARD
	elif _current_facing == FacingDirection.BACKWARD or _current_facing == FacingDirection.FORWARD:
		_current_facing = FacingDirection.BACKWARD if direction.y < 0.0 else FacingDirection.FORWARD

	match _current_facing:
		FacingDirection.SIDE:
			if side_texture != null:
				player_sprite.texture = side_texture
			player_sprite.flip_h = direction.x < 0.0
		FacingDirection.BACKWARD:
			player_sprite.flip_h = false
			if backward_texture != null:
				player_sprite.texture = backward_texture
		FacingDirection.FORWARD:
			player_sprite.flip_h = false
			if forward_texture != null:
				player_sprite.texture = forward_texture
