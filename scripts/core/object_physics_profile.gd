extends Resource
class_name ObjectPhysicsProfile

@export_range(0.0, 1.0, 0.01) var friction: float = 0.5
@export_range(0.0, 2.0, 0.05) var bounce: float = 0.7
@export_range(0.1, 5.0, 0.1) var weight: float = 1.0
# Higher ballistic coefficient means less speed loss to air drag.
@export_range(0.02, 1.5, 0.01) var ballistic_coefficient: float = 0.75
