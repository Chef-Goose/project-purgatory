extends Node2D

var PaperA = preload("uid://benr7m8oq8esp")
var PaperB = preload("uid://dcxfip4xxbigs")
var PaperC = preload("uid://dpoih4vfpeary")
@export var paperType := Sprite2D

var mousePosition : Vector2 = Vector2.ZERO
var mouseDifference : Vector2
var isOver : bool
var dragging : bool

func _ready() -> void:
	var rand = randi_range(1,3)
	if rand == 1:
		paperType.texture = PaperA
	elif rand == 2:
		paperType.texture = PaperB
	else:
		paperType.texture = PaperC

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
		
	if Input.is_action_just_released("leftClick"):
		dragging = false

	mousePosition = get_global_mouse_position()
