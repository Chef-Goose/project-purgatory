extends Control
class_name DaySummaryUI

@export var summary_label_path: NodePath
@export var stats_container_path: NodePath
@export var continue_button_path: NodePath
@export var supabase_url: String = ""
@export var supabase_anon_key: String = ""
@export var vote_stats_table: String = "character_vote_stats"

const SUPABASE_URL_SETTING := "leaderboard/supabase_url"
const SUPABASE_ANON_KEY_SETTING := "leaderboard/supabase_anon_key"
const LOCAL_SECRETS_PATH := "res://config/secrets.cfg"

@onready var summary_label: Label = get_node(summary_label_path)
@onready var stats_container: VBoxContainer = get_node(stats_container_path)
@onready var continue_button: Button = get_node(continue_button_path)

var _http_request: HTTPRequest
var _stats_rows: Array[Dictionary] = []


func _ready() -> void:
	if summary_label:
		summary_label.text = "Global vote stats"

	_clear_stats_rows()
	var loading_label := Label.new()
	loading_label.text = "Loading global vote stats..."
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_container.add_child(loading_label)

	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

	continue_button.pressed.connect(_on_continue_pressed)
	_fetch_vote_stats()


func _fetch_vote_stats() -> void:
	var resolved_supabase_url := _get_supabase_url()
	var resolved_supabase_anon_key := _get_supabase_anon_key()

	if resolved_supabase_url.is_empty() or resolved_supabase_anon_key.is_empty():
		_render_error("Supabase not configured yet.")
		return

	_stats_rows.clear()

	var request_url := "%s/rest/v1/%s?select=character_id,heaven_count,hell_count&order=character_id.asc" % [
		resolved_supabase_url,
		vote_stats_table.strip_edges()
	]
	var headers := PackedStringArray([
		"apikey: " + resolved_supabase_anon_key,
		"Authorization: Bearer " + resolved_supabase_anon_key,
		"Accept: application/json"
	])

	var error_code := _http_request.request(request_url, headers, HTTPClient.METHOD_GET)
	if error_code != OK:
		_render_error("Failed to request Supabase vote stats (error %s)." % error_code)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		_render_error("Supabase request failed (result %s, response %s)." % [result, response_code])
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array:
		_stats_rows = []
		for entry in parsed:
			if entry is Dictionary:
				_stats_rows.append(entry)
		_render_summary()
		return

	_render_error("Unexpected Supabase response.")


func _render_summary(error_message: String = "") -> void:
	if not summary_label or not stats_container:
		return

	_clear_stats_rows()

	if not error_message.is_empty():
		var error_label := Label.new()
		error_label.text = error_message
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_container.add_child(error_label)
		return

	var day_cycle_manager := get_node_or_null("/root/GameManager") as DayCycleManager
	if not day_cycle_manager:
		var missing_label := Label.new()
		missing_label.text = "GameManager not available."
		stats_container.add_child(missing_label)
		return

	if day_cycle_manager.characters_fated_today.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No characters were fated today."
		stats_container.add_child(empty_label)
		return

	for character: CharacterData in day_cycle_manager.characters_for_today:
		if character == null:
			continue
		if not day_cycle_manager.characters_fated_today.has(character.character_id):
			continue

		var row: Dictionary = _get_stats_row(character.character_id)
		var heaven_count := int(row.get("heaven_count", 0))
		var hell_count := int(row.get("hell_count", 0))
		var total_votes := heaven_count + hell_count
		var fate := str(character.fate_assigned)
		var left_text := _build_left_text(character.character_name, fate, hell_count, heaven_count)
		var right_text := _build_right_text(fate, heaven_count, hell_count, total_votes)

		stats_container.add_child(_build_stat_row(left_text, right_text))


func _render_error(error_message: String) -> void:
	_render_summary(error_message)


func _build_stat_row(left_text: String, right_text: String) -> HBoxContainer:
	var row_container := HBoxContainer.new()
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	row_container.add_theme_constant_override("separation", 12)

	var left_label := Label.new()
	left_label.text = left_text
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var right_label := Label.new()
	right_label.text = right_text
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_label.size_flags_horizontal = Control.SIZE_SHRINK_END

	row_container.add_child(left_label)
	row_container.add_child(spacer)
	row_container.add_child(right_label)
	return row_container


func _build_left_text(character_name: String, fate: String, hell_count: int, heaven_count: int) -> String:
	var supporters := hell_count if fate == "hell" else heaven_count
	var other_players := maxi(supporters - 1, 0)
	var destination := "Hell" if fate == "hell" else "Heaven"
	return "You and %d other players sent %s to %s" % [other_players, character_name, destination]


func _build_right_text(fate: String, heaven_count: int, hell_count: int, total_votes: int) -> String:
	if total_votes <= 0:
		return "0/0 | 0%"

	var choice_count := hell_count if fate == "hell" else heaven_count
	var percent := int(round((float(choice_count) / float(total_votes)) * 100.0))
	return "%d/%d | %d%%" % [choice_count, total_votes, percent]


func _get_stats_row(character_id: String) -> Dictionary:
	for row: Dictionary in _stats_rows:
		if str(row.get("character_id", "")) == character_id:
			return row
	return {}


func _clear_stats_rows() -> void:
	if not stats_container:
		return

	for child in stats_container.get_children():
		child.queue_free()


func _get_supabase_url() -> String:
	var project_value := str(ProjectSettings.get_setting(SUPABASE_URL_SETTING, ""))
	if not project_value.strip_edges().is_empty():
		return project_value.strip_edges()

	var secrets_value := _get_secret_value("supabase_url")
	if not secrets_value.is_empty():
		return secrets_value

	return supabase_url.strip_edges()


func _get_supabase_anon_key() -> String:
	var project_value := str(ProjectSettings.get_setting(SUPABASE_ANON_KEY_SETTING, ""))
	if not project_value.strip_edges().is_empty():
		return project_value.strip_edges()

	var secrets_value := _get_secret_value("supabase_anon_key")
	if not secrets_value.is_empty():
		return secrets_value

	return supabase_anon_key.strip_edges()


func _get_secret_value(key_name: String) -> String:
	if not FileAccess.file_exists(LOCAL_SECRETS_PATH):
		return ""

	var secrets_file := FileAccess.open(LOCAL_SECRETS_PATH, FileAccess.READ)
	if secrets_file == null:
		return ""

	while not secrets_file.eof_reached():
		var line := secrets_file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var equals_index := line.find("=")
		if equals_index == -1:
			continue

		var parsed_key := line.substr(0, equals_index).strip_edges()
		if parsed_key != key_name:
			continue

		var parsed_value := line.substr(equals_index + 1, line.length() - equals_index - 1).strip_edges()
		if parsed_value.begins_with('"') and parsed_value.ends_with('"') and parsed_value.length() >= 2:
			parsed_value = parsed_value.substr(1, parsed_value.length() - 2)

		return parsed_value

	return ""


func _on_continue_pressed() -> void:
	var day_cycle_manager := get_node_or_null("/root/GameManager") as DayCycleManager
	if day_cycle_manager:
		day_cycle_manager.go_to_overworld()
