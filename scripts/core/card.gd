extends Node2D

const SHADOW_TABLE_CLIP_SHADER_PATH = "res://shaders/shadow_table_clip.gdshader"
const SHADOW_CLIP_MAX_POINTS = 16
const TABLE_ITEM_CAPABILITIES_SCRIPT = preload("res://scripts/core/table_item_capabilities.gd")

# For testing -----------------------------------------------------------------
var paperA = preload("res://assets/testing/Paper A.png")
var paperB = preload("res://assets/testing/Paper B.png")
var paperC = preload("res://assets/testing/Paper C.png")

@export_category("References")
@export var paperType := Sprite2D
# End -------------------------------------------------------------------------

# Get hands for their positions
@export var leftHand : Node2D
@export var rightHand : Node2D

# Perspective scaling based on the tables 45-degree view
@export_category("Table Perspective")
@export var perspective_far_point: Vector2 = Vector2(157.0, -32.0)  # Upper-left / furthest point on the table
@export var perspective_near_point: Vector2 = Vector2(1746.0, 543.0)  # Lower-right / closest point on the table
@export var perspective_min_scale: float = 0.5  # Minimum scale (furthest away)
@export var perspective_max_scale: float = 1.3  # Maximum scale (closest)

@export_category("Visuals")
@export var drag_hover_offset: Vector2 = Vector2(0.0, -30.0)
@export var drag_hover_speed: float = 30.0
@export var hand_drop_screen_margin: float = 0.0
@export var in_hand_z_index: int = 101
@export var shadow_offset: Vector2 = Vector2(0.0, 40.0)
@export var shadow_fade_speed: float = 30.0
@export var shadow_max_alpha: float = 0.28
@export var snap_animation_duration: float = 0.1

@export_category("Physics")
@export var physics_profile: CardPhysicsProfile = preload("res://assets/data/cards/card_physics_default.tres")
@export var capabilities_profile: Resource = preload("res://assets/data/cards/table_item_capabilities_default.tres")
@export var bounce_objects: bool = true

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
var dragVelocity: Vector2 = Vector2.ZERO
var tableSlideVelocity: Vector2 = Vector2.ZERO
var releasedDragThisFrame: bool = false
var outOfBoundsDropActive: bool = false
var outOfBoundsDropTarget: Vector2 = Vector2.ZERO
var outOfBoundsDropVelocity: Vector2 = Vector2.ZERO
var originalScale: Vector2 = Vector2.ONE
var defaultZIndex: int = 0

enum floating {overTable, overLeftHand, overRightHand, overNothing}
var cardFloating : floating = floating.overTable
enum states {onTable, inLeftHand, inRightHand}
var cardStates : states = states.onTable

@onready var shadowSprite: Sprite2D = $Shadow

func _ready() -> void:
	if physics_profile == null:
		physics_profile = CardPhysicsProfile.new()
	if capabilities_profile == null:
		capabilities_profile = TABLE_ITEM_CAPABILITIES_SCRIPT.new()

	# For testing -------------------------------------------------------------
	if _uses_paper_test_random_texture():
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
	defaultZIndex = z_index
	originalScale = scale
	previousPosition = global_position

	if leftHand == null or rightHand == null:
		push_error("Card.gd: leftHand/rightHand is not assigned in the Inspector.")
		leftHandPosition = global_position
		rightHandPosition = global_position
		return

	_update_hand_positions()
	_setup_shadow_clip_material()
	_sync_shadow_texture()
	update_perspective_scale()
	update_drag_presentation(1.0)
	call_deferred("_deferred_refresh_table_clip")

func _update_hand_positions() -> void:
	if leftHand != null and is_instance_valid(leftHand):
		leftHandPosition = leftHand.global_position

	if rightHand != null and is_instance_valid(rightHand):
		rightHandPosition = rightHand.global_position

