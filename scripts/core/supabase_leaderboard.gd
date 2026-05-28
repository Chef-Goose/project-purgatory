extends Node
class_name SupabaseLeaderboard

signal vote_recorded(character_id: String, choice: String)
signal vote_failed(character_id: String, choice: String, message: String)

@export var supabase_url: String = ""
@export var supabase_anon_key: String = ""
@export var rpc_name: String = "record_character_vote"

const SUPABASE_URL_SETTING := "leaderboard/supabase_url"
const SUPABASE_ANON_KEY_SETTING := "leaderboard/supabase_anon_key"
const LOCAL_SECRETS_PATH := "res://config/secrets.cfg"

var _http_request: HTTPRequest


func _ready() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func record_vote(character_id: String, choice: String) -> void:
	var resolved_supabase_url := _get_supabase_url()
	var resolved_supabase_anon_key := _get_supabase_anon_key()

	if resolved_supabase_url.is_empty() or resolved_supabase_anon_key.is_empty():
		vote_failed.emit(character_id, choice, "Supabase not configured")
		return

	if character_id.strip_edges().is_empty() or choice.strip_edges().is_empty():
		vote_failed.emit(character_id, choice, "Missing character id or choice")
		return

	var request_url := "%s/rest/v1/rpc/%s" % [resolved_supabase_url, rpc_name.strip_edges()]
	var headers := PackedStringArray([
		"apikey: " + resolved_supabase_anon_key,
		"Authorization: Bearer " + resolved_supabase_anon_key,
		"Content-Type: application/json",
		"Prefer: return=representation"
	])
	var body := JSON.stringify({
		"p_character_id": character_id,
		"p_choice": choice
	})

	var error_code := _http_request.request(request_url, headers, HTTPClient.METHOD_POST, body)
	if error_code != OK:
		vote_failed.emit(character_id, choice, "HTTPRequest error %s" % error_code)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)

	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		var failure_character_id := ""
		var failure_choice := ""
		if parsed is Dictionary:
			failure_character_id = str(parsed.get("character_id", ""))
			failure_choice = str(parsed.get("choice", ""))
		vote_failed.emit(failure_character_id, failure_choice, response_text if not response_text.is_empty() else "Supabase request failed")
		return

	var character_id := ""
	var choice := ""
	if parsed is Array and not parsed.is_empty() and parsed[0] is Dictionary:
		var row: Dictionary = parsed[0]
		character_id = str(row.get("character_id", ""))
		choice = _choice_from_row(row)
	elif parsed is Dictionary:
		character_id = str(parsed.get("character_id", ""))
		choice = _choice_from_row(parsed)

	vote_recorded.emit(character_id, choice)


func _choice_from_row(row: Dictionary) -> String:
	var heaven_count := int(row.get("heaven_count", 0))
	var hell_count := int(row.get("hell_count", 0))
	if hell_count > heaven_count:
		return "hell"
	return "heaven"


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
