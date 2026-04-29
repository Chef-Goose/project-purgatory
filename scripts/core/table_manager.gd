extends Node2D
class_name TableManager

@onready var fate_ui_canvas: CanvasLayer = $FateDecisionUI
@onready var fate_ui: FateDecisionUI = $FateDecisionUI.find_child("DecisionPanel", true, false) as FateDecisionUI
@onready var passport_info: Node2D = $PassportInfo
@onready var character_look_zone: Area2D = $CameraZones/CharacterLook
@onready var dialogue_ui: CanvasLayer = $DialogueUI

var day_cycle_manager: DayCycleManager
var current_character: CharacterData


func _ready() -> void:
	day_cycle_manager = get_node("/root/GameManager") as DayCycleManager
	if not day_cycle_manager:
		push_error("TableManager: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
		return
	
	if not fate_ui:
		push_error("TableManager: FateDecisionUI not found in scene tree")
		return

	if character_look_zone != null and character_look_zone.has_signal("clicked"):
		character_look_zone.clicked.connect(_on_character_look_clicked)
	
	# Load the current character for today
	current_character = day_cycle_manager.get_current_character()
	if not current_character:
		day_cycle_manager.prepare_day()
		current_character = day_cycle_manager.get_current_character()
		if not current_character:
			push_error("TableManager: No current character in day cycle")
			return
	
	_update_passport_info()

	# Wire the fate UI to know about this character
	fate_ui.set_current_character(current_character)

func _update_passport_info() -> void:
	if passport_info == null:
		return

	var passport_sprite := passport_info.get_node_or_null("object") as Sprite2D
	if passport_sprite != null:
		passport_sprite.texture = preload("res://assets/testing/Paper A.png")


func _on_character_look_clicked() -> void:
	if dialogue_ui != null:
		dialogue_ui.visible = not dialogue_ui.visible
