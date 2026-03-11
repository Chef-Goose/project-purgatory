extends Node

@export var cue_tracks: Dictionary = {}
@export var default_fade_time: float = 0.6
@export var stop_fade_time: float = 0.4
@export var resume_cue_on_dialogue_end: String = ""


func _ready() -> void:
	var dm := get_node_or_null("/root/DialogueManager")
	if dm == null:
		push_warning("DialogueMusicBridge: DialogueManager autoload not found.")
		return

	if not dm.got_dialogue.is_connected(_on_got_dialogue):
		dm.got_dialogue.connect(_on_got_dialogue)

	if not dm.dialogue_ended.is_connected(_on_dialogue_ended):
		dm.dialogue_ended.connect(_on_dialogue_ended)


func _on_got_dialogue(line: DialogueLine) -> void:
	if line == null or not line.has_tag("music"):
		return

	var cue := line.get_tag_value("music").strip_edges().to_lower()
	if cue == "":
		return

	if cue == "stop":
		MusicController.stop_track(stop_fade_time)
		return

	var stream := cue_tracks.get(cue) as AudioStream
	if stream == null:
		push_warning("DialogueMusicBridge: No track assigned for cue '%s'." % cue)
		return

	MusicController.play_track(stream, default_fade_time)


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if resume_cue_on_dialogue_end == "":
		return

	var cue := resume_cue_on_dialogue_end.strip_edges().to_lower()
	var stream := cue_tracks.get(cue) as AudioStream
	if stream == null:
		return

	MusicController.play_track(stream, default_fade_time)


func set_cue_track(cue: String, stream: AudioStream) -> void:
	cue_tracks[cue.strip_edges().to_lower()] = stream
