extends Button

@export var hover_sound: AudioStream = preload("res://assets/audio/effects/menu/Menu Up-Down.wav")
@export var pressed_sound: AudioStream = preload("res://assets/audio/effects/menu/Menu Select Sound.wav")

@onready var _audio_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	_play_sound(hover_sound)


func _on_pressed() -> void:
	_play_sound(pressed_sound)


func _play_sound(sound: AudioStream) -> void:
	if sound == null:
		return

	_audio_player.stream = sound
	_audio_player.play()
