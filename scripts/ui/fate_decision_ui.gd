extends PanelContainer
class_name FateDecisionUI

@export var heaven_button_path: NodePath
@export var hell_button_path: NodePath
@export var character_name_label_path: NodePath
@export var decision_prompt_path: NodePath
@export var toggle_button_path: NodePath

@onready var heaven_button: Button = get_node(heaven_button_path)
@onready var hell_button: Button = get_node(hell_button_path)
@onready var character_name_label: Label = get_node(character_name_label_path)
@onready var decision_prompt: Label = get_node(decision_prompt_path)
@onready var toggle_button: Button = get_parent().find_child("ToggleButton", false, false) as Button

var day_cycle_manager: DayCycleManager
var current_character: CharacterData
var is_panel_visible: bool = false


func _ready() -> void:
	day_cycle_manager = get_node("/root/GameManager") as DayCycleManager
	if not day_cycle_manager:
		push_error("FateDecisionUI: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
		return
	
	if not toggle_button:
		push_error("FateDecisionUI: ToggleButton not found")
		return
	
	heaven_button.pressed.connect(_on_heaven_pressed)
	hell_button.pressed.connect(_on_hell_pressed)
	toggle_button.pressed.connect(_toggle_panel)
	
	# Start with this panel hidden, but CanvasLayer stays visible
	hide()


## Set the current character and update UI
func set_current_character(character: CharacterData) -> void:
	current_character = character
	if current_character:
		character_name_label.text = current_character.character_name
		decision_prompt.text = "Send %s to..." % current_character.character_name
		toggle_button.show()
	else:
		toggle_button.hide()


## Toggle the decision panel visibility
func _toggle_panel() -> void:
	if not current_character:
		return
	
	is_panel_visible = !is_panel_visible
	if is_panel_visible:
		show()
	else:
		hide()


## Hide the decision panel
func hide_panel() -> void:
	is_panel_visible = false
	hide()


func _on_heaven_pressed() -> void:
	if current_character and day_cycle_manager:
		day_cycle_manager.assign_fate(current_character, "heaven")
		_on_fate_chosen()


func _on_hell_pressed() -> void:
	if current_character and day_cycle_manager:
		day_cycle_manager.assign_fate(current_character, "hell")
		_on_fate_chosen()


func _on_fate_chosen() -> void:
	hide_panel()
	# Mark character as processed and move to next character
	if day_cycle_manager:
		day_cycle_manager.on_character_conversation_complete(current_character)
