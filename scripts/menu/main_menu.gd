extends Node2D


func _on_start_pressed() -> void:
	var day_manager = get_node("/root/GameManager") as DayCycleManager
	if day_manager:
		await get_tree().create_timer(0.5).timeout
		day_manager.intro_complete()
	else:
		push_error("MainMenu: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")


func _on_options_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("")


func _on_quit_pressed() -> void:
	get_tree().quit()
