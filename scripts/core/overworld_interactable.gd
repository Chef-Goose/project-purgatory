@tool
extends Sprite2D
class_name OverworldInteractable

enum InteractionType {
	SCENE_SWITCH,
	DIALOGUE,
	ITEM_PICKUP,
}

@export var interaction_type: InteractionType = InteractionType.DIALOGUE
@export_multiline var prompt_text: String = "Interact"

@export_file("*.tscn") var target_scene_path: String = ""
@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "start"

@export var item_id: String = ""
@export var item_display_name: String = ""
@export var consume_on_use: bool = true
@export var queue_free_on_use: bool = true
@export var collision_enabled: bool = true

var has_been_used: bool = false


func _ready() -> void:
	add_to_group("overworld_interactable")
	_update_collision()
	var interaction_area := get_node_or_null("InteractionArea") as Area2D
	if interaction_area != null and interaction_area.has_signal("area_entered"):
		pass


func _update_collision() -> void:
	var collision_body := get_node_or_null("CollisionBody") as StaticBody2D
	if collision_body == null:
		return
	
	# Disable the collision shape within the body
	var collision_shape := collision_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = not collision_enabled


func can_interact() -> bool:
	if consume_on_use and has_been_used:
		return false
	return true


func get_prompt_text() -> String:
	if not prompt_text.strip_edges().is_empty():
		return prompt_text

	match interaction_type:
		InteractionType.SCENE_SWITCH:
			return "Move to next area"
		InteractionType.DIALOGUE:
			return "Read"
		InteractionType.ITEM_PICKUP:
			return "Pick up item"

	return "Interact"


func get_item_label() -> String:
	if not item_display_name.strip_edges().is_empty():
		return item_display_name
	if not item_id.strip_edges().is_empty():
		return item_id
	return "Unknown Item"


func mark_used() -> void:
	has_been_used = true
	if consume_on_use:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
