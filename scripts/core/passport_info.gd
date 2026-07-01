extends Node2D
class_name PassportInfo

signal dossier_question_selected(question_slot: String)

const TITLE_TOP_OFFSET := 14.0
const TITLE_BOX_HEIGHT := 34.0
const TITLE_BOX_WIDTH_RATIO := 0.78
const BODY_LEFT_INSET := 28.0
const BODY_TOP_OFFSET := 34.0
const BODY_RIGHT_INSET := 28.0
const BODY_BOTTOM_INSET := 30.0

@export_category("Dossier Title")
@export var title_font_size: int = 18
@export var title_horizontal_offset: float = -18.0

@export_category("Dossier Body")
@export var body_font_size: int = 14

## Reference to the character data to display
var character_data: CharacterData = null

@onready var dossier_page: Control = get_node_or_null("InfoLayer/DossierPage") as Control
@onready var title_container: Control = get_node_or_null("InfoLayer/DossierPage/TitleContainer") as Control
@onready var body_container: Control = get_node_or_null("InfoLayer/DossierPage/BodyContainer") as Control
@onready var title_label: RichTextLabel = get_node_or_null("InfoLayer/DossierPage/TitleContainer/TitleLabel") as RichTextLabel
@onready var body_label: RichTextLabel = get_node_or_null("InfoLayer/DossierPage/BodyContainer/BodyLabel") as RichTextLabel

var _last_object_state: int = -1
var _game_object: Node = null
var _object_sprite: Sprite2D = null
var _scale_tween: Tween = null
var _label_fade_tween: Tween = null


func _ready() -> void:
	# This script lives on PassportDisplay, which is nested under the object sprite.
	_object_sprite = get_parent() as Sprite2D
	_game_object = _object_sprite.get_parent() if _object_sprite != null else null
	
	_setup_info_labels()
	_sync_label_layout()
	_update_label_visibility(false)
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
			_update_label_visibility(_is_in_hand_state(current_state))
			_last_object_state = current_state

	_sync_label_layout()

func _setup_info_labels() -> void:
	if dossier_page == null or title_container == null or body_container == null or title_label == null or body_label == null:
		push_error("PassportInfo: dossier page/container labels not found in scene")
		return

	dossier_page.clip_contents = true
	dossier_page.z_as_relative = false
	dossier_page.z_index = 10

	for container in [title_container, body_container]:
		container.clip_contents = false
		container.z_as_relative = false
		container.z_index = 11

	for label in [title_label, body_label]:
		label.scroll_active = false
		label.z_as_relative = false
		label.z_index = 12
		label.modulate = Color.BLACK
		label.self_modulate = Color.BLACK

	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	body_label.mouse_default_cursor_shape = Control.CURSOR_ARROW

	title_label.bbcode_enabled = true
	title_label.horizontal_alignment = 1 as HorizontalAlignment
	title_label.vertical_alignment = 0 as VerticalAlignment
	title_label.add_theme_color_override("default_color", Color.BLACK)

	body_label.bbcode_enabled = true
	body_label.horizontal_alignment = 0 as HorizontalAlignment
	body_label.vertical_alignment = 0 as VerticalAlignment
	body_label.add_theme_font_size_override("normal_font_size", body_font_size)
	body_label.add_theme_color_override("default_color", Color.BLACK)
	if body_label.has_signal("meta_clicked"):
		body_label.meta_clicked.connect(_on_body_meta_clicked)
	if body_label.has_signal("meta_hover_started"):
		body_label.meta_hover_started.connect(_on_body_meta_hover_started)
	if body_label.has_signal("meta_hover_ended"):
		body_label.meta_hover_ended.connect(_on_body_meta_hover_ended)


func _update_display() -> void:
	if title_label == null or body_label == null or character_data == null:
		if title_label:
			title_label.text = ""
		if body_label:
			body_label.text = ""
		return

	title_label.text = _build_title_text()
	body_label.text = _build_body_text()


func _update_scale_state(current_state: int) -> void:
	var target_scale := Vector2.ONE * 4.0 if _is_in_hand_state(current_state) else Vector2.ONE

	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_SINE)
	_scale_tween.set_ease(Tween.EASE_OUT)
	if _object_sprite != null:
		_scale_tween.tween_property(_object_sprite, "scale", target_scale, 0.3)