# Updates the card's scale based on its position in the isometric perspective
func update_perspective_scale() -> void:
	if cardStates == states.inLeftHand or cardStates == states.inRightHand:
		scale = originalScale
		return

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
	var blend = min(1.0, drag_hover_speed * delta)
	var target_card_offset = drag_hover_offset if dragging else Vector2.ZERO
	var can_show_drop_marker = (dragging or outOfBoundsDropActive) and hasTableDropTarget
	var target_shadow_alpha = (shadow_max_alpha * _shadow_alpha_scale()) if can_show_drop_marker else 0.0
	var target_shadow_position = Vector2.ZERO

	if can_show_drop_marker:
		var drop_local = to_local(tableDropPosition)
		# Keep shadow horizontally aligned with the card while still using table depth for Y.
		target_shadow_position = Vector2(paperType.position.x + shadow_offset.x, drop_local.y + (shadow_offset.y * _shadow_depth_scale()))

	paperType.position = paperType.position.lerp(target_card_offset, blend)
	if can_show_drop_marker:
		shadowSprite.position = target_shadow_position
	else:
		shadowSprite.position = shadowSprite.position.lerp(target_shadow_position, blend)
	shadowSprite.modulate.a = lerp(shadowSprite.modulate.a, target_shadow_alpha, min(1.0, shadow_fade_speed * delta))
	shadowSprite.visible = shadowSprite.modulate.a > 0.01

func update_table_drop_target() -> void:
	if !dragging:
		return

	var projected_position = _project_point_to_table(global_position)
	tableDropPosition = projected_position
	hasTableDropTarget = true

func _project_point_to_table(world_point: Vector2) -> Vector2:
	var projection_result = _project_point_to_table_with_collision(world_point)
	return projection_result["position"]

func _project_point_to_table_with_collision(world_point: Vector2) -> Dictionary:
	var result := {
		"position": world_point,
		"did_collide": false,
		"collision_normal": Vector2.ZERO
	}

	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1

	var hits = get_world_2d().direct_space_state.intersect_point(query, 1)
	if hits.size() > 0:
		return result

	if lastTableArea == null:
		return result

	var table_polygon = _get_table_polygon_world(lastTableArea)
	if table_polygon.size() < 3:
		return result

	if Geometry2D.is_point_in_polygon(world_point, table_polygon):
		return result

	var closest_point = table_polygon[0]
	var min_distance_sq = INF
	var closest_segment_a = table_polygon[0]
	var closest_segment_b = table_polygon[1]

	for i in range(table_polygon.size()):
		var a = table_polygon[i]
		var b = table_polygon[(i + 1) % table_polygon.size()]
		var segment_closest = Geometry2D.get_closest_point_to_segment(world_point, a, b)
		var distance_sq = world_point.distance_squared_to(segment_closest)
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_point = segment_closest
			closest_segment_a = a
			closest_segment_b = b

	var polygon_center := Vector2.ZERO
	for polygon_point in table_polygon:
		polygon_center += polygon_point
	polygon_center /= float(table_polygon.size())

	var edge_direction = closest_segment_b - closest_segment_a
	var collision_normal = Vector2.ZERO
	if edge_direction.length_squared() > 0.0:
		var candidate_normal_a = Vector2(-edge_direction.y, edge_direction.x).normalized()
		var candidate_normal_b = -candidate_normal_a
		var to_center = polygon_center - closest_point
		collision_normal = candidate_normal_a if candidate_normal_a.dot(to_center) >= candidate_normal_b.dot(to_center) else candidate_normal_b
	elif polygon_center != closest_point:
		collision_normal = (polygon_center - closest_point).normalized()

	result["position"] = closest_point
	result["did_collide"] = true
	result["collision_normal"] = collision_normal
	return result

func _get_table_polygon_world(table_area: Area2D) -> PackedVector2Array:
	for child in table_area.get_children():
		if child is CollisionPolygon2D:
			var polygon_node := child as CollisionPolygon2D
			var world_polygon := PackedVector2Array()
			for local_point in polygon_node.polygon:
				world_polygon.append(polygon_node.to_global(local_point))
			return world_polygon

	return PackedVector2Array()

func _closest_point_on_table_boundary(world_point: Vector2) -> Vector2:
	if lastTableArea == null:
		return world_point

	var table_polygon = _get_table_polygon_world(lastTableArea)
	if table_polygon.size() < 2:
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

