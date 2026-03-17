extends Node2D

const SHADOW_TABLE_CLIP_SHADER_PATH = "res://shaders/shadow_table_clip.gdshader"
const SHADOW_CLIP_MAX_POINTS = 16

# For testing -----------------------------------------------------------------
var paperA = preload("res://assets/testing/Paper A.png")
var paperB = preload("res://assets/testing/Paper B.png")
var paperC = preload("res://assets/testing/Paper C.png")
@export var paperType := Sprite2D
# End -------------------------------------------------------------------------

# Get hands for their positions
@export var leftHand : Node2D
@export var rightHand : Node2D

# Perspective scaling based on the tables 45-degree view
@export var perspective_far_point: Vector2 = Vector2(157.0, -32.0)  # Upper-left / furthest point on the table
@export var perspective_near_point: Vector2 = Vector2(1746.0, 543.0)  # Lower-right / closest point on the table
@export var perspective_min_scale: float = 0.5  # Minimum scale (furthest away)
@export var perspective_max_scale: float = 1.3  # Maximum scale (closest)
@export var drag_hover_offset: Vector2 = Vector2(0.0, -30.0)
@export var drag_hover_speed: float = 30.0
@export var shadow_offset: Vector2 = Vector2(0.0, 40.0)
@export var shadow_fade_speed: float = 30.0
@export var shadow_max_alpha: float = 0.28
@export var snap_animation_duration: float = 0.1

var mousePosition : Vector2 = Vector2.ZERO
var leftHandPosition: Vector2 = Vector2.ZERO
var rightHandPosition: Vector2 = Vector2.ZERO
var previousPosition : Vector2
var mouseDifference : Vector2
var placementTargetPosition: Vector2 = Vector2.ZERO
var tableDropPosition: Vector2 = Vector2.ZERO
var lastTableArea: Area2D

var isOver : bool
var dragging : bool = false
var thisCardInLeftHand : bool = false
var thisCardInRightHand : bool = false
var isColliding: bool = false
var hasPlacementTarget: bool = false
var hasTableDropTarget: bool = false

var cardsTouching: int = 0
var placementTween: Tween
var shadowClipMaterial: ShaderMaterial
var shadowClipShader: Shader

enum floating {overTable, overLeftHand, overRightHand, overNothing}
var cardFloating : floating = floating.overTable
enum states {onTable, inLeftHand, inRightHand}
var cardStates : states = states.onTable

@onready var shadowSprite: Sprite2D = $Shadow

func _ready() -> void:
	# For testing -------------------------------------------------------------
	var rand = randi_range(1,3)
	if rand == 1:
		paperType.texture = paperA
	elif rand == 2:
		paperType.texture = paperB
	else:
		paperType.texture = paperC
	# End ---------------------------------------------------------------------
		
	# Enables a setting that forces the only the top card to be selected when cards are overlaping
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	previousPosition = global_position

	if leftHand == null or rightHand == null:
		push_error("Card.gd: leftHand/rightHand is not assigned in the Inspector.")
		leftHandPosition = global_position
		rightHandPosition = global_position
		return

	# Snapshot hand positions once at startup.
	leftHandPosition = leftHand.global_position
	rightHandPosition = rightHand.global_position
	_setup_shadow_clip_material()
	_sync_shadow_texture()
	update_perspective_scale()
	update_drag_presentation(1.0)
	call_deferred("_deferred_refresh_table_clip")

# Updates the card's scale based on its position in the isometric perspective
func update_perspective_scale() -> void:
	# Project the card onto the table's far-to-near diagonal so both X and Y affect scale.
	var depth_vector = perspective_near_point - perspective_far_point
	var depth_length_squared = depth_vector.length_squared()
	var normalized_position = 0.5

	if depth_length_squared > 0.0:
		var offset_from_far = global_position - perspective_far_point
		normalized_position = clamp(offset_from_far.dot(depth_vector) / depth_length_squared, 0.0, 1.0)
	
	# Interpolate between min and max scale
	var target_scale = lerp(perspective_min_scale, perspective_max_scale, normalized_position)
	scale = Vector2.ONE * target_scale

