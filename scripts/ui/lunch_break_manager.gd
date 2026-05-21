extends Control
class_name LunchBreakManager

@export var dialogue_ui_path: NodePath
@export var continue_button_path: NodePath
@export var day_label_path: NodePath

@onready var dialogue_ui: Control = get_node_or_null(dialogue_ui_path) as Control
@onready var continue_button: Button = get_node_or_null(continue_button_path) as Button
@onready var day_label: Label = get_node_or_null(day_label_path) as Label

# Flexible cast slots (use CastSlot resources to configure N slots in inspector)
@export var cast_slots: Array[CastSlot] = []

var day_manager: DayCycleManager


func _ready() -> void:
	day_manager = get_node_or_null("/root/GameManager") as DayCycleManager
	if day_manager == null:
		push_error("LunchBreak: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")
		return

	if continue_button != null:
		continue_button.pressed.connect(_on_next_day_pressed)
		continue_button.visible = false

	if dialogue_ui != null and dialogue_ui.has_signal("dialogue_finished"):
		dialogue_ui.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))

	_update_day_label()
	_start_day_dialogue()


func _update_day_label() -> void:
	if day_label != null:
		day_label.text = "Lunch Break - Day %d" % day_manager.current_day


func _start_day_dialogue() -> void:
	if dialogue_ui == null:
		push_error("LunchBreak: DialogueUI node not found in the scene tree.")
		return

	var lunch_dialogue := load("res://scripts/dialogue/lunch_break.dialogue") as DialogueResource
	if lunch_dialogue == null:
		push_error("LunchBreak: Could not load lunch break dialogue resource.")
		return

	var branch_title := _get_branch_title_for_day(day_manager.current_day)
	if not lunch_dialogue.titles.has(branch_title):
		branch_title = "later_days" if lunch_dialogue.titles.has("later_days") else "start"

	# Populate DialogueUI cast mapping based on configured slots and who actually speaks in the branch
	var dialogue_file_path := "res://scripts/dialogue/lunch_break.dialogue"
	var speakers_in_branch: Array = _get_speakers_in_branch(dialogue_file_path, branch_title)
	_set_dialogue_cast_slot_paths()
	_populate_dialogue_ui_cast(speakers_in_branch)

	dialogue_ui.visible = true
	dialogue_ui.call("start", lunch_dialogue, branch_title)


func _get_branch_title_for_day(current_day: int) -> String:
	match current_day:
		1:
			return "day_1"
		2:
			return "day_2"
		3:
			return "day_3"
		_:
			return "later_days"


func _on_dialogue_finished() -> void:
	if continue_button != null:
		continue_button.visible = true
		continue_button.grab_focus()


func _on_next_day_pressed() -> void:
	if day_manager != null:
		day_manager.next_day()
	else:
		push_error("LunchBreak: GameManager autoload not found. Did you set it up in Project Settings → Autoload?")


func _populate_dialogue_ui_cast(speakers_in_branch: Array) -> void:
	if dialogue_ui == null:
		return

	var mapping := {}

	# If cast_slots configured, prefer them
	if cast_slots.size() > 0:
		for slot in cast_slots:
			if typeof(slot) == TYPE_OBJECT and slot != null:
				var node_path: NodePath = slot.node_path
				var speaker_name: String = str(slot.default_speaker)
				_assign_slot(mapping, speakers_in_branch, speaker_name, node_path)

	# Apply mapping to DialogueUI (overrides scene-set mapping)
	if mapping.size() > 0:
		dialogue_ui.set("portrait_node_paths", mapping)
	else:
		# Clear mapping so DialogueUI falls back to its default behavior
		dialogue_ui.set("portrait_node_paths", {})


func _set_dialogue_cast_slot_paths() -> void:
	if dialogue_ui == null:
		return

	var slot_paths: Array[NodePath] = []
	for slot in cast_slots:
		if typeof(slot) == TYPE_OBJECT and slot != null and not slot.node_path.is_empty():
			var slot_node = get_node_or_null(slot.node_path)
			if slot_node != null:
				slot_paths.append(dialogue_ui.get_path_to(slot_node))

	dialogue_ui.set("cast_slot_paths", slot_paths)


func _get_speakers_in_branch(dialogue_file_path: String, branch_title: String) -> Array:
	var result: Array = []
	var f = FileAccess.open(dialogue_file_path, FileAccess.ModeFlags.READ)
	if f == null:
		return result
	var in_section: bool = false
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("~"):
			# new section
			var section_name = line.substr(1).strip_edges()
			in_section = section_name == branch_title
			continue
		if not in_section:
			continue
		if line == "=> END" or line == "=> END":
			break
		# Match lines like 'Name: text'
		if line.find(":") != -1:
			var parts = line.split(":", false, 2)
			if parts.size() >= 2:
				var speaker = parts[0].strip_edges().to_lower()
				if speaker != "" and not result.has(speaker):
					result.append(speaker)

	f.close()
	return result


func _assign_slot(mapping: Dictionary, speakers_in_branch: Array, speaker_name: String, slot_path: NodePath) -> void:
	if slot_path == null or str(slot_path).strip_edges().is_empty():
		return
	var node = get_node_or_null(slot_path)
	if node == null:
		return
	# Determine if this speaker speaks in the branch
	var normalized_speaker: String = speaker_name.strip_edges().to_lower()
	if normalized_speaker != "" and speakers_in_branch.has(normalized_speaker):
		# Compute NodePath relative to DialogueUI so DialogueUI can resolve it
		var path_from_dui: NodePath = dialogue_ui.get_path_to(node)
		mapping[normalized_speaker] = path_from_dui
		node.visible = true
	else:
		node.visible = false