func _aligned_drop_target_on_table(world_point: Vector2) -> Vector2:
	if lastTableArea == null:
		return world_point

	var table_polygon = _get_table_polygon_world(lastTableArea)
	if table_polygon.size() < 2:
		return world_point

	var intersections: Array[float] = []
	var x = world_point.x

	for i in range(table_polygon.size()):
		var a = table_polygon[i]
		var b = table_polygon[(i + 1) % table_polygon.size()]

		if is_equal_approx(a.x, b.x):
			if is_equal_approx(a.x, x):
				intersections.append(a.y)
				intersections.append(b.y)
			continue

		var min_x = minf(a.x, b.x)
		var max_x = maxf(a.x, b.x)
		if x < min_x or x > max_x:
			continue

		var t = (x - a.x) / (b.x - a.x)
		if t >= 0.0 and t <= 1.0:
			intersections.append(lerp(a.y, b.y, t))

	if intersections.size() == 0:
		return _closest_point_on_table_boundary(world_point)

	var best_y = intersections[0]
	var best_delta = absf(best_y - world_point.y)
	for y in intersections:
		var delta = absf(y - world_point.y)
		if delta < best_delta:
			best_delta = delta
			best_y = y

	return Vector2(x, best_y)

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

func follow_in_hand_target(target_position: Vector2) -> void:
	global_position = target_position
	z_index = _clamped_in_hand_z_index()

func _clamped_in_hand_z_index() -> int:
	return clampi(in_hand_z_index, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)

func _is_world_position_on_screen(world_position: Vector2, margin: float = 0.0) -> bool:
	var viewport_rect = get_viewport_rect().grow(margin)
	var screen_position = get_viewport().get_canvas_transform() * world_position
	return viewport_rect.has_point(screen_position)

func _is_hand_anchor_active(hand_anchor: Node2D, hand_position: Vector2) -> bool:
	if hand_anchor == null or !is_instance_valid(hand_anchor):
		return false

	if !hand_anchor.is_visible_in_tree():
		return false

	return _is_world_position_on_screen(hand_position, hand_drop_screen_margin)

func _force_drop_from_hand() -> void:
	if thisCardInRightHand:
		CardHandler.release_hand(CardHandler.HAND_RIGHT)
		thisCardInRightHand = false

	if thisCardInLeftHand:
		CardHandler.release_hand(CardHandler.HAND_LEFT)
		thisCardInLeftHand = false

	cardStates = states.onTable
	tableSlideVelocity = Vector2.ZERO
	tableDropPosition = _aligned_drop_target_on_table(global_position)
	hasTableDropTarget = true

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
	releasedDragThisFrame = false
	var previous_card_position = global_position
	mouseDifference = mousePosition - get_global_mouse_position()
	_update_hand_positions()
	drag_handler()

	if delta > 0.0:
		dragVelocity = (global_position - previous_card_position) / delta

	if releasedDragThisFrame:
		_start_table_slide_from_release()

	update_table_drop_target()
	_apply_out_of_bounds_drop(delta)
	_apply_table_slide(delta)
	hand_handler()
	placement_handler()
	update_perspective_scale()
	update_drag_presentation(delta)
	mousePosition = get_global_mouse_position()

func _process(_delta: float) -> void:
	if dragging:
		return

	if placementTween != null and placementTween.is_valid():
		return

	if cardStates == states.inRightHand and thisCardInRightHand:
		_update_hand_positions()
		global_position = rightHandPosition
	elif cardStates == states.inLeftHand and thisCardInLeftHand:
		_update_hand_positions()
		global_position = leftHandPosition

func _slide_stop_speed() -> float:
	# Higher friction raises the speed threshold where slide is considered settled.
	return lerp(6.0, 260.0, _get_friction())

func _slide_friction_force() -> float:
	# 0.0 = slippery table, 1.0 = near immediate stop.
	return lerp(300.0, 18000.0, _get_friction())

func _release_speed_boost() -> float:
	# Higher bounce keeps a bit more release momentum.
	return clamp(0.3 + _get_bounce(), 0.6, 1.4)

func _return_pull_strength() -> float:
	# Air-return pull is independent from table friction.
	return 3000.0

func _return_drag_strength() -> float:
	# Air-return drag baseline is independent from table friction.
	return 3.5

func _return_settle_radius() -> float:
	return 14.0

