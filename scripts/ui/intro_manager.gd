extends Node2D

func _ready() -> void:
	var button = find_child("StartButton", true, false) as Button
	if button:
		button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	var day_manager = get_node("/root/GameManager") as DayCycleManager
	if day_manager:
		day_manager.intro_complete()
	else:
		push_error("Intro: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
