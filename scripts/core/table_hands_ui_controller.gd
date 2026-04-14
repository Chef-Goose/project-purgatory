extends Node2D

@export var toggle_action: StringName = &"toggle_hands_ui"
@export var start_visible: bool = true
@export var left_hand_area_path: NodePath = NodePath("leftHandArea")
@export var right_hand_area_path: NodePath = NodePath("rightHandArea")
@export var left_hand_back_sprite_path: NodePath = NodePath("leftHandArea/LeftHandBack")
@export var right_hand_back_sprite_path: NodePath = NodePath("rightHandArea/RightHandBack")
@export var left_hand_front_sprite_path: NodePath = NodePath("leftHandArea/LeftHandFront")
@export var right_hand_front_sprite_path: NodePath = NodePath("rightHandArea/RightHandFront")
@export var left_animation_player_path: NodePath = NodePath("LeftHandAnimationPlayer")
@export var right_animation_player_path: NodePath = NodePath("RightHandAnimationPlayer")
@export var left_enter_hold_animation: StringName = &"enter_hold"
@export var left_exit_hold_animation: StringName = &"exit_hold"
@export var right_enter_hold_animation: StringName = &"enter_hold"
@export var right_exit_hold_animation: StringName = &"exit_hold"
@export var left_idle_back_texture: Texture2D = preload("res://assets/art/hands/IdleLeftHand.png")
@export var left_holding_back_texture: Texture2D = preload("res://assets/art/hands/HoldingLeftHand.png")
@export var left_holding_front_texture: Texture2D
@export var right_idle_back_texture: Texture2D = preload("res://assets/art/hands/IdleRightHand.png")
@export var right_holding_back_texture: Texture2D = preload("res://assets/art/hands/HoldingRightHand.png")
@export var right_holding_front_texture: Texture2D

var _hands_visible: bool = true
var _left_hand_area: Area2D
var _right_hand_area: Area2D
var _left_hand_back_sprite: Sprite2D
var _right_hand_back_sprite: Sprite2D
var _left_hand_front_sprite: Sprite2D
var _right_hand_front_sprite: Sprite2D
var _left_animation_player: AnimationPlayer
var _right_animation_player: AnimationPlayer
var _left_hand_layer: int = 0
var _left_hand_mask: int = 0
var _right_hand_layer: int = 0
var _right_hand_mask: int = 0
var _left_holding_state: bool = false
var _right_holding_state: bool = false
@onready var _object_handler: Node = get_node_or_null("/root/ObjectHandler")


func _is_hand_available(slot: StringName) -> bool:
	if _object_handler != null and _object_handler.has_method("is_hand_available"):
		return _object_handler.is_hand_available(slot)
	return true


func _release_hand(slot: StringName) -> void:
	if _object_handler != null and _object_handler.has_method("release_hand"):
		_object_handler.release_hand(slot)


func _ready() -> void:
	_left_hand_area = get_node_or_null(left_hand_area_path) as Area2D
	_right_hand_area = get_node_or_null(right_hand_area_path) as Area2D
	_left_hand_back_sprite = get_node_or_null(left_hand_back_sprite_path) as Sprite2D
	_right_hand_back_sprite = get_node_or_null(right_hand_back_sprite_path) as Sprite2D
	_left_hand_front_sprite = get_node_or_null(left_hand_front_sprite_path) as Sprite2D
	_right_hand_front_sprite = get_node_or_null(right_hand_front_sprite_path) as Sprite2D
	_left_animation_player = get_node_or_null(left_animation_player_path) as AnimationPlayer
	_right_animation_player = get_node_or_null(right_animation_player_path) as AnimationPlayer

	if _left_hand_area == null or _right_hand_area == null:
		push_warning("TableHandsUiController: left/right hand area paths are not assigned.")
		return

	_left_hand_layer = _left_hand_area.collision_layer
	_left_hand_mask = _left_hand_area.collision_mask
	_right_hand_layer = _right_hand_area.collision_layer
	_right_hand_mask = _right_hand_area.collision_mask

	_set_hands_visible(start_visible)
	_update_hand_visual_state(false)


