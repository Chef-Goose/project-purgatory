extends Control

signal dialogue_finished


@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"
@export var will_block_other_input: bool = true
@export var force_scroll_tag: String = "force_scroll"
@export_range(0.0, 2.0, 0.01) var min_advance_delay_seconds: float = 0.2
@export var portrait_node_paths: Dictionary = {} # map lowercased speaker name -> NodePath
@export var cast_slot_paths: Array[NodePath] = []
@export var mood_tag_name: String = "mood"
@export var scroll_speed_tag_name: String = "scroll_speed"
@export var auto_advance_tag_name: String = "auto_advance"
@export var auto_advance_delay_tag_name: String = "auto_advance_delay"
@export var speaking_mood_name: String = "talking"
@export var idle_mood_name: String = "idle"
@export var default_character_moods: Dictionary = {}
@export var character_portrait_sets: Array[CharacterPortraitSet] = []

@onready var text_box: PanelContainer = $TextBox
@onready var dialogue_label: DialogueLabel = $TextBox/RichTextLabel
@onready var speaker_box: Control = $SpeakerBox
@onready var speaker_label: Label = $SpeakerBox/Label
@onready var progress: Polygon2D = $Control/Polygon2D
@onready var responses_menu: VBoxContainer = $ResponsesMenu
@onready var response_template: Button = $ResponsesMenu/ResponseTemplate

var dialogue_line: DialogueLine
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var _advance_unlock_time_msec: int = 0
var _portrait_sets_by_character_name: Dictionary = {}
var _active_portrait_speaker_name: String = ""
var _last_active_portrait_node: CharacterPortrait = null
var _default_seconds_per_step: float = 0.03


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text_box.focus_mode = Control.FOCUS_NONE
	speaker_box.focus_mode = Control.FOCUS_NONE
	response_template.focus_mode = Control.FOCUS_ALL
	response_template.visible = false
	_clear_responses()
	_build_portrait_set_lookup()
	_default_seconds_per_step = dialogue_label.seconds_per_step

	visible = false
	progress.visible = false

	if auto_start:
		if dialogue_resource == null:
			push_error("Auto start is enabled but dialogue_resource is not set on DialogueUI.")
			return
		start()


func _resolve_portrait_for_speaker(speaker_name: String) -> CharacterPortrait:
	var key: String = speaker_name.strip_edges().to_lower()
	# Prefer explicit mapping set on the DialogueUI instance
	if portrait_node_paths.has(key):
		var path_val = portrait_node_paths[key]
		if typeof(path_val) == TYPE_NODE_PATH or typeof(path_val) == TYPE_STRING:
			var node = get_node_or_null(path_val) as CharacterPortrait
			if node != null:
				return node

	return null


func _process(_delta: float) -> void:
	if not is_instance_valid(dialogue_line):
		progress.visible = false
		return

	progress.visible = is_waiting_for_input and _is_advance_unlocked() and not dialogue_label.is_typing and dialogue_line.responses.size() == 0


func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states

	if with_dialogue_resource != null:
		dialogue_resource = with_dialogue_resource

	if not title.is_empty():
		start_from_title = title

	if dialogue_resource == null:
		push_error("Cannot start DialogueUI without a DialogueResource.")
		return

	visible = true
	_go_to_line(start_from_title)


func start_for_character(character_data: CharacterData, dialogue_slot: String = "") -> void:
	if character_data == null:
		return

	var dialogue_to_use: DialogueResource = character_data.get_dialogue_resource_for_slot(dialogue_slot)
	if dialogue_to_use == null:
		push_warning("DialogueUI could not resolve a dialogue resource for character '%s' (slot '%s'). Falling back to the scene default." % [character_data.character_name, dialogue_slot])
		dialogue_to_use = dialogue_resource

	var title_to_use: String = start_from_title
	if title_to_use.is_empty():
		title_to_use = character_data.get_dialogue_title_for_slot(dialogue_slot)

	# If the resolved title doesn't actually exist in the DialogueResource,
	# fall back to the dialogue's first_title or start from the top to avoid
	# assertions in the DialogueManager when a label is missing.
	if dialogue_to_use != null and not title_to_use.is_empty():
		if not dialogue_to_use.titles.has(title_to_use):
			push_warning("Dialogue resource %s has no title '%s' for character '%s' (slot '%s'). Falling back to first title or start." % [str(dialogue_to_use), title_to_use, character_data.character_name, dialogue_slot])
			if dialogue_to_use.first_title != null and not dialogue_to_use.first_title.is_empty():
				title_to_use = dialogue_to_use.first_title
			else:
				title_to_use = ""

	if character_portrait_sets.is_empty() and character_data.portrait_set != null:
		character_portrait_sets = [character_data.portrait_set]

	_build_portrait_set_lookup()
	start(dialogue_to_use, title_to_use)


func _go_to_line(next_id: String) -> void:
	is_waiting_for_input = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)

	if dialogue_line == null:
		visible = false
		dialogue_finished.emit()
		return

	_apply_dialogue_line()


