extends Control

func _ready() -> void:
	var button = find_child("NextDayButton", true, false) as Button
	if button:
		button.pressed.connect(_on_next_day_pressed)


func _on_next_day_pressed() -> void:
	var day_manager = get_node("/root/GameManager") as DayCycleManager
	if day_manager:
		day_manager.next_day()
	else:
		push_error("LunchBreak: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
