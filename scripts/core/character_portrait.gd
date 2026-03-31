extends CanvasLayer
class_name CharacterPortrait

enum Mood {
	IDLE,
	TALKING,
	ANGRY,
	SAD,
}

@export var idle_texture: Texture2D
@export var talking_texture: Texture2D
@export var angry_texture: Texture2D
@export var sad_texture: Texture2D
@export var default_mood: Mood = Mood.IDLE

@onready var _sprite: Sprite2D = $Control/Node2D/Sprite2D

func _ready() -> void:
	if not is_in_group("character_portrait"):
		add_to_group("character_portrait")
	_apply_mood(default_mood)

func set_mood(mood: Mood) -> void:
	default_mood = mood
	_apply_mood(mood)

func set_mood_by_name(mood_name: String) -> void:
	match mood_name.to_lower():
		"idle":
			set_mood(Mood.IDLE)
		"talking":
			set_mood(Mood.TALKING)
		"angry":
			set_mood(Mood.ANGRY)
		"sad":
			set_mood(Mood.SAD)
		_:
			set_mood(Mood.IDLE)

func set_texture_set(
	new_idle: Texture2D,
	new_talking: Texture2D = null,
	new_angry: Texture2D = null,
	new_sad: Texture2D = null
) -> void:
	idle_texture = new_idle
	talking_texture = new_talking
	angry_texture = new_angry
	sad_texture = new_sad
	_apply_mood(default_mood)

func _apply_mood(mood: Mood) -> void:
	var texture_to_use: Texture2D = idle_texture
	match mood:
		Mood.IDLE:
			texture_to_use = idle_texture
		Mood.TALKING:
			texture_to_use = talking_texture if talking_texture != null else idle_texture
		Mood.ANGRY:
			texture_to_use = angry_texture if angry_texture != null else idle_texture
		Mood.SAD:
			texture_to_use = sad_texture if sad_texture != null else idle_texture

	_sprite.texture = texture_to_use