func _apply_dialogue_line() -> void:
	speaker_box.visible = not dialogue_line.character.is_empty()
	speaker_label.text = tr(dialogue_line.character, "dialogue")
	_clear_responses()
	_apply_cast_for_line()
	var has_explicit_mood_tag: bool = _apply_portrait_for_line()
	_apply_scroll_speed_for_line()

	dialogue_label.dialogue_line = dialogue_line

	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		if _last_active_portrait_node != null and is_instance_valid(_last_active_portrait_node) and not has_explicit_mood_tag:
			_last_active_portrait_node.set_mood_by_name(idle_mood_name)

	if dialogue_line.responses.size() > 0:
		_show_responses(dialogue_line.responses)
		is_waiting_for_input = false
		return

	if _should_auto_advance_line():
		var delay_seconds: float = _get_auto_advance_delay_seconds_for_line()
		if delay_seconds > 0.0:
			await get_tree().create_timer(delay_seconds).timeout

		if visible and is_instance_valid(dialogue_line):
			_go_to_line(dialogue_line.next_id)
		return

	_begin_advance_lock()
	is_waiting_for_input = true


func _apply_cast_for_line() -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	if not dialogue_line.has_tag("cast"):
		return false

	if cast_slot_paths.is_empty():
		return false

	var raw_cast: String = dialogue_line.get_tag_value("cast").strip_edges()
	if raw_cast.is_empty():
		_clear_cast_slots()
		return true

	var cast_names: PackedStringArray = raw_cast.split(",", true)
	_apply_cast_names_to_slots(cast_names)
	return true


func _apply_portrait_for_line() -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	var normalized_name: String = dialogue_line.character.strip_edges().to_lower()
	if normalized_name.is_empty():
		return false

	# Resolve the portrait node for this speaker
	var target_portrait: CharacterPortrait = _resolve_portrait_for_speaker(dialogue_line.character)
	if target_portrait == null:
		return false

	# If we switched speakers, reset the previous portrait to idle
	if _last_active_portrait_node != null and is_instance_valid(_last_active_portrait_node) and _last_active_portrait_node != target_portrait:
		_last_active_portrait_node.set_mood_by_name(idle_mood_name)

	# Ensure the right textures are applied for this speaker
	_apply_portrait_set_for_speaker(dialogue_line.character)

	var has_explicit_mood_tag: bool = dialogue_line.has_tag(mood_tag_name)
	var mood_name: String = dialogue_line.get_tag_value(mood_tag_name)

	if mood_name.is_empty():
		if default_character_moods.has(dialogue_line.character):
			mood_name = str(default_character_moods[dialogue_line.character])
		elif not dialogue_line.text.is_empty():
			mood_name = speaking_mood_name
		else:
			mood_name = idle_mood_name

	# Apply mood to the resolved portrait node
	target_portrait.set_mood_by_name(mood_name)

	_last_active_portrait_node = target_portrait
	_active_portrait_speaker_name = normalized_name

	return has_explicit_mood_tag


func _apply_cast_names_to_slots(cast_names: PackedStringArray) -> void:
	if cast_slot_paths.is_empty():
		return

	var new_mapping: Dictionary = {}
	for index in range(cast_slot_paths.size()):
		var slot_path: NodePath = cast_slot_paths[index]
		if slot_path.is_empty():
			continue

		var slot_node: CharacterPortrait = get_node_or_null(slot_path) as CharacterPortrait
		if slot_node == null:
			continue

		var speaker_name: String = ""
		if index < cast_names.size():
			speaker_name = str(cast_names[index]).strip_edges()

		if speaker_name.is_empty():
			slot_node.visible = false
			continue

		var normalized_name: String = speaker_name.to_lower()
		new_mapping[normalized_name] = slot_path
		slot_node.visible = true

	portrait_node_paths = new_mapping


func _clear_cast_slots() -> void:
	if cast_slot_paths.is_empty():
		return

	for slot_path: NodePath in cast_slot_paths:
		if slot_path.is_empty():
			continue

		var slot_node: CharacterPortrait = get_node_or_null(slot_path) as CharacterPortrait
		if slot_node != null:
			slot_node.visible = false

	portrait_node_paths.clear()


func _build_portrait_set_lookup() -> void:
	_portrait_sets_by_character_name.clear()
	for portrait_set: CharacterPortraitSet in character_portrait_sets:
		if portrait_set == null:
			continue

		var speaker_name: String = portrait_set.speaker_name.strip_edges()
		if speaker_name.is_empty():
			continue

		_portrait_sets_by_character_name[speaker_name.to_lower()] = portrait_set

		for alias in portrait_set.speaker_aliases:
			var alias_name: String = str(alias).strip_edges()
			if alias_name.is_empty():
				continue

			_portrait_sets_by_character_name[alias_name.to_lower()] = portrait_set


