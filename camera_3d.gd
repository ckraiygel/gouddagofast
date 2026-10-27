extends Camera3D

@export var target_path: NodePath = "../Player"
@export var follow_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 10, 7)

var target: Node3D
var shake_amount: float = 0.0

func _ready() -> void:
	if has_node(target_path):
		target = get_node(target_path)

func apply_shake(strength: float) -> void:
	# Keep highest current shake value
	shake_amount = max(shake_amount, strength)

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	# Desired position relative to player
	var desired_position = target.global_position + offset
	desired_position.x = clamp(desired_position.x, -2.5, 2.5)
	desired_position.z = clamp(desired_position.z, 4.5, 9.5)

	# Calculate translational and rotational shake offsets
	var shake_offset = Vector3.ZERO
	var rot_offset = Vector3.ZERO

	if shake_amount > 0.0:
		shake_offset = Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		# Toned down rotational tilt
		rot_offset = Vector3(
			randf_range(-shake_amount, shake_amount) * 0.8,
			0.0,
			randf_range(-shake_amount, shake_amount) * 0.8
		)
		# Faster decay so the camera snaps back immediately
		shake_amount = move_toward(shake_amount, 0.0, delta * 5.0)

	# Smooth camera follow
	global_position = global_position.lerp(desired_position + shake_offset, follow_speed * delta)
	look_at(Vector3(target.global_position.x * 0.3, 0.0, target.global_position.z * 0.3))
	
	# Apply rotational tilt on top of base orientation
	rotation_degrees += rot_offset
