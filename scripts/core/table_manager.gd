extends Node2D
class_name TableManager

@onready var fate_ui_canvas: CanvasLayer = $FateDecisionUI
@onready var fate_ui: FateDecisionUI = $FateDecisionUI.find_child("DecisionPanel", true, false) as FateDecisionUI
@onready var character_look_zone: Area2D = $CameraZones/CharacterLook
@onready var dialogue_ui: Control = $DialogueUILayer/DialogueUI
@onready var camera_controller: TableCameraController = $Camera2D
@onready var character_layer: Node2D = $CanvasLayer
@onready var passport_spawn_point: Node2D = $PassportSpawnPoint

@export var passport_scene: PackedScene = preload("res://scenes/objects/passport_info.tscn")

var passport_info: Node2D

var day_cycle_manager: DayCycleManager
var current_character: CharacterData
var _awaiting_dialogue_start: bool = false
var _dialogue_active: bool = false
var _character_entry_tween: Tween
var _character_exit_tween: Tween
var _passport_entry_tween: Tween
var _passport_exit_tween: Tween
var _character_base_position: Vector2 = Vector2.ZERO
var _passport_base_position: Vector2 = Vector2.ZERO

const CHARACTER_ENTRY_FADE_DURATION := 1.05
const CHARACTER_HEAVEN_EXIT_FADE_DURATION := 0.65
const CHARACTER_HELL_EXIT_DURATION := 0.18
const CHARACTER_HELL_DROP_DISTANCE := 120.0
const PASSPORT_ENTRY_DURATION := 1.10
const PASSPORT_EXIT_DURATION := 1.00

## Item ID to scene path mapping
var item_scene_map: Dictionary = {
	"rubber_duck": "res://scenes/objects/rubber_duck.tscn",
	"marble": "res://scenes/objects/marble.tscn",
	"cocktail": "res://scenes/objects/cocktail.tscn",
	"mallard_duck": "res://scenes/objects/mallard_duck.tscn",
	"root_beer": "res://scenes/objects/root_beer.tscn",
}

## Spawn positions for items (around the table)
var item_spawn_positions: Array[Vector2] = [
	Vector2(-100, -150),
	Vector2(100, -150),
	Vector2(-300, -200),
	Vector2(300, -200),
	Vector2(-450, -270),
	Vector2(450, -270),
]

var _spawned_items: Array[Node] = []