func _apply_portrait_set_for_speaker(speaker_name: String) -> void:
	var normalized_name: String = speaker_name.strip_edges().to_lower()
	if normalized_name.is_empty():
		return

	if normalized_name == _active_portrait_speaker_name:
		return

	if not _portrait_sets_by_character_name.has(normalized_name):
		return

	var portrait_set: CharacterPortraitSet = _portrait_sets_by_character_name[normalized_name] as CharacterPortraitSet
	if portrait_set == null or portrait_set.idle_texture == null:
		return

	# Apply textures to the portrait node resolved for this speaker
	var target_portrait: CharacterPortrait = _resolve_portrait_for_speaker(speaker_name)
	if target_portrait == null:
		return

	target_portrait.set_texture_set(
		portrait_set.idle_texture,
		portrait_set.talking_texture,
		portrait_set.angry_texture,
		portrait_set.sad_texture
	)
	_active_portrait_speaker_name = normalized_name


func _apply_scroll_speed_for_line() -> void:
	if dialogue_label == null or not is_instance_valid(dialogue_line):
		return

	var seconds_per_step: float = _default_seconds_per_step
	if dialogue_line.has_tag(scroll_speed_tag_name):
		var raw_speed: String = dialogue_line.get_tag_value(scroll_speed_tag_name).strip_edges()
		if not raw_speed.is_empty():
			var parsed_speed: float = raw_speed.to_float()
			if parsed_speed > 0.0:
				seconds_per_step = parsed_speed
			else:
				push_warning("Invalid scroll speed tag value '%s'. Using default speed." % raw_speed)

	dialogue_label.seconds_per_step = seconds_per_step


func _should_auto_advance_line() -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	var has_auto_advance_tag: bool = dialogue_line.has_tag(auto_advance_tag_name) or auto_advance_tag_name in dialogue_line.tags
	if not has_auto_advance_tag:
		return false

	var raw_value: String = dialogue_line.get_tag_value(auto_advance_tag_name).strip_edges().to_lower()
	if raw_value in ["0", "false", "no", "off"]:
		return false

	return true


func _get_auto_advance_delay_seconds_for_line() -> float:
	if not is_instance_valid(dialogue_line):
		return 0.0

	if not dialogue_line.has_tag(auto_advance_delay_tag_name):
		return 0.0

	var raw_delay: String = dialogue_line.get_tag_value(auto_advance_delay_tag_name).strip_edges()
	if raw_delay.is_empty():
		return 0.0

	var parsed_delay: float = raw_delay.to_float()
	if parsed_delay < 0.0:
		push_warning("Invalid auto advance delay '%s'. Using 0." % raw_delay)
		return 0.0

	return parsed_delay


func _show_responses(responses: Array) -> void:
	var added_count: int = 0
	for response in responses:
		if not response.is_allowed:
			continue

		var button: Button = response_template.duplicate() as Button
		button.visible = true
		button.disabled = false
		button.text = response.text
		button.focus_mode = Control.FOCUS_ALL
		responses_menu.add_child(button)
		button.pressed.connect(_on_response_selected.bind(response.next_id))
		added_count += 1

	responses_menu.visible = added_count > 0

	if responses_menu.get_child_count() > 1:
		var first_button: Control = responses_menu.get_child(1)
		if first_button != null:
			first_button.grab_focus()


func _clear_responses() -> void:
	for child in responses_menu.get_children():
		if child == response_template:
			continue
		child.queue_free()

	responses_menu.visible = false


func _on_response_selected(next_id: String) -> void:
	get_viewport().set_input_as_handled()
	_go_to_line(next_id)


func _can_skip_current_line() -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	if force_scroll_tag.is_empty():
		return true

	var has_force_scroll_tag: bool = dialogue_line.has_tag(force_scroll_tag) or force_scroll_tag in dialogue_line.tags
	return not has_force_scroll_tag


func _begin_advance_lock() -> void:
	_advance_unlock_time_msec = Time.get_ticks_msec() + int(min_advance_delay_seconds * 1000.0)


func _is_advance_unlocked() -> bool:
	return Time.get_ticks_msec() >= _advance_unlock_time_msec


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_pressed: bool = event.is_action_pressed(skip_action)
		var next_pressed_while_typing: bool = event.is_action_pressed(next_action)
		if (mouse_was_clicked or skip_pressed or next_pressed_while_typing) and _can_skip_current_line():
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return
		elif will_block_other_input:
			get_viewport().set_input_as_handled()
			return

	if not is_waiting_for_input:
		return

	if not _is_advance_unlocked():
		if will_block_other_input:
			get_viewport().set_input_as_handled()
		return

	if dialogue_line.responses.size() > 0:
		if will_block_other_input:
			get_viewport().set_input_as_handled()
		return

	var next_pressed: bool = event.is_action_pressed(next_action)
	var next_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
	if next_pressed or next_clicked:
		get_viewport().set_input_as_handled()
		_go_to_line(dialogue_line.next_id)
	elif will_block_other_input:
		get_viewport().set_input_as_handled()
