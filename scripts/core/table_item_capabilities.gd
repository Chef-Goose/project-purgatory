extends Resource
class_name TableItemCapabilities

@export var can_drag: bool = true
@export var can_be_placed_in_hands: bool = true
@export var can_slide_on_table: bool = true
@export var can_bounce_objects: bool = true
@export var can_receive_object_bounce: bool = true
@export var use_paper_test_random_texture: bool = false
@export_range(0.1, 2.0, 0.01) var shadow_alpha_scale: float = 1.0
@export_range(0.1, 2.0, 0.01) var shadow_depth_scale: float = 1.0
