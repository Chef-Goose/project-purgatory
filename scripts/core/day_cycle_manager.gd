extends Node
class_name DayCycleManager

signal fate_assigned(character: CharacterData, fate: String)
signal current_character_changed(character: CharacterData)

## Game state
var current_day: int = 1
var characters_for_today: Array[CharacterData] = []
var characters_fated_today: Dictionary = {}  # character_id -> "heaven" or "hell"
var current_character_index: int = 0
var game_started: bool = false

## Persistent inventory across scenes
var player_inventory: Dictionary = {}  # item_id -> display_name

## Scene references
@export var intro_scene_path: String = "res://scenes/levels/intro.tscn"
@export var table_scene_path: String = "res://scenes/levels/table.tscn"
@export var overworld_scene_path: String = "res://scenes/levels/overworld.tscn"
@export var summary_scene_path: String = "res://scenes/levels/day_summary.tscn"
@export var lunch_scene_path: String = "res://scenes/levels/lunch_break.tscn"

## Character pool (add characters for different days)
var all_available_characters: Array[CharacterData] = []


func _ready() -> void:
	# Initialize but don't start the game automatically
	# Call _start_game() manually or from a UI button when ready
	pass


func _start_game() -> void:
	game_started = true
	# For now, load the intro scene
	if ResourceLoader.exists(intro_scene_path):
		get_tree().change_scene_to_file(intro_scene_path)
	else:
		push_error("DayCycleManager: Intro scene not found at ", intro_scene_path)


## Called when intro dialogue is complete
func intro_complete() -> void:
	_load_day()


## Prepare today's characters without changing scenes.
func prepare_day() -> void:
	characters_for_today.clear()
	characters_fated_today.clear()
	current_character_index = 0

	# TODO: Implement day-specific character loading logic
	# For now, use placeholder characters
	if all_available_characters.is_empty():
		_create_placeholder_characters()

	# Randomly pick 3-5 characters for today
	var num_characters = randi_range(3, 5)
	var shuffled = all_available_characters.duplicate()
	shuffled.shuffle()
	for i in range(mini(num_characters, shuffled.size())):
		characters_for_today.append(shuffled[i])


## Load today's characters and transition to work
func _load_day() -> void:
	prepare_day()
	
	_load_table_scene()


## Transition to the table with the first character
func _load_table_scene() -> void:
	get_tree().change_scene_to_file(table_scene_path)


## Called when a character's conversation is complete
func on_character_conversation_complete(character: CharacterData) -> void:
	character.has_been_spoken_to = true
	
	# If we've talked to all characters for today, go to summary
	if _all_characters_processed():
		_transition_to_summary()
	else:
		# Move to next character
		current_character_index += 1
		current_character_changed.emit(get_current_character())


## Called by the fate decision UI
func assign_fate(character: CharacterData, fate: String) -> void:
	if fate in ["heaven", "hell"]:
		character.fate_assigned = fate
		characters_fated_today[character.character_id] = fate
		var leaderboard := get_node_or_null("/root/Leaderboard") as SupabaseLeaderboard
		if leaderboard:
			leaderboard.record_vote(character.character_id, fate)
		else:
			push_warning("DayCycleManager: Leaderboard autoload not found; vote was not recorded.")
		fate_assigned.emit(character, fate)


## Check if all characters have been spoken to
func _all_characters_processed() -> bool:
	for character in characters_for_today:
		if not character.has_been_spoken_to:
			return false
	return true


## Inventory management
func add_item_to_inventory(item_id: String, item_label: String) -> void:
	player_inventory[item_id] = item_label


func has_item(item_id: String) -> bool:
	return item_id in player_inventory


func get_item_label(item_id: String) -> String:
	return player_inventory.get(item_id, "")


func get_all_items() -> Dictionary:
	return player_inventory.duplicate()


## Transition to end-of-day summary
func _transition_to_summary() -> void:
	get_tree().change_scene_to_file(summary_scene_path)


## Called from summary screen to go to overworld
func go_to_overworld() -> void:
	get_tree().change_scene_to_file(overworld_scene_path)


