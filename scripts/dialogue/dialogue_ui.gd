extends Control


@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"
@export var will_block_other_input: bool = true
@export var force_scroll_tag: String = "force_scroll"
@export_range(0.0, 2.0, 0.01) var min_advance_delay_seconds: float = 0.2

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


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text_box.focus_mode = Control.FOCUS_NONE
	speaker_box.focus_mode = Control.FOCUS_NONE
	response_template.focus_mode = Control.FOCUS_ALL
	response_template.visible = false
	_clear_responses()

	visible = false
	progress.visible = false

	if auto_start:
		if dialogue_resource == null:
			push_error("Auto start is enabled but dialogue_resource is not set on DialogueUI.")
			return
		start()


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


func _go_to_line(next_id: String) -> void:
	is_waiting_for_input = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)

	if dialogue_line == null:
		visible = false
		return

	_apply_dialogue_line()


func _apply_dialogue_line() -> void:
	speaker_box.visible = not dialogue_line.character.is_empty()
	speaker_label.text = tr(dialogue_line.character, "dialogue")
	_clear_responses()

	dialogue_label.dialogue_line = dialogue_line

	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		_show_responses(dialogue_line.responses)
		is_waiting_for_input = false
		return

	_begin_advance_lock()
	is_waiting_for_input = true


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