func _air_stop_speed() -> float:
	return 30.0

func _hide_drop_shadow() -> void:
	# Let update_drag_presentation fade the shadow out smoothly instead of hiding instantly.
	if shadowSprite.modulate.a > 0.01:
		shadowSprite.visible = true

func _air_drag_factor() -> float:
	# Quadratic drag approximation: acceleration is proportional to v^2 and inverse to BC * mass.
	var bc = max(0.02, _get_ballistic_coefficient())
	var mass = max(0.1, _get_weight())
	return _return_drag_strength() / (bc * mass * 1800.0)

func _max_return_speed() -> float:
	var base_speed = 700.0 + (_return_pull_strength() * 0.15)
	var bc_scale = clamp(sqrt(max(0.02, _get_ballistic_coefficient())) * 2.0, 0.45, 2.5)
	return clamp(base_speed * bc_scale, 250.0, 3200.0)

func _landing_slide_transfer() -> float:
	# Converts return impact into table slide momentum.
	return clamp(0.4 + (_get_bounce() * 0.4), 0.4, 1.0)

func _uses_paper_test_random_texture() -> bool:
	if capabilities_profile == null:
		return false
	return capabilities_profile.use_paper_test_random_texture

func _can_drag_item() -> bool:
	if capabilities_profile == null:
		return true
	return capabilities_profile.can_drag

func _can_be_placed_in_hands() -> bool:
	if capabilities_profile == null:
		return true
	return capabilities_profile.can_be_placed_in_hands

func _can_slide_on_table() -> bool:
	if capabilities_profile == null:
		return true
	return capabilities_profile.can_slide_on_table

func _can_bounce_objects() -> bool:
	if capabilities_profile == null:
		return true
	return capabilities_profile.can_bounce_objects

func _can_receive_object_bounce() -> bool:
	if capabilities_profile == null:
		return true
	return capabilities_profile.can_receive_object_bounce

func _shadow_alpha_scale() -> float:
	if capabilities_profile == null:
		return 1.0
	return capabilities_profile.shadow_alpha_scale

func _shadow_depth_scale() -> float:
	if capabilities_profile == null:
		return 1.0
	return capabilities_profile.shadow_depth_scale

func _get_friction() -> float:
	if physics_profile == null:
		return 0.5
	return physics_profile.friction

func _get_bounce() -> float:
	if physics_profile == null:
		return 0.7
	return physics_profile.bounce

func _get_weight() -> float:
	if physics_profile == null:
		return 1.0
	return physics_profile.weight

func _get_ballistic_coefficient() -> float:
	if physics_profile == null:
		return 0.75
	return physics_profile.ballistic_coefficient

# Moves the card to the position of the mouse and handles if the card is being dragged
func drag_handler():
	if !_can_drag_item():
		dragging = false
		return

	if dragging and mouseDifference != Vector2.ZERO:
		global_position -= mouseDifference
		_refresh_floating_state_from_overlaps()
	
	if isOver and Input.is_action_just_pressed("leftClick"):
		_stop_placement_tween()
		tableSlideVelocity = Vector2.ZERO
		outOfBoundsDropActive = false
		outOfBoundsDropVelocity = Vector2.ZERO
		dragging = true
		tableDropPosition = previousPosition
		hasTableDropTarget = true
		z_index = CardHandler.next_card_z_index()
		_refresh_floating_state_from_overlaps()
	elif dragging and Input.is_action_just_released("leftClick"):
		dragging = false
		releasedDragThisFrame = true
		_refresh_floating_state_from_overlaps()

func _start_table_slide_from_release() -> void:
	if !_can_slide_on_table():
		tableSlideVelocity = Vector2.ZERO
		return

	if cardFloating == floating.overNothing:
		_start_out_of_bounds_drop()
		return

	if cardFloating != floating.overTable:
		tableSlideVelocity = Vector2.ZERO
		return

	tableSlideVelocity = dragVelocity * _release_speed_boost()
	if tableSlideVelocity.length() < _slide_stop_speed():
		tableSlideVelocity = Vector2.ZERO
		return

	_stop_placement_tween()
	hasPlacementTarget = false

