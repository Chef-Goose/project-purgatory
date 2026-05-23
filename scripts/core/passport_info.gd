extends Node2D
class_name PassportInfo

## Reference to the character data to display
var character_data: CharacterData = null

@onready var info_label: Label = $InfoLabel if has_node("InfoLabel") else null

var _blur_material_sprite: ShaderMaterial = null
var _blur_material_label: ShaderMaterial = null
var _last_object_state: int = -1
var _game_object: Node = null
var _object_sprite: Sprite2D = null


func _ready() -> void:
	# This script lives on PassportDisplay, which is nested under the object sprite.
	_object_sprite = get_parent() as Sprite2D
	_game_object = _object_sprite.get_parent() if _object_sprite != null else null
	
	_setup_blur_material()
	_setup_info_label()
	_update_display()


func set_character_data(character: CharacterData) -> void:
	character_data = character
	_update_display()



func _process(_delta: float) -> void:
	# Check if object state has changed (on table vs in hand)
	if _game_object != null and "objectState" in _game_object:
		var current_state = _game_object.objectState
		if current_state != _last_object_state:
			_last_object_state = current_state
			_update_blur_state()


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


func _update_display() -> void:
	if info_label == null or character_data == null:
		if info_label:
			info_label.text = ""
		return
	
	var info_lines: Array[String] = []
	
	# Build the display text from passport_info
	if not character_data.passport_info.is_empty():
		for key in character_data.passport_info.keys():
			var value = character_data.passport_info[key]
			var formatted_key = key.to_pascal_case()
			info_lines.append("%s: %s" % [formatted_key, value])
	else:
		info_lines.append("No information")
	
	info_label.text = "\n".join(info_lines)


func _update_blur_state() -> void:
	if _blur_material_sprite == null or _blur_material_label == null:
		return
	
	if _game_object == null or not "objectState" in _game_object:
		return
	
	# Check if object is in a hand (state 1 = inLeftHand, state 2 = inRightHand)
	var current_state = _game_object.objectState
	var should_unblur = (current_state == 1 or current_state == 2)  # In a hand
	
	# Animate blur transition for both sprite and label
	var target_blur = 0.0 if should_unblur else 5.0
	var transition_duration := 0.3
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_blur_material_sprite, "shader_parameter/blur_amount", target_blur, transition_duration)
	tween.tween_property(_blur_material_label, "shader_parameter/blur_amount", target_blur, transition_duration)