func _sync_label_layout() -> void:
	if dossier_page == null or title_container == null or body_container == null or title_label == null or body_label == null or _object_sprite == null or _object_sprite.texture == null:
		return

	var sprite_scale := _object_sprite.global_transform.get_scale()
	var sprite_size := _object_sprite.texture.get_size() * sprite_scale.abs()
	var sprite_rect_top_left := -(_object_sprite.texture.get_size() * 0.5)
	var canvas_transform := _object_sprite.get_global_transform_with_canvas()
	var canvas_top_left := canvas_transform * sprite_rect_top_left
	dossier_page.position = canvas_top_left
	dossier_page.custom_minimum_size = sprite_size
	dossier_page.size = sprite_size

	var title_width := maxf(sprite_size.x * TITLE_BOX_WIDTH_RATIO, 1.0)
	var title_top := TITLE_TOP_OFFSET * sprite_scale.y
	title_container.anchor_left = 0.0
	title_container.anchor_top = 0.0
	title_container.anchor_right = 0.0
	title_container.anchor_bottom = 0.0
	title_container.offset_left = 0.0
	title_container.offset_top = title_top
	title_container.offset_right = sprite_size.x
	title_container.offset_bottom = title_top + (TITLE_BOX_HEIGHT * sprite_scale.y)
	title_container.custom_minimum_size = Vector2(title_width, TITLE_BOX_HEIGHT * sprite_scale.y)
	title_container.size = title_container.custom_minimum_size
	title_label.position = Vector2(title_horizontal_offset * sprite_scale.x, 0.0)
	title_label.custom_minimum_size = title_container.size
	title_label.size = title_label.custom_minimum_size
	title_label.scale = Vector2.ONE

	body_container.position = Vector2(BODY_LEFT_INSET * sprite_scale.x, BODY_TOP_OFFSET * sprite_scale.y)
	body_container.custom_minimum_size = Vector2(maxf(sprite_size.x - ((BODY_LEFT_INSET + BODY_RIGHT_INSET) * sprite_scale.x), 1.0), maxf(sprite_size.y - (BODY_TOP_OFFSET * sprite_scale.y) - (BODY_BOTTOM_INSET * sprite_scale.y), 1.0))
	body_container.size = body_container.custom_minimum_size
	body_label.position = Vector2.ZERO
	body_label.custom_minimum_size = body_container.size
	body_label.size = body_label.custom_minimum_size
	body_label.scale = Vector2.ONE


func _update_label_visibility(should_show: bool) -> void:
	if title_label == null or body_label == null:
		return

	if _label_fade_tween != null and _label_fade_tween.is_valid():
		_label_fade_tween.kill()

	_label_fade_tween = create_tween()
	_label_fade_tween.set_trans(Tween.TRANS_SINE)
	_label_fade_tween.set_ease(Tween.EASE_OUT)
	var target_alpha := 1.0 if should_show else 0.0
	_label_fade_tween.parallel().tween_property(title_label, "modulate:a", target_alpha, 0.25)
	_label_fade_tween.parallel().tween_property(title_label, "self_modulate:a", target_alpha, 0.25)
	_label_fade_tween.parallel().tween_property(body_label, "modulate:a", target_alpha, 0.25)
	_label_fade_tween.parallel().tween_property(body_label, "self_modulate:a", target_alpha, 0.25)


func _build_body_text() -> String:
	var lines: Array[String] = []
	lines.append(_build_field_block("NAME", _safe_text(character_data.character_name, "Unknown")))
	lines.append("")
	lines.append(_build_field_block("AGE", _safe_text(character_data.passport_info.get("age", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_field_block("OCCUPATION", _safe_text(character_data.passport_info.get("occupation", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_field_block("CAUSE OF DEATH", _safe_text(character_data.passport_info.get("cause_of_death", "Unknown"), "Unknown")))
	lines.append("")
	lines.append(_build_question_section("THE GOOD", _as_string_array(character_data.passport_info.get("good_points", [])), "good", "wave", "#2f9d58", "No good points recorded."))
	lines.append("")
	lines.append(_build_question_section("THE BAD", _as_string_array(character_data.passport_info.get("bad_points", [])), "bad", "shake", "#b83b3b", "No bad points recorded."))
	return "[font_size=%d]%s[/font_size]" % [body_font_size, "\n".join(lines)]


func _build_title_text() -> String:
	return "[center][font_size=%d][b]PERSONAL DOSSIER[/b][/font_size][/center]" % title_font_size


func _build_field_block(title: String, value: String) -> String:
	return "[b]%s[/b]\n%s" % [title, value]


func _build_question_section(title: String, entries: Array[String], question_prefix: String, effect_name: String, color_hex: String, empty_text: String) -> String:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % title)
	if entries.is_empty():
		lines.append("- %s" % empty_text)
	else:
		for entry_index in range(entries.size()):
			var entry := entries[entry_index]
			var cleaned_entry := _safe_text(entry, "")
			if cleaned_entry.is_empty():
				continue
			lines.append(_build_question_entry(question_prefix, entry_index, cleaned_entry, effect_name, color_hex))
	return "\n".join(lines)


func _build_question_entry(question_prefix: String, entry_index: int, entry_text: String, effect_name: String, color_hex: String) -> String:
	var question_slot := "%s_%d" % [question_prefix, entry_index]
	var font_size := body_font_size + 2
	var effect_tag := effect_name
	if effect_name == "wave":
		effect_tag = "wave amp=18 freq=3"
	elif effect_name == "shake":
		effect_tag = "shake rate=20 level=6"

	return "[url=%s][color=%s][font_size=%d][%s]- %s[/%s][/font_size][/color][/url]" % [question_slot, color_hex, font_size, effect_tag, entry_text, effect_name]


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


func _on_body_meta_clicked(meta: Variant) -> void:
	var question_slot := str(meta).strip_edges()
	if question_slot.is_empty():
		return
	dossier_question_selected.emit(question_slot)


func _on_body_meta_hover_started(_meta: Variant) -> void:
	body_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_body_meta_hover_ended(_meta: Variant) -> void:
	body_label.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _is_in_hand_state(state_value: int) -> bool:
	return state_value == 1 or state_value == 2 or state_value == 3
