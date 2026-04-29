extends Resource
class_name CharacterDialogueEntry

@export var dialogue_slot: String = "start"
@export var dialogue_resource: DialogueResource = null
@export var dialogue_resource_path: String = ""
@export var start_from_title: String = "start"


func resolve_dialogue_resource() -> DialogueResource:
	if dialogue_resource != null:
		return dialogue_resource

	if not dialogue_resource_path.is_empty() and ResourceLoader.exists(dialogue_resource_path):
		return load(dialogue_resource_path) as DialogueResource

	return null