func _start_out_of_bounds_drop() -> void:
	tableSlideVelocity = Vector2.ZERO
	outOfBoundsDropTarget = _aligned_drop_target_on_table(global_position)

	if outOfBoundsDropTarget.is_equal_approx(global_position):
		outOfBoundsDropActive = false
		outOfBoundsDropVelocity = Vector2.ZERO
		return

	outOfBoundsDropActive = true
	outOfBoundsDropVelocity = dragVelocity
	tableDropPosition = outOfBoundsDropTarget
	hasTableDropTarget = true
	_stop_placement_tween()
	hasPlacementTarget = false

func _apply_out_of_bounds_drop(delta: float) -> void:
	if dragging or !outOfBoundsDropActive:
		return

	var closest_table_point = _aligned_drop_target_on_table(global_position)
	if !closest_table_point.is_equal_approx(global_position):
		outOfBoundsDropTarget = closest_table_point

	var to_target = outOfBoundsDropTarget - global_position
	var distance_to_target = to_target.length()

	if distance_to_target <= _return_settle_radius() and outOfBoundsDropVelocity.length() <= _air_stop_speed():
		_finish_out_of_bounds_drop()
		return

	var acceleration = Vector2.ZERO
	if distance_to_target > 0.0:
		acceleration += to_target.normalized() * _return_pull_strength()

	var speed = outOfBoundsDropVelocity.length()
	if speed > 0.0:
		var drag_direction = outOfBoundsDropVelocity / speed
		var drag_acceleration = _air_drag_factor() * speed * speed
		acceleration -= drag_direction * drag_acceleration

	outOfBoundsDropVelocity += acceleration * delta

	var max_speed = _max_return_speed()
	if outOfBoundsDropVelocity.length() > max_speed:
		outOfBoundsDropVelocity = outOfBoundsDropVelocity.normalized() * max_speed

	var next_position = global_position + (outOfBoundsDropVelocity * delta)
	var next_to_target = outOfBoundsDropTarget - next_position

	if to_target.dot(next_to_target) <= 0.0:
		_finish_out_of_bounds_drop()
		return

	global_position = next_position
	tableDropPosition = _project_point_to_table(global_position)
	hasTableDropTarget = true
	_refresh_floating_state_from_overlaps()

func _finish_out_of_bounds_drop() -> void:
	var landing_velocity = outOfBoundsDropVelocity
	outOfBoundsDropActive = false
	outOfBoundsDropVelocity = Vector2.ZERO
	global_position = outOfBoundsDropTarget
	tableDropPosition = outOfBoundsDropTarget
	hasTableDropTarget = true
	previousPosition = outOfBoundsDropTarget
	_hide_drop_shadow()
	if _can_slide_on_table():
		_set_slide_velocity(landing_velocity * _landing_slide_transfer())
	else:
		tableSlideVelocity = Vector2.ZERO
	_refresh_floating_state_from_overlaps()

func _apply_table_slide(delta: float) -> void:
	if !_can_slide_on_table():
		tableSlideVelocity = Vector2.ZERO
		return

	if dragging or outOfBoundsDropActive or tableSlideVelocity == Vector2.ZERO:
		return

	if cardStates != states.onTable and cardFloating != floating.overTable and cardFloating != floating.overNothing:
		tableSlideVelocity = Vector2.ZERO
		return

	var desired_position = global_position + (tableSlideVelocity * delta)
	var projected_result = _project_point_to_table_with_collision(desired_position)
	var projected_position: Vector2 = projected_result["position"]
	global_position = projected_position
	tableDropPosition = projected_position
	hasTableDropTarget = true
	_refresh_floating_state_from_overlaps()

	if projected_result["did_collide"]:
		_handle_table_slide_bounce(projected_result["collision_normal"])
		tableDropPosition = projected_position
		hasTableDropTarget = true
		previousPosition = projected_position
		return

	var speed = tableSlideVelocity.length()
	speed = max(0.0, speed - (_slide_friction_force() * delta))
	if speed <= _slide_stop_speed():
		tableSlideVelocity = Vector2.ZERO
		tableDropPosition = global_position
		hasTableDropTarget = true
	else:
		tableSlideVelocity = tableSlideVelocity.normalized() * speed

	previousPosition = global_position

