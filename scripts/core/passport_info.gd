extends Node2D
class_name PassportInfo

## Reference to the character data to display
var character_data: CharacterData = null

@onready var info_label: RichTextLabel = $InfoLabel if has_node("InfoLabel") else null

var _blur_material_sprite: ShaderMaterial = null
var _blur_material_label: ShaderMaterial = null
var _last_object_state: int = -1
var _game_object: Node = null
var _object_sprite: Sprite2D = null
var _doc_scale_base: Vector2 = Vector2.ONE
var _scale_tween: Tween = null


func _ready() -> void:
	# This script lives on PassportDisplay, which is nested under the object sprite.
	_object_sprite = get_parent() as Sprite2D
	_game_object = _object_sprite.get_parent() if _object_sprite != null else null
	_doc_scale_base = (info_label.scale * 3.5) if info_label != null else Vector2.ONE
	
	_setup_blur_material()
	_setup_info_label()
	_sync_info_label_scale()
	_update_display()


func set_character_data(character: CharacterData) -> void:
	character_data = character
	_update_display()



func _process(_delta: float) -> void:
	# Check if object state has changed (on table vs in hand)
	if _game_object != null and "objectState" in _game_object:
		var current_state = _game_object.objectState
		if current_state != _last_object_state:
			_update_scale_state(current_state)
			_last_object_state = current_state
			_update_blur_state()

	_sync_info_label_scale()


func _setup_blur_material() -> void:
	if _object_sprite == null:
		push_warning("PassportInfo: object_sprite not found")
		return
	
	var shader = load("res://shaders/passport_blur.gdshader")
	if shader == null:
		push_error("PassportInfo: Failed to load blur shader")
		return
	
	# Create material for sprite
	_blur_material_sprite = ShaderMaterial.new()
	_blur_material_sprite.shader = shader
	_blur_material_sprite.set_shader_parameter("blur_amount", 0.0)
	_object_sprite.set_material(_blur_material_sprite)
	
	# Create separate material for label
	if info_label != null:
		_blur_material_label = ShaderMaterial.new()
		_blur_material_label.shader = shader
		_blur_material_label.set_shader_parameter("blur_amount", 0.0)
		info_label.set_material(_blur_material_label)


func _setup_info_label() -> void:
	if info_label == null:
		push_error("PassportInfo: InfoLabel not found in scene")
		return

	info_label.bbcode_enabled = true
	info_label.scroll_active = false
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_font_size_override("normal_font_size", 8)


func _update_display() -> void:
	if info_label == null or character_data == null:
		if info_label:
			info_label.text = ""
		return

	info_label.text = _build_dossier_text()


func _update_blur_state() -> void:
	if _blur_material_sprite == null or _blur_material_label == null:
		return
	
	if _game_object == null or not "objectState" in _game_object:
		return
	
	# Check if object is in a hand.
	var current_state = _game_object.objectState
	var should_unblur = _is_in_hand_state(current_state)  # In a hand
	
	# Animate blur transition for both sprite and label
	var target_blur = 0.0 if should_unblur else 5.0
	var transition_duration := 0.3
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_blur_material_sprite, "shader_parameter/blur_amount", target_blur, transition_duration)
	tween.tween_property(_blur_material_label, "shader_parameter/blur_amount", target_blur, transition_duration)


func _update_scale_state(current_state: int) -> void:
	var target_scale := Vector2.ONE * 4.0 if _is_in_hand_state(current_state) else Vector2.ONE

	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_SINE)
	_scale_tween.set_ease(Tween.EASE_OUT)
	if _object_sprite != null:
		_scale_tween.tween_property(_object_sprite, "scale", target_scale, 0.3)


func _sync_info_label_scale() -> void:
	if info_label == null or _object_sprite == null:
		return

	var sprite_scale := _object_sprite.scale
	if is_zero_approx(sprite_scale.x) or is_zero_approx(sprite_scale.y):
		return

	var normalized_scale := Vector2(
		_doc_scale_base.x / sprite_scale.x,
		_doc_scale_base.y / sprite_scale.y
	)
	info_label.scale = normalized_scale


func _build_dossier_text() -> String:
	var lines: Array[String] = []
	lines.append("[center][b]PERSONAL DOSSIER[/b][/center]")
	lines.append("")
	lines.append(_build_field_block("NAME", _safe_text(character_data.character_name, "Unknown")))
	lines.append("")
	lines.append(_build_field_block("AGE", _safe_text(character_data.passport_info.get("age", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_field_block("OCCUPATION", _safe_text(character_data.passport_info.get("occupation", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_field_block("CAUSE OF DEATH", _safe_text(character_data.passport_info.get("cause_of_death", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_list_block("THE GOOD", _as_string_array(character_data.passport_info.get("good_points", [])), "No good points recorded."))
	lines.append("")
	lines.append(_build_list_block("THE BAD", _as_string_array(character_data.passport_info.get("bad_points", [])), "No bad points recorded."))
	return "\n".join(lines)


func _build_field_block(title: String, value: String) -> String:
	return "[b]%s[/b]\n%s" % [title, value]


func _build_list_block(title: String, entries: Array[String], empty_text: String) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % title)
	if entries.is_empty():
		lines.append("- %s" % empty_text)
	else:
		for entry in entries:
			var cleaned_entry := _safe_text(entry, "")
			if cleaned_entry.is_empty():
				continue
			lines.append("- %s" % cleaned_entry)
	return "\n".join(lines)


func _safe_text(value: Variant, fallback: String) -> String:
	var text := str(value).strip_edges()
	if text.is_empty() or text == "null":
		return fallback
	return text


func _as_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := _safe_text(item, "")
			if not text.is_empty():
				result.append(text)
	return result


func _is_in_hand_state(state_value: int) -> bool:
	return state_value == 1 or state_value == 2 or state_value == 3