func update_drag_presentation(delta: float) -> void:
	var weight = min(1.0, drag_hover_speed * delta)
	var target_card_offset = drag_hover_offset if dragging else Vector2.ZERO
	var can_show_drop_marker = dragging and hasTableDropTarget
	var target_shadow_alpha = shadow_max_alpha if can_show_drop_marker else 0.0
	var target_shadow_position = Vector2.ZERO

	if can_show_drop_marker:
		target_shadow_position = to_local(tableDropPosition) + shadow_offset

	paperType.position = paperType.position.lerp(target_card_offset, weight)
	shadowSprite.position = shadowSprite.position.lerp(target_shadow_position, weight)
	shadowSprite.modulate.a = lerp(shadowSprite.modulate.a, target_shadow_alpha, min(1.0, shadow_fade_speed * delta))
	shadowSprite.visible = shadowSprite.modulate.a > 0.01

func update_table_drop_target() -> void:
	if !dragging:
		return

	var projected_position = _project_point_to_table(global_position)
	tableDropPosition = projected_position
	hasTableDropTarget = true

func _project_point_to_table(world_point: Vector2) -> Vector2:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1

	var hits = get_world_2d().direct_space_state.intersect_point(query, 1)
	if hits.size() > 0:
		return world_point

	if lastTableArea == null:
		return world_point

	var table_polygon = _get_table_polygon_world(lastTableArea)
	if table_polygon.size() < 3:
		return world_point

	if Geometry2D.is_point_in_polygon(world_point, table_polygon):
		return world_point

	var closest_point = table_polygon[0]
	var min_distance_sq = INF

	for i in range(table_polygon.size()):
		var a = table_polygon[i]
		var b = table_polygon[(i + 1) % table_polygon.size()]
		var segment_closest = Geometry2D.get_closest_point_to_segment(world_point, a, b)
		var distance_sq = world_point.distance_squared_to(segment_closest)
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_point = segment_closest

	return closest_point

func _get_table_polygon_world(table_area: Area2D) -> PackedVector2Array:
	for child in table_area.get_children():
		if child is CollisionPolygon2D:
			var polygon_node := child as CollisionPolygon2D
			var world_polygon := PackedVector2Array()
			for local_point in polygon_node.polygon:
				world_polygon.append(polygon_node.to_global(local_point))
			return world_polygon

	return PackedVector2Array()

func _setup_shadow_clip_material() -> void:
	if shadowSprite == null:
		return

	if shadowClipShader == null:
		shadowClipShader = load(SHADOW_TABLE_CLIP_SHADER_PATH)
		if shadowClipShader == null:
			push_error("Card.gd: Failed to load shadow clip shader at %s" % SHADOW_TABLE_CLIP_SHADER_PATH)
			return

	if shadowSprite.material is ShaderMaterial and (shadowSprite.material as ShaderMaterial).shader == shadowClipShader:
		shadowClipMaterial = shadowSprite.material as ShaderMaterial
	else:
		shadowClipMaterial = ShaderMaterial.new()
		shadowClipMaterial.shader = shadowClipShader
		shadowSprite.material = shadowClipMaterial

	shadowClipMaterial.set_shader_parameter("table_point_count", 0)

func _deferred_refresh_table_clip() -> void:
	if lastTableArea == null:
		for area in $Area2D.get_overlapping_areas():
			if area.get_collision_layer_value(1):
				lastTableArea = area
				break

	_update_shadow_clip_polygon()

func _update_shadow_clip_polygon() -> void:
	if shadowClipMaterial == null:
		return

	var table_polygon = PackedVector2Array()
	if lastTableArea != null:
		table_polygon = _get_table_polygon_world(lastTableArea)

	var clipped_polygon := PackedVector2Array()
	var clipped_count = mini(table_polygon.size(), SHADOW_CLIP_MAX_POINTS)
	for i in range(clipped_count):
		clipped_polygon.append(table_polygon[i])

	shadowClipMaterial.set_shader_parameter("table_point_count", clipped_count)
	shadowClipMaterial.set_shader_parameter("table_points", clipped_polygon)

func animate_to_position(target_position: Vector2) -> void:
	if global_position.is_equal_approx(target_position):
		_stop_placement_tween()
		global_position = target_position
		return

	if placementTween != null and placementTween.is_valid() and hasPlacementTarget and placementTargetPosition.is_equal_approx(target_position):
		return

	_stop_placement_tween(false)
	hasPlacementTarget = true
	placementTargetPosition = target_position
	placementTween = create_tween()
	placementTween.set_trans(Tween.TRANS_CUBIC)
	placementTween.set_ease(Tween.EASE_OUT)
	placementTween.tween_property(self, "global_position", target_position, snap_animation_duration)
	placementTween.finished.connect(_on_placement_tween_finished)