## Called from overworld when player is ready for next day
func go_to_lunch_break() -> void:
	get_tree().change_scene_to_file(lunch_scene_path)


## Called from lunch break to start next day
func next_day() -> void:
	current_day += 1
	_load_day()


## Get the current character being worked on
func get_current_character() -> CharacterData:
	if current_character_index < characters_for_today.size():
		return characters_for_today[current_character_index]
	return null


## Pick which dialogue slot to use for this character right now.
func get_dialogue_slot_for_character(character: CharacterData) -> String:
	if character == null:
		return ""

	if character.has_been_spoken_to:
		if not character.follow_up_dialogue_title.is_empty():
			return character.follow_up_dialogue_title
		return "follow_up"

	if not character.intro_dialogue_title.is_empty():
		return character.intro_dialogue_title

	return character.default_dialogue_slot


## Placeholder character setup (replace with real data)
func _create_placeholder_characters() -> void:
	var sample_portrait_set := CharacterPortraitSet.new()
	sample_portrait_set.speaker_name = "Sample Sam"
	sample_portrait_set.speaker_aliases = ["Sample"]
	sample_portrait_set.idle_texture = preload("res://assets/art/characters/SampleSam/samplesamidle.png")
	sample_portrait_set.talking_texture = preload("res://assets/art/characters/SampleSam/samplesamtalking.png")
	sample_portrait_set.angry_texture = preload("res://assets/art/characters/SampleSam/samplesamangry.png")
	sample_portrait_set.sad_texture = preload("res://assets/art/characters/SampleSam/samplesamsad.png")

	var char1 = CharacterData.new("Wigger Wayne", "wayne")
	char1.description = "A spreadsheet enthusiast with questionable moral priorities."
	char1.morality_weight = -0.3
	char1.passport_info = {
		"occupation": "Pimp",
		"age": "45",
		"cause_of_death": "Domestic dispute in which he killed his wife, pounded 50 monsters after and died of heart attack.",
		"good_points": ["Nice to watch UFC with"],
		"bad_points": ["Abuses women when caffinated"]
	}
	char1.portrait_set = sample_portrait_set
	char1.default_dialogue_slot = "start"
	char1.dialogue_resource_path = "res://scripts/dialogue/wayne_intro.dialogue"
	
	var char2 = CharacterData.new("Pepsi Man", "pepsi_man")
	char2.description = "FUELED."
	char2.morality_weight = 0.8
	char2.passport_info = {
		"occupation": "RUNNER/DELIVERER",
		"age": "62",
		"cause_of_death": "Ran out of road before he ran out of energy.",
		"good_points": ["Never misses a deadline", "Motivated", "Knows every shortcut"],
		"bad_points": ["Does not take no for answer", 'Promotes sugary drink as "cool" to kids', "Runs through and injures pedestrians with no care"]
	}
	char2.portrait_set = sample_portrait_set
	char2.default_dialogue_slot = "start"
	char2.dialogue_resource_path = "res://scripts/dialogue/pepsi_man_intro.dialogue"
	
	var char3 = CharacterData.new("Derrick", "derrick")
	char3.description = "Social media personality with unclear ethics."
	char3.morality_weight = -0.1
	char3.passport_info = {
		"occupation": "Karaoke Bar Worker",
		"age": "28",
		"cause_of_death": "Broke carotid artery by singing A Whole New World loudly.",
		"good_points": ["Whimsy", "Doesn't care what others think"],
		"bad_points": ["Takes the stage so often they ignore others", "Destroys too much soju"]
	}
	char3.portrait_set = sample_portrait_set
	char3.default_dialogue_slot = "start"
	char3.dialogue_resource_path = "res://scripts/dialogue/derrick_intro.dialogue"
	
	all_available_characters = [char1, char2, char3]


## Debug: Print current state
func debug_print_state() -> void:
	print("Day: ", current_day)
	print("Characters today: ", characters_for_today.size())
	print("Current character: ", get_current_character().character_name if get_current_character() else "None")
	print("Fated today: ", characters_fated_today)
