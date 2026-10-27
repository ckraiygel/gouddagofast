extends CharacterBody3D

@export var SPIN_SPEED: float = 7.0 # Auto-rotation speed while idling
@export var DRIVE_SPEED: float = 9.5
@export var JUMP_VELOCITY: float = 6.0
@export var GRAVITY: float = 18.0
@export var TABLE_BOUND: float = 4.3 # Max distance from center before edge containment

var movement_trail: GPUParticles3D

var is_alive: bool = true

# Status Modifiers
var speed_modifier: float = 1.0
var jump_modifier: float = 1.0
var is_shielded: bool = false
var is_invincible: bool = false
var is_inverted: bool = false
var is_slippery: bool = false

# Visual 3D Shield Bubble
var shield_visual: MeshInstance3D

func _ready() -> void:
	add_to_group("player")
	_setup_shield_visual()
	_setup_dynamic_trail()

func _setup_shield_visual() -> void:
	shield_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	shield_visual.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.6, 1.0, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.8
	shield_visual.material_override = mat
	shield_visual.visible = false
	add_child(shield_visual)

func _setup_dynamic_trail() -> void:
	movement_trail = GPUParticles3D.new()
	movement_trail.name = "MovementTrail"
	add_child(movement_trail)

	movement_trail.position.y = 0.05
	movement_trail.amount = 20
	movement_trail.lifetime = 0.25
	movement_trail.local_coords = false # Leaves dust behind in world space
	movement_trail.emitting = false

	# Fluffy dust process material matching the cat paw slide
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 40.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0, -0.6, 0)
	mat.scale_min = 0.12
	mat.scale_max = 0.3

	movement_trail.process_material = mat

	# Dusty gray-beige quad mesh with billboard mode to prevent angle clipping
	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	
	var mat_3d = StandardMaterial3D.new()
	mat_3d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_3d.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_3d.albedo_color = Color(0.85, 0.82, 0.78, 0.75)
	quad.material = mat_3d

	movement_trail.draw_pass_1 = quad

func reset_player(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	velocity = Vector3.ZERO
	is_alive = true
	visible = true
	speed_modifier = 1.0
	jump_modifier = 1.0
	is_shielded = false
	is_invincible = false
	is_inverted = false
	is_slippery = false
	if shield_visual:
		shield_visual.visible = false

func _physics_process(delta: float) -> void:
	if not is_alive:
		if movement_trail:
			movement_trail.emitting = false
		return

	# 1. Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# 2. Jump
	var jump_pressed = Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("ui_accept")
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY * jump_modifier

	# 3. Drive Input
	var is_driving = Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if not is_driving:
		if is_slippery:
			velocity.x = lerp(velocity.x, 0.0, delta * 1.8)
			velocity.z = lerp(velocity.z, 0.0, delta * 1.8)
		else:
			velocity.x = move_toward(velocity.x, 0.0, DRIVE_SPEED * delta * 12.0)
			velocity.z = move_toward(velocity.z, 0.0, DRIVE_SPEED * delta * 12.0)
			
		rotate_y(SPIN_SPEED * delta)
	else:
		var drive_direction = transform.basis.z if is_inverted else -transform.basis.z
		var current_speed = DRIVE_SPEED * speed_modifier
		
		if is_slippery:
			var target_vel = drive_direction * current_speed
			velocity.x = lerp(velocity.x, target_vel.x, delta * 3.5)
			velocity.z = lerp(velocity.z, target_vel.z, delta * 3.5)
		else:
			velocity.x = drive_direction.x * current_speed
			velocity.z = drive_direction.z * current_speed

	move_and_slide()
	_constrain_to_table()
	
	if movement_trail:
		movement_trail.emitting = is_alive and is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5

func _constrain_to_table() -> void:
	if abs(global_position.x) > TABLE_BOUND:
		global_position.x = sign(global_position.x) * TABLE_BOUND
		velocity.x = 0.0

	if abs(global_position.z) > TABLE_BOUND:
		global_position.z = sign(global_position.z) * TABLE_BOUND
		velocity.z = 0.0

# -------------------------------------------------------------------
# STATUS EFFECT & INVINCIBILITY HANDLERS
# -------------------------------------------------------------------

func apply_speed_boost(duration: float = 5.0) -> void:
	speed_modifier = 1.45
	await get_tree().create_timer(duration).timeout
	speed_modifier = 1.0

func apply_heavy_speed_penalty(duration: float = 5.0) -> void:
	speed_modifier = 0.55
	await get_tree().create_timer(duration).timeout
	speed_modifier = 1.0

func apply_slippery_butter(duration: float = 4.0) -> void:
	is_slippery = true
	await get_tree().create_timer(duration).timeout
	is_slippery = false

func apply_confusion(duration: float = 3.0) -> void:
	is_inverted = true
	await get_tree().create_timer(duration).timeout
	is_inverted = false

func grant_shield() -> void:
	is_shielded = true
	if shield_visual:
		shield_visual.visible = true

func remove_shield() -> void:
	is_shielded = false
	if shield_visual:
		shield_visual.visible = false
	trigger_invincibility(1.5)

func trigger_invincibility(duration: float = 1.5) -> void:
	if is_invincible:
		return
	is_invincible = true
	
	var flash_tween = create_tween().set_loops(int(duration / 0.15))
	flash_tween.tween_property(self, "visible", false, 0.075)
	flash_tween.tween_property(self, "visible", true, 0.075)
	
	await get_tree().create_timer(duration).timeout
	
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
	visible = true
	is_invincible = false
