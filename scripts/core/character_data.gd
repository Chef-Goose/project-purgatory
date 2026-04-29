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
