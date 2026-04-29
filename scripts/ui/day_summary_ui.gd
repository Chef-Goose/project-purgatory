extends Control
class_name DaySummaryUI

@export var summary_label_path: NodePath
@export var continue_button_path: NodePath

@onready var summary_label: Label = get_node(summary_label_path)
@onready var continue_button: Button = get_node(continue_button_path)

var day_cycle_manager: DayCycleManager


func _ready() -> void:
	day_cycle_manager = get_node("/root/GameManager") as DayCycleManager
	if not day_cycle_manager:
		push_error("DaySummaryUI: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
		return
	
	continue_button.pressed.connect(_on_continue_pressed)
	_update_summary()


func _update_summary() -> void:
	if not day_cycle_manager:
		return
	
	var heaven_count = 0
	var hell_count = 0
	
	for fate_value in day_cycle_manager.characters_fated_today.values():
		if fate_value == "heaven":
			heaven_count += 1
		elif fate_value == "hell":
			hell_count += 1
	
	var summary_text = "Day %d Summary\n\n" % day_cycle_manager.current_day
	summary_text += "Sent to Heaven: %d\n" % heaven_count
	summary_text += "Sent to Hell: %d\n\n" % hell_count
	summary_text += ""
	
	summary_label.text = summary_text


func _on_continue_pressed() -> void:
	if day_cycle_manager:
		day_cycle_manager.go_to_overworld()
