extends Node3D

signal player_squished
signal slam_impact(impact_position: Vector3)
signal sweep_impact

@onready var warning_shadow: MeshInstance3D = $WarningShadow
@onready var paw_mesh: MeshInstance3D = $PawMesh

var is_attacking: bool = false
var player_ref: Node3D = null

var base_shadow_scale: Vector3 = Vector3.ONE
var base_paw_scale: Vector3 = Vector3.ONE

var sweep_particles: GPUParticles3D

func _ready() -> void:
	visible = false
	if warning_shadow:
		base_shadow_scale = warning_shadow.scale
		_ensure_shadow_material_flush()
	if paw_mesh:
		base_paw_scale = paw_mesh.scale
	_hide_sub_nodes()
	_setup_sweep_particles()

func _ensure_shadow_material_flush() -> void:
	if not warning_shadow:
		return
	var mat = warning_shadow.get_surface_override_material(0)
	if not mat and warning_shadow.mesh:
		mat = warning_shadow.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.6
		mat.render_priority = 1
		mat.no_depth_test = false

func _setup_sweep_particles() -> void:
	sweep_particles = GPUParticles3D.new()
	sweep_particles.name = "SweepSlideParticles"
	add_child(sweep_particles)
	
	sweep_particles.position = Vector3(0.0, 0.08, 0.0)
	sweep_particles.amount = 35
	sweep_particles.lifetime = 0.4
	sweep_particles.local_coords = false
	sweep_particles.emitting = false
	sweep_particles.visible = false

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 1.8
	mat.gravity = Vector3(0, -0.5, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.45
	sweep_particles.process_material = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	
	var mat_3d = StandardMaterial3D.new()
	mat_3d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_3d.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_3d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_3d.albedo_color = Color(0.85, 0.82, 0.78, 0.75)
	quad.material = mat_3d

	sweep_particles.draw_pass_1 = quad

func _hide_sub_nodes() -> void:
	if warning_shadow:
		warning_shadow.visible = false
		warning_shadow.scale = base_shadow_scale
		warning_shadow.position.y = 0.12
	if paw_mesh:
		paw_mesh.visible = false
		paw_mesh.scale = Vector3(base_paw_scale.x, base_paw_scale.y * 0.25, base_paw_scale.z)
		paw_mesh.position = Vector3(0.0, 15.0, 0.0)
	if sweep_particles:
		sweep_particles.emitting = false
		sweep_particles.visible = false

func _get_player() -> Node3D:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref and get_parent() and get_parent().has_node("Player"):
			player_ref = get_parent().get_node("Player")
	return player_ref

# -------------------------------------------------------------------
# PUBLIC ATTACK CALLS
# -------------------------------------------------------------------

func trigger_slam(target_pos: Vector3, speed_mult: float = 1.0) -> void:
	is_attacking = true
	await _run_slam(target_pos, speed_mult)
	is_attacking = false

func trigger_sweep(speed_mult: float = 1.0) -> void:
	is_attacking = true
	await _run_sweep(speed_mult)
	is_attacking = false

func trigger_dual_slam(target_pos_1: Vector3, get_target_2_callable: Callable, is_staggered: bool, speed_mult: float) -> void:
	is_attacking = true
	await _run_slam(target_pos_1, speed_mult)
	
	var delay: float = 0.4 if is_staggered else 0.2
	await get_tree().create_timer(delay).timeout
	
	var target_pos_2: Vector3 = target_pos_1
	if get_target_2_callable.is_valid():
		target_pos_2 = get_target_2_callable.call()
		
	await _run_slam(target_pos_2, speed_mult)
	is_attacking = false

func trigger_dual_sweep(_mode: String, speed_mult: float) -> void:
	is_attacking = true
	await _run_sweep(speed_mult)
	await get_tree().create_timer(0.3).timeout
	await _run_sweep(speed_mult)
	is_attacking = false

# -------------------------------------------------------------------
# CORE ATTACK SEQUENCES
# -------------------------------------------------------------------

func _run_slam(target_pos: Vector3, speed_mult: float) -> void:
	rotation = Vector3.ZERO
	global_position = Vector3(target_pos.x, 0.0, target_pos.z)
	visible = true
	_hide_sub_nodes()

	if sweep_particles:
		sweep_particles.emitting = false
		sweep_particles.visible = false

	if warning_shadow:
		warning_shadow.position.y = 0.12
		warning_shadow.scale = Vector3(base_shadow_scale.x * 2.0, base_shadow_scale.y, base_shadow_scale.z * 2.0)
		warning_shadow.visible = true
	
	var telegraph_delay: float = max(0.25, 0.5 / speed_mult)
	await get_tree().create_timer(telegraph_delay).timeout

	if warning_shadow:
		warning_shadow.visible = false

	if paw_mesh:
		paw_mesh.scale = Vector3(base_paw_scale.x, base_paw_scale.y * 0.25, base_paw_scale.z)
		paw_mesh.position = Vector3(0.0, 8.0, 0.0)
		paw_mesh.visible = true
		
		var slam_time: float = max(0.15, 0.28 / speed_mult)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(paw_mesh, "position", Vector3(0.0, 0.0, 0.0), slam_time)
		await tween.finished

	slam_impact.emit(global_position)
	_check_squish(1.0, false)

	if paw_mesh:
		var retract_tween = create_tween()
		retract_tween.tween_property(paw_mesh, "position", Vector3(0.0, 8.0, 0.0), 0.25)
		await retract_tween.finished

	_hide_sub_nodes()
	visible = false

func _run_sweep(speed_mult: float) -> void:
	visible = true
	_hide_sub_nodes()

	var is_horizontal: bool = randf() > 0.5
	var start_pos: Vector3
	var end_pos: Vector3
	var radius: float = 7.5

	if is_horizontal:
		var side = -1.0 if randf() > 0.5 else 1.0
		var sweep_z = randf_range(-3.0, 3.0)
		start_pos = Vector3(side * radius, 0.12, sweep_z)
		end_pos = Vector3(-side * radius, 0.12, sweep_z)
	else:
		var side = -1.0 if randf() > 0.5 else 1.0
		var sweep_x = randf_range(-3.0, 3.0)
		start_pos = Vector3(sweep_x, 0.12, side * radius)
		end_pos = Vector3(sweep_x, 0.12, -side * radius)

	var center_pos: Vector3 = (start_pos + end_pos) / 2.0

	if paw_mesh:
		paw_mesh.scale = Vector3(base_paw_scale.x, base_paw_scale.y * 0.25, base_paw_scale.z)

	global_position = center_pos
	look_at(end_pos, Vector3.UP)

	if warning_shadow:
		warning_shadow.position.y = 0.12
		warning_shadow.scale = Vector3(base_shadow_scale.x * 1.5, base_shadow_scale.y, radius * 2.0)
		warning_shadow.visible = true

	var telegraph_delay: float = max(0.25, 0.5 / speed_mult)
	await get_tree().create_timer(telegraph_delay).timeout

	if warning_shadow:
		warning_shadow.visible = false

	global_position = start_pos
	look_at(end_pos, Vector3.UP)
	
	if paw_mesh:
		paw_mesh.position = Vector3.ZERO
		paw_mesh.visible = true

	if has_signal("sweep_impact"):
		sweep_impact.emit()

	# Force sweep particles visible and emitting at start_pos
	if sweep_particles:
		sweep_particles.visible = true
		sweep_particles.restart()
		sweep_particles.emitting = true

	var sweep_time: float = max(0.5, 1.2 / speed_mult)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", end_pos, sweep_time)

	while tween.is_running():
		_check_squish(1.25, true)
		await get_tree().process_frame

	if sweep_particles:
		sweep_particles.emitting = false
		sweep_particles.visible = false

	_hide_sub_nodes()
	rotation = Vector3.ZERO
	visible = false

# -------------------------------------------------------------------
# SQUISH DETECTION
# -------------------------------------------------------------------

func _check_squish(radius: float, is_sweep: bool) -> void:
	var p = _get_player()
	if not p or not is_instance_valid(p):
		return
	if "is_alive" in p and not p.is_alive:
		return

	var paw_xz = Vector2(global_position.x, global_position.z)
	var player_xz = Vector2(p.global_position.x, p.global_position.z)
	var player_y = p.global_position.y

	if is_sweep and player_y > 0.75:
		return
	if not is_sweep and player_y > 1.4:
		return

	if paw_xz.distance_to(player_xz) <= radius:
		player_squished.emit()