func _handle_table_slide_bounce(collision_normal: Vector2) -> void:
	var bounce_amount = _get_bounce()
	if bounce_amount <= 0.0:
		tableSlideVelocity = Vector2.ZERO
		return

	if collision_normal == Vector2.ZERO:
		tableSlideVelocity = Vector2.ZERO
		return

	var bounced_velocity = tableSlideVelocity.bounce(collision_normal.normalized()) * bounce_amount
	if bounced_velocity.length() <= _slide_stop_speed():
		tableSlideVelocity = Vector2.ZERO
	else:
		tableSlideVelocity = bounced_velocity

func _get_mass() -> float:
	return max(0.1, _get_weight())

func _get_object_restitution() -> float:
	# Real-world coefficient of restitution is between 0 and 1.
	return clamp(_get_bounce(), 0.0, 1.0)

func _get_slide_velocity() -> Vector2:
	return tableSlideVelocity

func _set_slide_velocity(new_velocity: Vector2) -> void:
	if new_velocity.length() <= _slide_stop_speed():
		tableSlideVelocity = Vector2.ZERO
	else:
		tableSlideVelocity = new_velocity

	tableDropPosition = global_position
	hasTableDropTarget = true
	previousPosition = global_position

func _can_participate_in_object_bounce() -> bool:
	return bounce_objects and _can_bounce_objects() and _can_receive_object_bounce() and !dragging and !outOfBoundsDropActive and cardStates == states.onTable and _can_slide_on_table()

func _handle_object_slide_bounce(other_area: Area2D) -> void:
	var bounce_amount = _get_bounce()
	if !bounce_objects or !_can_bounce_objects() or bounce_amount <= 0.0:
		return

	if other_area == null:
		return

	var other_card = other_area.get_parent()
	if other_card == null or other_card == self:
		return

	if !other_card.has_method("_can_participate_in_object_bounce"):
		return

	var self_can_bounce = _can_participate_in_object_bounce()
	var other_can_bounce = bool(other_card.call("_can_participate_in_object_bounce"))
	if !self_can_bounce:
		return

	var other_node = other_card as Node2D
	if other_node == null:
		return

	var v1 = _get_slide_velocity()
	var v2: Vector2 = Vector2.ZERO
	if other_card.has_method("_get_slide_velocity"):
		v2 = other_card.call("_get_slide_velocity")

	if !other_can_bounce:
		if v1 == Vector2.ZERO:
			return

		var static_normal = global_position - other_node.global_position
		if static_normal.length_squared() <= 0.0:
			if v1.length_squared() <= 0.0:
				return
			static_normal = -v1.normalized()

		_set_slide_velocity(v1.bounce(static_normal.normalized()) * bounce_amount)
		return

	# Process each collision once so both cards don't apply the same impulse twice.
	if get_instance_id() > other_card.get_instance_id():
		return

	var normal = other_node.global_position - global_position
	if normal.length_squared() <= 0.0:
		var fallback_direction = v2 - v1
		if fallback_direction.length_squared() <= 0.0:
			return
		normal = fallback_direction.normalized()
	else:
		normal = normal.normalized()

	var relative_velocity = v2 - v1
	var velocity_along_normal = relative_velocity.dot(normal)
	if velocity_along_normal > 0.0:
		return

	var m1 = _get_mass()
	var m2 = float(other_card.call("_get_mass"))
	var restitution_a = _get_object_restitution()
	var restitution_b = float(other_card.call("_get_object_restitution"))
	var restitution = sqrt(max(0.0, restitution_a * restitution_b))

	var impulse = -(1.0 + restitution) * velocity_along_normal
	impulse /= (1.0 / m1) + (1.0 / m2)

	var new_v1 = v1 - (impulse / m1) * normal
	var new_v2 = v2 + (impulse / m2) * normal

	_set_slide_velocity(new_v1)
	other_card.call("_set_slide_velocity", new_v2)

