extends Node2D

@onready var player: OverworldPlayer = $World/Player
@onready var prompt_label: Label = $UILayer/PromptPanel/PromptLabel
@onready var inventory_label: Label = $UILayer/InventoryPanel/InventoryLabel
@onready var status_label: Label = $UILayer/StatusLabel
@onready var dialogue_ui: Control = $DialogueUILayer/DialogueUI

var day_manager: DayCycleManager
var _collected_items: Dictionary = {}
var _dialogue_active: bool = false
var _current_prompt_target: OverworldInteractable


func _ready() -> void:
	day_manager = get_node_or_null("/root/GameManager") as DayCycleManager
	if day_manager == null:
		push_error("Overworld: GameManager autoload not found. Did you set it up in Project Settings -> Autoload?")

	if player != null:
		player.interaction_target_changed.connect(_on_interaction_target_changed)
		player.interaction_requested.connect(_on_interaction_requested)

	if dialogue_ui != null and dialogue_ui.has_signal("dialogue_finished"):
		dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)

	if status_label != null:
		if day_manager != null:
			status_label.text = "Overworld - Day %d" % day_manager.current_day
		else:
			status_label.text = "Overworld"

	_set_prompt_target(null)
	_refresh_inventory_label()


func _on_interaction_target_changed(target: OverworldInteractable) -> void:
	_set_prompt_target(target)


func _on_interaction_requested(target: OverworldInteractable) -> void:
	if _dialogue_active:
		return

	if target == null or not is_instance_valid(target):
		return

	if not target.can_interact():
		_set_prompt_target(player.get_current_interactable() if player != null else null)
		return

	_handle_interaction(target)


func _handle_interaction(target: OverworldInteractable) -> void:
	match target.interaction_type:
		OverworldInteractable.InteractionType.SCENE_SWITCH:
			if target.target_scene_path.is_empty():
				push_warning("Overworld: Scene-switch interactable has no target scene path.")
				return
			if not ResourceLoader.exists(target.target_scene_path):
				push_warning("Overworld: Target scene does not exist: %s" % target.target_scene_path)
				return
			get_tree().change_scene_to_file(target.target_scene_path)

		OverworldInteractable.InteractionType.DIALOGUE:
			if dialogue_ui == null:
				push_warning("Overworld: DialogueUI is missing.")
				return
			if target.dialogue_resource == null:
				push_warning("Overworld: Dialogue interactable has no DialogueResource assigned.")
				return
			_dialogue_active = true
			if player != null:
				player.set_movement_locked(true)
			_set_prompt_target(null)
			dialogue_ui.start(target.dialogue_resource, target.dialogue_title)

		OverworldInteractable.InteractionType.ITEM_PICKUP:
			var resolved_item_id: String = target.item_id.strip_edges()
			if resolved_item_id.is_empty():
				resolved_item_id = target.name.to_lower().replace(" ", "_")

			_collected_items[resolved_item_id] = target.get_item_label()
			target.mark_used()
			if target.consume_on_use and target.queue_free_on_use:
				target.queue_free()

			if status_label != null:
				status_label.text = "Picked up: %s" % _collected_items[resolved_item_id]

			_refresh_inventory_label()
			_set_prompt_target(player.get_current_interactable() if player != null else null)


func _on_dialogue_finished() -> void:
	_dialogue_active = false
	if player != null:
		player.set_movement_locked(false)
	_set_prompt_target(player.get_current_interactable() if player != null else null)


func _set_prompt_target(target: OverworldInteractable) -> void:
	_current_prompt_target = target
	if prompt_label == null:
		return

	if _dialogue_active or target == null or not is_instance_valid(target) or not target.can_interact():
		prompt_label.text = "Explore and walk up to an interactable."
		return

	prompt_label.text = "[E] or [Enter] - %s" % target.get_prompt_text()


func _refresh_inventory_label() -> void:
	if inventory_label == null:
		return

	if _collected_items.is_empty():
		inventory_label.text = "Items: (none)"
		return

	var item_names: PackedStringArray = []
	for item_name in _collected_items.values():
		item_names.append(str(item_name))

	inventory_label.text = "Items: %s" % ", ".join(item_names)
