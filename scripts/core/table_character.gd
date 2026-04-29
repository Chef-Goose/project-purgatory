extends Node2D
class_name TableCharacter

@export var sprite_path: NodePath = NodePath("Sprite2D")
@export var fallback_texture: Texture2D

@onready var character_sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D

var current_character: CharacterData


func set_character_data(character_data: CharacterData) -> void:
	current_character = character_data
	if character_sprite == null:
		return

	var texture_to_use: Texture2D = fallback_texture
	if current_character != null and current_character.portrait_set != null and current_character.portrait_set.idle_texture != null:
		texture_to_use = current_character.portrait_set.idle_texture

	character_sprite.texture = texture_to_use
