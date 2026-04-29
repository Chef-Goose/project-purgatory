extends CanvasLayer

@export var camera_path: NodePath
@export var button_text: String = "Return"
@export var show_only_when_snapped: bool = true

var _camera: TableCameraController
@onready var _button: Button = $ReturnButton


func _ready() -> void:
	_button.text = button_text
	_button.pressed.connect(_on_return_pressed)
	_camera = _resolve_camera()
	_update_visibility()


func _process(_delta: float) -> void:
	if show_only_when_snapped:
		_update_visibility()


func _on_return_pressed() -> void:
	if _camera.is_interaction_locked():
		return

	_camera.clear_hover_zones()
	_camera.clear_snap()
	_update_visibility()


func _update_visibility() -> void:
	if not show_only_when_snapped:
		visible = true
		return

	visible = _camera.is_snap_active() and not _camera.is_interaction_locked()


func _resolve_camera() -> TableCameraController:
	if camera_path == NodePath():
		push_error("CameraReturnButton requires camera_path to be assigned.")
		return null

	_camera = get_node(camera_path) as TableCameraController

	return _camera
