extends Node

@export var music_track: AudioStream
@export var fade_time: float = 0.6


func _ready() -> void:
	if music_track == null:
		return

	MusicController.play_track(music_track, fade_time)
