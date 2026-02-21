extends Node2D

# For testing -----------------------------------------------------------------
var paperA = preload("uid://benr7m8oq8esp")
var paperB = preload("uid://dcxfip4xxbigs")
var paperC = preload("uid://dpoih4vfpeary")
@export var paperType := Sprite2D
# End -------------------------------------------------------------------------

var mousePosition : Vector2 = Vector2.ZERO
var mouseDifference : Vector2
var isOver : bool
var dragging : bool = false
var collideLayer : int

enum floating {overTable, overLeftHand, overRightHand}
var cardFloating : floating = floating.overTable
enum states {onTable, inLeftHand, inRightHand}
var cardStates : states = states.onTable

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
		
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	
func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	isOver = true

func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	isOver = false

func _physics_process(delta: float) -> void:
	mouseDifference = mousePosition - get_global_mouse_position()
	
	if dragging and mouseDifference != Vector2.ZERO:
		global_position -= mouseDifference
	
	if isOver and Input.is_action_just_pressed("leftClick"):
		dragging = true
		
	if dragging and Input.is_action_just_released("leftClick"):
		dragging = false
		if cardFloating == floating.overRightHand:
			cardStates = states.inRightHand
			print("Card in right hand")
		elif cardFloating == floating.overLeftHand:
			cardStates = states.inLeftHand
			print("Card in left hand")
		elif cardFloating == floating.overTable:
			cardStates = states.onTable
			print("Card on table")
		
	mousePosition = get_global_mouse_position()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(3) == true:
		cardFloating = floating.overRightHand
	elif area.get_collision_layer_value(2) == true:
		cardFloating = floating.overLeftHand
	
	if area.get_collision_layer_value(4) == true and dragging:
		ZIndexHandler.masterZ_Index += 1
		z_index = ZIndexHandler.masterZ_Index

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.get_collision_layer_value(3) == true or area.get_collision_layer_value(2) == true:
		cardFloating = floating.overTable
