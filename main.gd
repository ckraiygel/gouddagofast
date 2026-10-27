extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var cheese: Area3D = $Cheese
@onready var cat_paw: Node3D = $CatPaw
@onready var camera: Camera3D = $Camera3D

# UI References
@onready var score_label: Label = $UI/ScoreLabel
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var final_score_label: Label = $UI/GameOverScreen/VBoxContainer/FinalScoreLabel
@onready var restart_button: Button = $UI/GameOverScreen/VBoxContainer/RestartButton

var status_label: Label
var main_menu_screen: Control
var menu_play_button: Button
var menu_quit_button: Button
var main_menu_button: Button
var high_score_label_menu: Label

var active_statuses: Dictionary = {}
const SAVE_PATH: String = "user://highscore.save"

var initial_spawn_pos: Vector3
var is_game_started: bool = false
var score: int = 0
var high_score: int = 0

var attack_timer: float = 0.0
var next_attack_interval: float = 2.5
var sweep_chance: float = 0.30
var cat_slow_multiplier: float = 1.0

func _ready() -> void:
	initial_spawn_pos = player.global_position
	_load_high_score()
	_setup_dynamic_ui()
	_connect_signals()
	_show_main_menu()

# -------------------------------------------------------------------
# PERSISTENT HIGH SCORE
# -------------------------------------------------------------------

func _load_high_score() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		high_score = config.get_value("game", "high_score", 0)
	else:
		high_score = 0

func _save_high_score() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "high_score", high_score)
	config.save(SAVE_PATH)

# -------------------------------------------------------------------
# PARTICLE SPAWNERS
# -------------------------------------------------------------------

func spawn_cheese_particles(pos: Vector3, color: Color) -> void:
	var particles = CPUParticles3D.new()
	add_child(particles)
	particles.global_position = pos
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mesh.material = mat
	particles.mesh = mesh
	
	particles.amount = 14
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 0.95
	
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.5
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	
	particles.emitting = true
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()

func spawn_impact_dust(pos: Vector3) -> void:
	var particles = CPUParticles3D.new()
	add_child(particles)
	particles.global_position = pos + Vector3(0, 0.1, 0)
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.12
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.75, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.mesh = mesh
	
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.9
	
	particles.direction = Vector3.ZERO
	particles.spread = 180.0
	particles.flatness = 1.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -2.0, 0)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 2.0
	
	particles.emitting = true
	
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	particles.queue_free()

# -------------------------------------------------------------------
# UI SETUP & MANAGEMENT
# -------------------------------------------------------------------

func _setup_dynamic_ui() -> void:
	if $UI.has_node("StatusLabel"):
		status_label = $UI/StatusLabel as Label
	else:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		$UI.add_child(status_label)
		
	status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position.y = 45.0

	if $UI.has_node("MainMenuScreen"):
		main_menu_screen = $UI/MainMenuScreen as Control
		var menu_vbox = main_menu_screen.get_node("VBoxContainer")
		menu_play_button = menu_vbox.get_node("PlayButton") as Button
		high_score_label_menu = menu_vbox.get_node("HighScoreLabel") as Label
		
		if menu_vbox.has_node("QuitButton"):
			menu_quit_button = menu_vbox.get_node("QuitButton") as Button
		else:
			menu_quit_button = Button.new()
			menu_quit_button.name = "QuitButton"
			menu_quit_button.text = "QUIT GAME"
			menu_quit_button.custom_minimum_size = Vector2(160, 45)
			menu_vbox.add_child(menu_quit_button)
	else:
		_build_main_menu_node()

	var vbox = $UI/GameOverScreen/VBoxContainer
	if vbox.has_node("MainMenuButton"):
		main_menu_button = vbox.get_node("MainMenuButton") as Button
		main_menu_button.text = "MAIN MENU"
	else:
		main_menu_button = Button.new()
		main_menu_button.name = "MainMenuButton"
		main_menu_button.text = "MAIN MENU"
		vbox.add_child(main_menu_button)

	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI/GameOverScreen/ColorRect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH

func _build_main_menu_node() -> void:
	main_menu_screen = Control.new()
	main_menu_screen.name = "MainMenuScreen"
	$UI.add_child(main_menu_screen)
	main_menu_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	main_menu_screen.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	main_menu_screen.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title = Label.new()
	title.text = "GOUDA GO FAST!"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Hold W / Click to Drive | Space to Jump"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	high_score_label_menu = Label.new()
	high_score_label_menu.name = "HighScoreLabel"
	high_score_label_menu.text = "BEST SCORE: 0"
	high_score_label_menu.add_theme_font_size_override("font_size", 20)
	high_score_label_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(high_score_label_menu)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)
	
	menu_play_button = Button.new()
	menu_play_button.name = "PlayButton"
	menu_play_button.text = "START GAME"
	menu_play_button.custom_minimum_size = Vector2(160, 45)
	vbox.add_child(menu_play_button)
	
	menu_quit_button = Button.new()
	menu_quit_button.name = "QuitButton"
	menu_quit_button.text = "QUIT GAME"
	menu_quit_button.custom_minimum_size = Vector2(160, 45)
	vbox.add_child(menu_quit_button)

func _connect_signals() -> void:
	cheese.cheese_collected.connect(_on_cheese_collected)
	cat_paw.player_squished.connect(_on_player_squished)
	cat_paw.slam_impact.connect(_on_slam_impact)
	if cat_paw.has_signal("sweep_impact"):
		cat_paw.sweep_impact.connect(_on_sweep_impact)
	
	restart_button.pressed.connect(_on_restart_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	menu_play_button.pressed.connect(_on_play_button_pressed)
	menu_quit_button.pressed.connect(_on_quit_button_pressed)

func _show_main_menu() -> void:
	is_game_started = false
	player.is_alive = false
	player.visible = true
	main_menu_screen.visible = true
	game_over_screen.visible = false
	score_label.visible = false
	high_score_label_menu.text = "BEST SCORE: " + str(high_score)
	_clear_all_statuses()

func _start_game() -> void:
	is_game_started = true
	player.reset_player(initial_spawn_pos)
	cheese.reset_cheese()
	score = 0
	attack_timer = 0.0
	next_attack_interval = 2.5
	sweep_chance = 0.30
	_clear_all_statuses()
	
	main_menu_screen.visible = false
	game_over_screen.visible = false
	score_label.visible = true
	_update_score_ui()

func _process(delta: float) -> void:
	if not is_game_started or not player.is_alive:
		return

	_update_status_durations(delta)

	if not cat_paw.is_attacking:
		attack_timer += delta

	if attack_timer >= next_attack_interval:
		attack_timer = 0.0
		
		next_attack_interval = max(0.65, 2.5 - (score * 0.07))
		var base_speed_mult: float = min(2.0, 1.0 + (score * 0.04))
		var speed_mult: float = base_speed_mult * cat_slow_multiplier
		
		_choose_and_trigger_attack(speed_mult)

# -------------------------------------------------------------------
# STATUS EFFECTS
# -------------------------------------------------------------------

func add_status(key: String, text: String, duration: float) -> void:
	active_statuses[key] = {
		"text": text,
		"time_left": duration,
		"is_permanent": (duration <= 0.0)
	}
	_update_status_ui()

func remove_status(key: String) -> void:
	if active_statuses.has(key):
		active_statuses.erase(key)
		_update_status_ui()

func _clear_all_statuses() -> void:
	active_statuses.clear()
	_update_status_ui()

func _update_status_durations(delta: float) -> void:
	var keys_to_remove: Array = []
	for key in active_statuses:
		var data = active_statuses[key]
		if not data["is_permanent"]:
			data["time_left"] -= delta
			if data["time_left"] <= 0.0:
				keys_to_remove.append(key)
				
	if keys_to_remove.size() > 0:
		for key in keys_to_remove:
			active_statuses.erase(key)
		_update_status_ui()

func _update_status_ui() -> void:
	var lines: Array = []
	for key in active_statuses:
		lines.append(active_statuses[key]["text"])
	status_label.text = "\n".join(lines)

# -------------------------------------------------------------------

func _choose_and_trigger_attack(speed_mult: float) -> void:
	var roll = randf()
	
	if score >= 10 and roll < 0.45:
		var dual_roll = randf()
		if dual_roll < 0.5:
			var is_staggered = randf() > 0.5
			cat_paw.trigger_dual_slam(_get_smart_slam_target(), Callable(self, "_get_smart_slam_target"), is_staggered, speed_mult)
		else:
			var sweep_modes = ["PARALLEL", "CRISS_CROSS", "STAGGERED"]
			var chosen_mode = sweep_modes[randi() % sweep_modes.size()]
			cat_paw.trigger_dual_sweep(chosen_mode, speed_mult)
	else:
		if randf() < sweep_chance:
			cat_paw.trigger_sweep(speed_mult)
			sweep_chance = 0.30
		else:
			cat_paw.trigger_slam(_get_smart_slam_target(), speed_mult)
			sweep_chance = min(0.85, sweep_chance + 0.15)

func _on_cheese_collected(type: int) -> void:
	if not is_game_started:
		return

	var particle_color: Color = Color.YELLOW
	match type:
		0: particle_color = Color(1.0, 0.63, 0.0)
		1: particle_color = Color(1.0, 0.16, 0.0)
		2: particle_color = Color(0.0, 0.82, 1.0)
		3: particle_color = Color(0.0, 1.0, 0.53)
		4: particle_color = Color(1.0, 0.99, 0.85)
		5: particle_color = Color(0.61, 0.15, 0.69)
		6: particle_color = Color(0.46, 1.0, 0.01)

	spawn_cheese_particles(cheese.global_position, particle_color)
		
	match type:
		0: score += 1
		1: 
			score += 1
			player.apply_speed_boost(5.0)
			add_status("SPEED", "⚡ PEPPER JACK: SPEED BOOST!", 5.0)
		2: 
			score += 1
			player.grant_shield()
			add_status("SHIELD", "🛡️ WAX SHIELD ACTIVE!", 0.0)
		3: 
			score += 1
			_apply_cat_slowmo(4.0)
			add_status("SLOW_CAT", "⏱️ CATNIP CLOCK: SLOW CAT!", 4.0)
		4: 
			score += 1
			player.apply_slippery_butter(4.0)
			add_status("BUTTER", "🧈 SLIPPERY BUTTER: DRIFTING!", 4.0)
		5: 
			score += 3
			player.apply_heavy_speed_penalty(5.0)
			add_status("HEAVY", "🍇 GREEDY CHEESE: +3 PTS (HEAVY SLOW)", 5.0)
		6: 
			score += 1
			player.apply_confusion(3.0)
			add_status("SPOILED", "🤢 SPOILED CHEESE: REVERSE DRIVE!", 3.0)
			
	_update_score_ui()

func _apply_cat_slowmo(duration: float) -> void:
	cat_slow_multiplier = 0.6
	await get_tree().create_timer(duration).timeout
	cat_slow_multiplier = 1.0

func _on_slam_impact(impact_pos: Vector3) -> void:
	if is_game_started:
		camera.apply_shake(0.85)
		spawn_impact_dust(impact_pos)

func _on_sweep_impact() -> void:
	if not is_game_started:
		return

	# Light gamepad controller rumble (device 0, weak magnitude 0.2, strong magnitude 0.1, duration 0.35s)
	Input.start_joy_vibration(0, 0.2, 0.1, 0.35)

	# Low-intensity camera shake pulses during the slide
	for i in range(3):
		if camera and camera.has_method("apply_shake"):
			camera.apply_shake(0.25)
		await get_tree().create_timer(0.15).timeout

func _on_player_squished() -> void:
	if not is_game_started or player.is_invincible:
		return

	if player.is_shielded:
		player.remove_shield()
		remove_status("SHIELD")
		add_status("IFRAMES", "💥 SHIELD BROKEN! (INVINCIBLE)", 1.5)
		return
		
	player.is_alive = false
	player.visible = false
	_clear_all_statuses()

	var is_new_record: bool = false
	if score > high_score:
		high_score = score
		is_new_record = true
		_save_high_score()
	
	if is_new_record:
		final_score_label.text = "NEW HIGH SCORE!\nScore: " + str(score)
	else:
		final_score_label.text = "Final Score: " + str(score) + "\nBest Score: " + str(high_score)
		
	game_over_screen.visible = true

func _on_play_button_pressed() -> void:
	_start_game()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_restart_button_pressed() -> void:
	_start_game()

func _on_main_menu_button_pressed() -> void:
	_show_main_menu()

func _update_score_ui() -> void:
	score_label.text = "CHEESE: " + str(score)

func _get_smart_slam_target() -> Vector3:
	var target_pos = player.global_position
	var max_lead = min(1.2, 0.5 + (score * 0.03))
	var scatter_range = max(0.2, 1.0 - (score * 0.04))
	
	if player.velocity.length() > 0.5:
		var lead_factor: float = randf_range(0.4, max_lead)
		target_pos += Vector3(player.velocity.x, 0.0, player.velocity.z) * lead_factor
	
	target_pos += Vector3(
		randf_range(-scatter_range, scatter_range),
		0.0,
		randf_range(-scatter_range, scatter_range)
	)
	
	target_pos.x = clamp(target_pos.x, -4.2, 4.2)
	target_pos.z = clamp(target_pos.z, -4.2, 4.2)
	
	return target_pos
