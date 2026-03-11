extends Node

@export var music_bus_name: StringName = &"Music"
@export var default_fade_time: float = 0.6
@export var minimum_volume_db: float = -60.0

var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _target_volume_db: float = 0.0
var _fade_tween: Tween


func _ready() -> void:
	_active_player = _make_player("MusicA")
	_inactive_player = _make_player("MusicB")


func play_track(stream: AudioStream, fade_time: float = -1.0) -> void:
	if stream == null:
		return

	if _active_player.stream == stream and _active_player.playing:
		return

	var duration := default_fade_time if fade_time < 0.0 else fade_time
	var next_player := _inactive_player
	next_player.stream = stream
	next_player.volume_db = minimum_volume_db
	next_player.play()

	_stop_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(next_player, "volume_db", _target_volume_db, duration)

	if _active_player.playing:
		_fade_tween.tween_property(_active_player, "volume_db", minimum_volume_db, duration)
		_fade_tween.finished.connect(func() -> void:
			if _active_player.playing:
				_active_player.stop()
		)

	_swap_players()


func stop_track(fade_time: float = -1.0) -> void:
	if not _active_player.playing:
		return

	var duration := default_fade_time if fade_time < 0.0 else fade_time
	_stop_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_active_player, "volume_db", minimum_volume_db, duration)
	_fade_tween.finished.connect(func() -> void:
		if _active_player.playing:
			_active_player.stop()
	)


func set_music_volume_db(value: float) -> void:
	_target_volume_db = value
	if _active_player.playing:
		_active_player.volume_db = _target_volume_db


func _make_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	if AudioServer.get_bus_index(music_bus_name) == -1:
		player.bus = &"Master"
	else:
		player.bus = music_bus_name
	player.autoplay = false
	player.volume_db = minimum_volume_db
	add_child(player)
	return player


func _swap_players() -> void:
	var temp := _active_player
	_active_player = _inactive_player
	_inactive_player = temp


func _stop_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