# Handles what position the card is in before it is placed down by the player
func hand_handler():
	if dragging:
		return

	if !_can_be_placed_in_hands():
		cardStates = states.onTable
		return

	# State transitions are only evaluated on release frames so hands cannot auto-capture.
	if releasedDragThisFrame:
		if cardFloating == floating.overRightHand:
			cardStates = states.inRightHand
		elif cardFloating == floating.overLeftHand:
			cardStates = states.inLeftHand
		else:
			cardStates = states.onTable
		return

	# Between releases, preserve held state if already claimed.
	if cardStates == states.inRightHand and thisCardInRightHand:
		return
	if cardStates == states.inLeftHand and thisCardInLeftHand:
		return

	cardStates = states.onTable

# Handles where the card will be placed when let go of by the player
func placement_handler():
	if dragging:
		return

	if cardStates == states.inRightHand and !_is_hand_anchor_active(rightHand, rightHandPosition):
		_force_drop_from_hand()
	elif cardStates == states.inLeftHand and !_is_hand_anchor_active(leftHand, leftHandPosition):
		_force_drop_from_hand()

	if outOfBoundsDropActive:
		_stop_placement_tween()
		return

	if tableSlideVelocity != Vector2.ZERO and cardStates == states.onTable:
		_stop_placement_tween()
		return

	if cardStates == states.inRightHand:
		tableSlideVelocity = Vector2.ZERO
		z_index = _clamped_in_hand_z_index()
		if placementTween != null and placementTween.is_valid():
			if !hasPlacementTarget or !placementTargetPosition.is_equal_approx(rightHandPosition):
				animate_to_position(rightHandPosition)
		elif thisCardInRightHand:
			follow_in_hand_target(rightHandPosition)
		else:
			animate_to_position(rightHandPosition)
		CardHandler.claim_hand(CardHandler.HAND_RIGHT)
		thisCardInRightHand = true
	elif cardStates == states.inLeftHand:
		tableSlideVelocity = Vector2.ZERO
		z_index = _clamped_in_hand_z_index()
		if placementTween != null and placementTween.is_valid():
			if !hasPlacementTarget or !placementTargetPosition.is_equal_approx(leftHandPosition):
				animate_to_position(leftHandPosition)
		elif thisCardInLeftHand:
			follow_in_hand_target(leftHandPosition)
		else:
			animate_to_position(leftHandPosition)
		CardHandler.claim_hand(CardHandler.HAND_LEFT)
		thisCardInLeftHand = true
	elif cardStates == states.onTable and hasTableDropTarget:
		animate_to_position(tableDropPosition)
		previousPosition = tableDropPosition
	elif cardFloating == floating.overTable:
		_stop_placement_tween()
		previousPosition = global_position
	elif cardFloating == floating.overNothing:
		animate_to_position(previousPosition)
	
	if cardStates != states.inRightHand and thisCardInRightHand:
		CardHandler.release_hand(CardHandler.HAND_RIGHT)
		thisCardInRightHand = false
		z_index = defaultZIndex
	
	if cardStates != states.inLeftHand and thisCardInLeftHand:
		CardHandler.release_hand(CardHandler.HAND_LEFT)
		thisCardInLeftHand = false
		z_index = defaultZIndex

# Checks what layer the card has collided with and changes the state to the appropriate position
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(1):
		lastTableArea = area
		_update_shadow_clip_polygon()

	# Changes the z_index of the most recently set card to the top if it collides with another card
	if area.get_collision_layer_value(4):
		cardsTouching += 1
		if dragging and !isColliding:
			z_index = CardHandler.next_card_z_index()

		if !dragging and !outOfBoundsDropActive:
			_handle_object_slide_bounce(area)
		
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
	var can_place_in_hands = _can_be_placed_in_hands()

	# Priority is explicit so overlap ordering cannot cause random outcomes.
	if can_place_in_hands:
		for area in overlapping_areas:
			if area.get_collision_layer_value(3) and CardHandler.is_hand_available(CardHandler.HAND_RIGHT, thisCardInRightHand):
				cardFloating = floating.overRightHand
				return

	if can_place_in_hands:
		for area in overlapping_areas:
			if area.get_collision_layer_value(2) and CardHandler.is_hand_available(CardHandler.HAND_LEFT, thisCardInLeftHand):
				cardFloating = floating.overLeftHand
				return

	for area in overlapping_areas:
		if area.get_collision_layer_value(1):
			cardFloating = floating.overTable
			return