func _stop_placement_tween(clear_target: bool = true) -> void:
	if placementTween != null and placementTween.is_valid():
		placementTween.kill()

	placementTween = null

	if clear_target:
		hasPlacementTarget = false

func _on_placement_tween_finished() -> void:
	placementTween = null
	hasPlacementTarget = false

func _sync_shadow_texture() -> void:
	shadowSprite.texture = paperType.texture

# Tracks if the mouse is over the card
func _on_area_2d_mouse_shape_entered(_shape_idx: int) -> void:
	isOver = true
func _on_area_2d_mouse_shape_exited(_shape_idx: int) -> void:
	isOver = false

func _physics_process(delta: float) -> void:
	mouseDifference = mousePosition - get_global_mouse_position()
	drag_handler()
	update_table_drop_target()
	hand_handler()
	placement_handler()
	update_perspective_scale()
	update_drag_presentation(delta)
	mousePosition = get_global_mouse_position()

# Moves the card to the position of the mouse and handles if the card is being dragged
func drag_handler():
	if dragging and mouseDifference != Vector2.ZERO:
		global_position -= mouseDifference
		_refresh_floating_state_from_overlaps()
	
	if isOver and Input.is_action_just_pressed("leftClick"):
		_stop_placement_tween()
		dragging = true
		tableDropPosition = previousPosition
		hasTableDropTarget = true
		CardHandler.masterZ_Index += 1
		z_index = CardHandler.masterZ_Index
		_refresh_floating_state_from_overlaps()
	elif dragging and Input.is_action_just_released("leftClick"):
		dragging = false
		_refresh_floating_state_from_overlaps()

# Handles what position the card is in before it is placed down by the player
func hand_handler():
	if !dragging and cardFloating == floating.overRightHand:
		cardStates = states.inRightHand
	elif !dragging and cardFloating == floating.overLeftHand:
		cardStates = states.inLeftHand
	elif !dragging and (cardFloating == floating.overTable or cardFloating == floating.overNothing):
		cardStates = states.onTable

# Handles where the card will be placed when let go of by the player
func placement_handler():
	if dragging:
		return

	if !dragging and cardStates == states.inRightHand:
		animate_to_position(rightHandPosition)
		CardHandler.rightHandEmpty = false
		thisCardInRightHand = true
	elif !dragging and cardStates == states.inLeftHand:
		animate_to_position(leftHandPosition)
		CardHandler.leftHandEmpty = false
		thisCardInLeftHand = true
	elif !dragging and cardStates == states.onTable and hasTableDropTarget:
		animate_to_position(tableDropPosition)
		previousPosition = tableDropPosition
	elif !dragging and cardFloating == floating.overTable:
		_stop_placement_tween()
		previousPosition = global_position
	elif !dragging and cardFloating == floating.overNothing:
		animate_to_position(previousPosition)
	
	if cardStates != states.inRightHand and !CardHandler.rightHandEmpty and thisCardInRightHand:
		CardHandler.rightHandEmpty = true
		thisCardInRightHand = false
	
	if cardStates != states.inLeftHand and !CardHandler.leftHandEmpty and thisCardInLeftHand:
		CardHandler.leftHandEmpty = true
		thisCardInLeftHand = false

# Checks what layer the card has collided with and changes the state to the appropriate position
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(1):
		lastTableArea = area
		_update_shadow_clip_polygon()

	# Changes the z_index of the most recently set card to the top if it collides with another card
	if area.get_collision_layer_value(4):
		cardsTouching += 1
		if dragging and !isColliding:
			CardHandler.masterZ_Index += 1
			z_index = CardHandler.masterZ_Index
		
		if !isColliding:
			isColliding = true

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.get_collision_layer_value(4):
		cardsTouching -= 1
		if cardsTouching == 0:
			isColliding = false


func _refresh_floating_state_from_overlaps() -> void:
	var overlapping_areas: Array[Area2D] = $Area2D.get_overlapping_areas()
	cardFloating = floating.overNothing

	# Priority is explicit so overlap ordering cannot cause random outcomes.
	for area in overlapping_areas:
		if area.get_collision_layer_value(3) and (CardHandler.rightHandEmpty or thisCardInRightHand):
			cardFloating = floating.overRightHand
			return

	for area in overlapping_areas:
		if area.get_collision_layer_value(2) and (CardHandler.leftHandEmpty or thisCardInLeftHand):
			cardFloating = floating.overLeftHand
			return

	for area in overlapping_areas:
		if area.get_collision_layer_value(1):
			cardFloating = floating.overTable
			return
