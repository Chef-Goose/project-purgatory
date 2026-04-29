extends Resource
class_name CharacterData

## Core identity
@export var character_name: String = "Unknown"
@export var character_id: String = "unknown"  # Unique identifier for dialogue/state tracking

## Visual presentation
@export var portrait_set: CharacterPortraitSet = null  # Mood-based portraits
@export var description: String = ""  # Brief description for fate decisions

## Passport/dossier info (what the player sees)
@export var passport_info: Dictionary = {}  # e.g., {"date_of_birth": "...", "occupation": "..."}

## Dialogue setup
@export var dialogue_resource: DialogueResource = null  # Path to character's dialogue file
@export var dialogue_resource_path: String = ""  # Optional res:// path used if dialogue_resource is not assigned
@export var default_dialogue_slot: String = "start"
@export var dialogue_entries: Array[CharacterDialogueEntry] = []
@export var intro_dialogue_title: String = "start"  # Where to begin in dialogue tree
@export var follow_up_dialogue_title: String = "follow_up"  # After player asks questions

## Morality & fate
## Morality weight: -1 (evil), 0 (neutral), 1 (good). Helps weight player decisions.
@export var morality_weight: float = 0.0
@export var can_lie: bool = true  # All purgatory characters can lie
@export var lie_flags: Array[String] = []  # Which statements are lies (e.g., ["occupation", "age"])

## State tracking
var has_been_spoken_to: bool = false
var fate_assigned: String = ""  # "heaven", "hell", or ""

## Audio (optional)
@export var voice_pitch_shift: float = 1.0


func _init(p_name: String = "", p_id: String = "") -> void:
	character_name = p_name
	character_id = p_id


func get_dialogue_entry(slot_name: String = "") -> CharacterDialogueEntry:
	var resolved_slot := slot_name.strip_edges()
	if resolved_slot.is_empty():
		resolved_slot = default_dialogue_slot.strip_edges()

	for entry: CharacterDialogueEntry in dialogue_entries:
		if entry == null:
			continue

		if entry.dialogue_slot.strip_edges() == resolved_slot:
			return entry

	return null


func set_dialogue_entry(entry: CharacterDialogueEntry) -> void:
	if entry == null:
		return

	var resolved_slot := entry.dialogue_slot.strip_edges()
	if resolved_slot.is_empty():
		resolved_slot = default_dialogue_slot.strip_edges()
		if resolved_slot.is_empty():
			resolved_slot = "start"
		entry.dialogue_slot = resolved_slot

	if entry.start_from_title.strip_edges().is_empty():
		entry.start_from_title = resolved_slot

	for i in range(dialogue_entries.size()):
		var existing_entry: CharacterDialogueEntry = dialogue_entries[i]
		if existing_entry != null and existing_entry.dialogue_slot.strip_edges() == resolved_slot:
			dialogue_entries[i] = entry
			return

	dialogue_entries.append(entry)


func set_dialogue_slot(slot_name: String, resource_path: String = "", resource: DialogueResource = null, start_title: String = "") -> CharacterDialogueEntry:
	var entry := CharacterDialogueEntry.new()
	entry.dialogue_slot = slot_name
	entry.dialogue_resource_path = resource_path
	entry.dialogue_resource = resource
	entry.start_from_title = start_title
	set_dialogue_entry(entry)
	return entry


func set_dialogue_slot_path(slot_name: String, resource_path: String, start_title: String = "") -> CharacterDialogueEntry:
	return set_dialogue_slot(slot_name, resource_path, null, start_title)


func set_dialogue_slot_resource(slot_name: String, resource: DialogueResource, start_title: String = "") -> CharacterDialogueEntry:
	return set_dialogue_slot(slot_name, "", resource, start_title)


func get_dialogue_resource_for_slot(slot_name: String = "") -> DialogueResource:
	var entry := get_dialogue_entry(slot_name)
	if entry != null:
		var resolved_resource := entry.resolve_dialogue_resource()
		if resolved_resource != null:
			return resolved_resource

	if dialogue_resource != null:
		return dialogue_resource

	if not dialogue_resource_path.is_empty() and ResourceLoader.exists(dialogue_resource_path):
		return load(dialogue_resource_path) as DialogueResource

	return null


func get_dialogue_title_for_slot(slot_name: String = "") -> String:
	var entry := get_dialogue_entry(slot_name)
	if entry != null and not entry.start_from_title.is_empty():
		return entry.start_from_title

	if not intro_dialogue_title.is_empty():
		return intro_dialogue_title

	return default_dialogue_slot
