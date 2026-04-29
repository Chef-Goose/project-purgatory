extends Node2D

func _ready() -> void:
	var button = find_child("LunchBreakButton", true, false) as Button
	if button:
		button.pressed.connect(_on_lunch_break_pressed)


func _on_lunch_break_pressed() -> void:
	var day_manager = get_node("/root/GameManager") as DayCycleManager
	if day_manager:
		day_manager.go_to_lunch_break()
	else:
		push_error("Overworld: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
