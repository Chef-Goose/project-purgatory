extends Control

func _ready() -> void:
	var button = find_child("ContinueButton", true, false) as Button
	if button:
		button.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	var day_manager = get_node("/root/GameManager") as DayCycleManager
	if day_manager:
		day_manager.go_to_overworld()
	else:
		push_error("DaySummary: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