func _process(_delta: float) -> void:
	_update_hand_visual_state(true)


func _unhandled_input(event: InputEvent) -> void:
	if _is_toggle_event(event):
		_set_hands_visible(!_hands_visible)
		get_viewport().set_input_as_handled()


func _is_toggle_event(event: InputEvent) -> bool:
	if event is InputEventAction:
		var action_event := event as InputEventAction
		return action_event.action == toggle_action and action_event.pressed

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo or !key_event.pressed:
			return false
		return key_event.keycode == KEY_H

	return false


func _set_hands_visible(visible_state: bool) -> void:
	_hands_visible = visible_state
	_set_hand_area_enabled(_left_hand_area, visible_state, _left_hand_layer, _left_hand_mask)
	_set_hand_area_enabled(_right_hand_area, visible_state, _right_hand_layer, _right_hand_mask)

	if not visible_state:
		_release_hand(&"left")
		_release_hand(&"right")

	_update_hand_visual_state(false)


func _update_hand_visual_state(animate_transitions: bool) -> void:
	var left_is_holding = !_is_hand_available(&"left")
	var right_is_holding = !_is_hand_available(&"right")

	if left_is_holding != _left_holding_state:
		_transition_left_hand(left_is_holding, animate_transitions)
	elif not animate_transitions:
		_apply_left_hand_final_state(left_is_holding)

	if right_is_holding != _right_holding_state:
		_transition_right_hand(right_is_holding, animate_transitions)
	elif not animate_transitions:
		_apply_right_hand_final_state(right_is_holding)

	_left_holding_state = left_is_holding
	_right_holding_state = right_is_holding


func _transition_left_hand(is_holding: bool, animate_transition: bool) -> void:
	if _left_hand_back_sprite != null:
		_left_hand_back_sprite.texture = left_holding_back_texture if is_holding else left_idle_back_texture

	if _left_hand_front_sprite != null:
		if is_holding and left_holding_front_texture != null:
			_left_hand_front_sprite.texture = left_holding_front_texture
			_left_hand_front_sprite.visible = true
		else:
			_left_hand_front_sprite.texture = null

	if animate_transition and _left_animation_player != null:
		var animation_name = left_enter_hold_animation if is_holding else left_exit_hold_animation
		if _left_animation_player.has_animation(animation_name):
			_left_animation_player.play(animation_name)
			return

	_apply_left_hand_final_state(is_holding)


func _transition_right_hand(is_holding: bool, animate_transition: bool) -> void:
	if _right_hand_back_sprite != null:
		_right_hand_back_sprite.texture = right_holding_back_texture if is_holding else right_idle_back_texture

	if _right_hand_front_sprite != null:
		if is_holding and right_holding_front_texture != null:
			_right_hand_front_sprite.texture = right_holding_front_texture
			_right_hand_front_sprite.visible = true
		else:
			_right_hand_front_sprite.texture = null

	if animate_transition and _right_animation_player != null:
		var animation_name = right_enter_hold_animation if is_holding else right_exit_hold_animation
		if _right_animation_player.has_animation(animation_name):
			_right_animation_player.play(animation_name)
			return

	_apply_right_hand_final_state(is_holding)


func _apply_left_hand_final_state(is_holding: bool) -> void:
	if _left_hand_front_sprite == null:
		return

	var show_front = is_holding and left_holding_front_texture != null
	_left_hand_front_sprite.modulate.a = 1.0 if show_front else 0.0
	_left_hand_front_sprite.visible = show_front


func _apply_right_hand_final_state(is_holding: bool) -> void:
	if _right_hand_front_sprite == null:
		return

	var show_front = is_holding and right_holding_front_texture != null
	_right_hand_front_sprite.modulate.a = 1.0 if show_front else 0.0
	_right_hand_front_sprite.visible = show_front


func _set_hand_area_enabled(area: Area2D, enabled: bool, cached_layer: int, cached_mask: int) -> void:
	if area == null:
		return

	area.visible = enabled
	if enabled:
		area.collision_layer = cached_layer
		area.collision_mask = cached_mask
	else:
		area.collision_layer = 0
		area.collision_mask = 0
