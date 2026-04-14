extends Node2D

var _master_z_index: int = 10
var _left_hand_empty: bool = true
var _right_hand_empty: bool = true
const HAND_LEFT: StringName = &"left"
const HAND_RIGHT: StringName = &"right"


func next_object_z_index() -> int:
	_master_z_index += 1
	return _master_z_index


func is_hand_available(slot: StringName, currently_holding: bool = false) -> bool:
	match slot:
		HAND_RIGHT:
			return _right_hand_empty or currently_holding
		HAND_LEFT:
			return _left_hand_empty or currently_holding
		_:
			push_warning("ObjectHandler: Unknown hand slot '%s' in is_hand_available." % String(slot))
			return false


func claim_hand(slot: StringName) -> void:
	match slot:
		HAND_RIGHT:
			_right_hand_empty = false
		HAND_LEFT:
			_left_hand_empty = false
		_:
			push_warning("ObjectHandler: Unknown hand slot '%s' in claim_hand." % String(slot))


func release_hand(slot: StringName) -> void:
	match slot:
		HAND_RIGHT:
			_right_hand_empty = true
		HAND_LEFT:
			_left_hand_empty = true
		_:
			push_warning("ObjectHandler: Unknown hand slot '%s' in release_hand." % String(slot))