func _ready() -> void:
	day_cycle_manager = get_node("/root/GameManager") as DayCycleManager
	if not day_cycle_manager:
		push_error("TableManager: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
		return
	if day_cycle_manager.has_signal("fate_assigned"):
		day_cycle_manager.fate_assigned.connect(_on_fate_assigned)
	if day_cycle_manager.has_signal("current_character_changed"):
		day_cycle_manager.current_character_changed.connect(_on_current_character_changed)
	
	if not fate_ui:
		push_error("TableManager: FateDecisionUI not found in scene tree")
		return

	if camera_controller == null:
		push_error("TableManager: Camera2D not found in scene tree")
		return

	if character_look_zone != null and character_look_zone.has_signal("clicked"):
		character_look_zone.clicked.connect(_on_character_look_clicked)
	if camera_controller.has_signal("snap_completed"):
		camera_controller.snap_completed.connect(_on_character_camera_snap_completed)
	if dialogue_ui != null and dialogue_ui.has_signal("dialogue_finished"):
		dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	if fate_ui != null and fate_ui.has_signal("panel_visibility_changed"):
		fate_ui.panel_visibility_changed.connect(_on_fate_panel_visibility_changed)
	passport_info = get_node_or_null("PassportInfo") as Node2D
	if character_layer != null:
		_character_base_position = character_layer.position
	if passport_spawn_point != null:
		_passport_base_position = passport_spawn_point.position
	
	# Load the current character for today
	current_character = day_cycle_manager.get_current_character()
	if not current_character:
		day_cycle_manager.prepare_day()
		current_character = day_cycle_manager.get_current_character()
		if not current_character:
			push_error("TableManager: No current character in day cycle")
			return
	
	_spawn_passport_node()
	_update_passport_info()

	# Wire the fate UI to know about this character
	fate_ui.set_current_character(current_character)
	fate_ui.set_fate_button_visible(true)

	if dialogue_ui != null:
		dialogue_ui.visible = false
		dialogue_ui.set_process_unhandled_input(true)
	camera_controller.set_interaction_locked(false)
	
	# Spawn items from the player's inventory
	_spawn_inventory_items()


func _update_passport_info() -> void:
	if passport_scene == null:
		push_error("TableManager: passport_scene is not assigned")
		return

	if passport_info == null or not is_instance_valid(passport_info):
		_spawn_passport_node()

	if passport_info == null:
		return

	var passport_sprite := passport_info.get_node_or_null("object") as Sprite2D
	if passport_sprite != null:
		passport_sprite.texture = preload("res://assets/testing/Paper A.png")
	
	# Update the passport info display with current character data
	var passport_display = passport_info.get_node_or_null("object/PassportDisplay") as PassportInfo
	if passport_display and current_character:
		passport_display.set_character_data(current_character)


func _spawn_passport_node() -> void:
	if passport_scene == null:
		return

	var passport_parent: Node = self
	if passport_info != null and is_instance_valid(passport_info):
		passport_parent = passport_info.get_parent()
		if passport_info.has_method("force_drop_from_hand"):
			passport_info.call("force_drop_from_hand")
		passport_info.queue_free()

	var new_passport = passport_scene.instantiate() as Node2D
	if new_passport == null:
		push_error("TableManager: Failed to instantiate passport scene")
		return

	passport_parent.add_child(new_passport)
	new_passport.position = _passport_base_position
	new_passport.modulate.a = 0.0
	passport_info = new_passport
	_animate_passport_entry(new_passport)


func _animate_passport_entry(passport_node: Node2D) -> void:
	if passport_node == null:
		return

	if _passport_entry_tween != null and _passport_entry_tween.is_valid():
		_passport_entry_tween.kill()

	passport_node.modulate.a = 0.0

	_passport_entry_tween = create_tween()
	_passport_entry_tween.set_trans(Tween.TRANS_SINE)
	_passport_entry_tween.set_ease(Tween.EASE_OUT)
	_passport_entry_tween.tween_property(passport_node, "modulate:a", 1.0, PASSPORT_ENTRY_DURATION)


func _animate_passport_exit() -> void:
	if passport_info == null or not is_instance_valid(passport_info):
		return

	if _passport_entry_tween != null and _passport_entry_tween.is_valid():
		_passport_entry_tween.kill()

	if _passport_exit_tween != null and _passport_exit_tween.is_valid():
		_passport_exit_tween.kill()

	_passport_exit_tween = create_tween()
	_passport_exit_tween.set_trans(Tween.TRANS_SINE)
	_passport_exit_tween.set_ease(Tween.EASE_IN)
	_passport_exit_tween.tween_property(passport_info, "modulate:a", 0.0, PASSPORT_EXIT_DURATION)


func _animate_character_exit(fate: String) -> void:
	if character_layer == null:
		return

	if _character_entry_tween != null and _character_entry_tween.is_valid():
		_character_entry_tween.kill()

	if _character_exit_tween != null and _character_exit_tween.is_valid():
		_character_exit_tween.kill()

	_character_exit_tween = create_tween()
	_character_exit_tween.set_trans(Tween.TRANS_CUBIC)
	_character_exit_tween.set_ease(Tween.EASE_IN)

	if fate == "hell":
		_character_exit_tween.parallel().tween_property(character_layer, "position", _character_base_position + Vector2(0.0, CHARACTER_HELL_DROP_DISTANCE), CHARACTER_HELL_EXIT_DURATION)
		_character_exit_tween.parallel().tween_property(character_layer, "modulate:a", 0.0, CHARACTER_HELL_EXIT_DURATION)
	else:
		_character_exit_tween.tween_property(character_layer, "modulate:a", 0.0, CHARACTER_HEAVEN_EXIT_FADE_DURATION)


func _animate_character_entry() -> void:
	if character_layer == null:
		return

	if _character_entry_tween != null and _character_entry_tween.is_valid():
		_character_entry_tween.kill()

	character_layer.modulate.a = 0.0
	_character_entry_tween = create_tween()
	_character_entry_tween.set_trans(Tween.TRANS_SINE)
	_character_entry_tween.set_ease(Tween.EASE_OUT)
	_character_entry_tween.tween_property(character_layer, "modulate:a", 1.0, CHARACTER_ENTRY_FADE_DURATION)


func _on_character_look_clicked() -> void:
	if fate_ui != null and fate_ui.is_panel_open():
		return

	if _dialogue_active or _awaiting_dialogue_start:
		return

	_awaiting_dialogue_start = true
	camera_controller.set_interaction_locked(true)


func _on_character_camera_snap_completed() -> void:
	if not _awaiting_dialogue_start or _dialogue_active:
		return

	_awaiting_dialogue_start = false
	_dialogue_active = true
	fate_ui.set_fate_button_visible(false)
	if dialogue_ui != null:
		var dialogue_slot := day_cycle_manager.get_dialogue_slot_for_character(current_character)
		dialogue_ui.start_for_character(current_character, dialogue_slot)


func _on_dialogue_finished() -> void:
	_dialogue_active = false
	_awaiting_dialogue_start = false
	fate_ui.set_fate_button_visible(true)
	camera_controller.set_interaction_locked(fate_ui != null and fate_ui.is_panel_open())


func _on_fate_panel_visibility_changed(is_visible: bool) -> void:
	if is_visible:
		# Prevent dialogue from auto-starting if fate was opened during a pending snap.
		_awaiting_dialogue_start = false
		camera_controller.clear_snap()
		camera_controller.clear_hover_zones()
		camera_controller.set_interaction_locked(true)
		fate_ui.set_fate_button_visible(true)
		if dialogue_ui != null:
			dialogue_ui.set_process_unhandled_input(false)
		return

	if dialogue_ui != null:
		dialogue_ui.set_process_unhandled_input(true)

	camera_controller.set_interaction_locked(_dialogue_active or _awaiting_dialogue_start)
	fate_ui.set_fate_button_visible(not _dialogue_active and not _awaiting_dialogue_start)


func _on_fate_assigned(character: CharacterData, fate: String) -> void:
	if character != current_character:
		return

	if passport_info != null and passport_info.has_method("begin_transition_fade"):
		passport_info.call("begin_transition_fade")
	_animate_passport_exit()
	_animate_character_exit(fate)


func _on_current_character_changed(character: CharacterData) -> void:
	current_character = character
	_dialogue_active = false
	_awaiting_dialogue_start = false
	if dialogue_ui != null:
		dialogue_ui.visible = false
		dialogue_ui.set_process_unhandled_input(true)
	if fate_ui != null:
		fate_ui.set_current_character(current_character)
		fate_ui.set_fate_button_visible(current_character != null)
	if current_character != null:
		if character_layer != null:
			character_layer.position = _character_base_position
			character_layer.modulate.a = 0.0
		_spawn_passport_node()
		_update_passport_info()
		_animate_character_entry()
	camera_controller.set_interaction_locked(false)


func _spawn_inventory_items() -> void:
	# Clear any previously spawned items
	for item in _spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	_spawned_items.clear()
	
	if not day_cycle_manager:
		return
	
	var inventory = day_cycle_manager.get_all_items()
	if inventory.is_empty():
		return
	
	var spawn_index = 0
	for item_id: String in inventory:
		if spawn_index >= item_spawn_positions.size():
			push_warning("TableManager: Too many items to spawn, exceeds available spawn positions")
			break
		
		if item_id not in item_scene_map:
			push_warning("TableManager: Item '%s' not in item_scene_map" % item_id)
			continue
		
		var scene_path = item_scene_map[item_id]
		if not ResourceLoader.exists(scene_path):
			push_warning("TableManager: Item scene does not exist: %s" % scene_path)
			continue
		
		var item_scene = load(scene_path) as PackedScene
		if item_scene == null:
			push_error("TableManager: Failed to load item scene: %s" % scene_path)
			continue
		
		var item_instance = item_scene.instantiate()
		item_instance.position = item_spawn_positions[spawn_index]
		add_child(item_instance)
		_spawned_items.append(item_instance)
		
		spawn_index += 1
