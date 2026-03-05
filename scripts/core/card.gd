extends Node2D

# For testing -----------------------------------------------------------------
var paperA = preload("res://assets/sprites/Paper A.png")
var paperB = preload("res://assets/sprites/Paper B.png")
var paperC = preload("res://assets/sprites/Paper C.png")
@export var paperType := Sprite2D
# End -------------------------------------------------------------------------

var mousePosition : Vector2 = Vector2.ZERO
var leftHandPosition: Vector2 = Vector2(-350, 200)
var rightHandPosition: Vector2 = Vector2(375, 200)
var previousPosition : Vector2
var mouseDifference : Vector2

var isOver : bool
var dragging : bool = false
var thisCardInLeftHand : bool = false
var thisCardInRightHand : bool = false
var isColliding: bool = false

var cardsTouching: int = 0

enum floating {overTable, overLeftHand, overRightHand, overNothing}
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
		
	# Enables a setting that forces the only the top card to be selected when cards are overlaping
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	previousPosition = position

# Tracks if the mouse is over the card
func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	isOver = true
func _on_area_2d_mouse_shape_exited(shape_idx: int) -> void:
	isOver = false

func _physics_process(delta: float) -> void:
	mouseDifference = mousePosition - get_global_mouse_position()
	drag_handler()
	hand_handler()
	placement_handler()
	mousePosition = get_global_mouse_position()

# Moves the card to the position of the mouse and handles if the card is being dragged
func drag_handler():
	if dragging and mouseDifference != Vector2.ZERO:
		global_position -= mouseDifference
	
	if isOver and Input.is_action_just_pressed("leftClick"):
		dragging = true
	elif dragging and Input.is_action_just_released("leftClick"):
		dragging = false

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
	if !dragging and cardStates == states.inRightHand:
		position = rightHandPosition
		CardHandler.rightHandEmpty = false
		thisCardInRightHand = true
	elif !dragging and cardStates == states.inLeftHand:
		position = leftHandPosition
		CardHandler.leftHandEmpty = false
		thisCardInLeftHand = true
	elif !dragging and cardFloating == floating.overTable:
		previousPosition = position
	elif !dragging and cardFloating == floating.overNothing:
		position = previousPosition
	
	if cardStates != states.inRightHand and !CardHandler.rightHandEmpty and thisCardInRightHand:
		CardHandler.rightHandEmpty = true
		thisCardInRightHand = false
	
	if cardStates != states.inLeftHand and !CardHandler.leftHandEmpty and thisCardInLeftHand:
		CardHandler.leftHandEmpty = true
		thisCardInLeftHand = false

# Checks what layer the card has collided with and changes the state to the appropriate position
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(3) and CardHandler.rightHandEmpty:
		cardFloating = floating.overRightHand
	elif area.get_collision_layer_value(2) and CardHandler.leftHandEmpty:
		cardFloating = floating.overLeftHand
	elif area.get_collision_layer_value(1):
		cardFloating = floating.overTable
	
	# Changes the z_index of the most recently set card to the top if it collides with another card
	if area.get_collision_layer_value(4):
		cardsTouching += 1
		if dragging and !isColliding:
			CardHandler.masterZ_Index += 1
			z_index = CardHandler.masterZ_Index
		
		if !isColliding:
			isColliding = true

func _on_area_2d_area_exited(area: Area2D) -> void:
	# If the card is no longer colliding with the left or right hand, or the table, it is set to over nothing
	if area.get_collision_layer_value(3) or area.get_collision_layer_value(2) or area.get_collision_layer_value(1):
		cardFloating = floating.overNothing
	
	if area.get_collision_layer_value(4):
		cardsTouching -= 1
		if cardsTouching == 0:
			isColliding = false
