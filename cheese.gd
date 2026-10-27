extends Area3D

signal cheese_collected(type: int)

enum CheeseType {
	NORMAL,             # 0: Standard Cheddar
	SPEED_BOOST,        # 1: Spicy Red Pepper Jack
	WAX_SHIELD,         # 2: Electric Cyan Shield
	SLOW_CAT,           # 3: Deep Mint Catnip Clock
	SLIPPERY_BUTTER,    # 4: Pale Creamy Butter
	HEAVY_CHEESE,       # 5: Royal Purple Greedy Cheese
	SPOILED_CONFUSION   # 6: Toxic Lime Green
}

@export var type: CheeseType = CheeseType.NORMAL
@export var TABLE_BOUND: float = 3.8
@export var SPECIAL_CHEESE_CHANCE: float = 0.25 # 25% special cheese, 75% normal cheddar
@export var MIN_SPAWN_DIST: float = 2.0 # Minimum distance required from player on spawn

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var last_type: CheeseType = CheeseType.NORMAL
var is_first_spawn: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	respawn()

func reset_cheese() -> void:
	is_first_spawn = true
	respawn()

func respawn() -> void:
	# 1. Fetch player reference to calculate spawn distance
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if not player_node and get_parent() and get_parent().has_node("Player"):
		player_node = get_parent().get_node("Player") as Node3D

	# 2. Pick a random position that maintains minimum distance from player
	var candidate_pos: Vector3 = Vector3.ZERO
	var valid_spawn: bool = false
	var attempts: int = 0
	
	while not valid_spawn and attempts < 20:
		attempts += 1
		candidate_pos = Vector3(
			randf_range(-TABLE_BOUND, TABLE_BOUND),
			0.4,
			randf_range(-TABLE_BOUND, TABLE_BOUND)
		)
		
		if player_node and is_instance_valid(player_node):
			var dist = candidate_pos.distance_to(player_node.global_position)
			if dist >= MIN_SPAWN_DIST:
				valid_spawn = true
		else:
			valid_spawn = true

	global_position = candidate_pos

	# 3. Determine type (first spawn is ALWAYS normal cheddar)
	var chosen_type: CheeseType = CheeseType.NORMAL
	
	if is_first_spawn:
		chosen_type = CheeseType.NORMAL
		is_first_spawn = false
	elif randf() < SPECIAL_CHEESE_CHANCE:
		var available_specials: Array[CheeseType] = []
		for i in range(1, 7):
			var candidate = i as CheeseType
			if candidate != last_type:
				available_specials.append(candidate)
		
		chosen_type = available_specials[randi() % available_specials.size()]
	else:
		chosen_type = CheeseType.NORMAL

	type = chosen_type
	last_type = type
	_apply_type_visuals()

func _apply_type_visuals() -> void:
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.6
	
	match type:
		CheeseType.NORMAL:
			mat.albedo_color = Color(1.0, 0.63, 0.0)
			mat.emission = Color(1.0, 0.45, 0.0)
			
		CheeseType.SPEED_BOOST:
			mat.albedo_color = Color(1.0, 0.16, 0.0)
			mat.emission = Color(1.0, 0.1, 0.0)
			
		CheeseType.WAX_SHIELD:
			mat.albedo_color = Color(0.0, 0.82, 1.0)
			mat.emission = Color(0.0, 0.7, 1.0)
			
		CheeseType.SLOW_CAT:
			mat.albedo_color = Color(0.0, 1.0, 0.53)
			mat.emission = Color(0.0, 0.9, 0.4)
			
		CheeseType.SLIPPERY_BUTTER:
			mat.albedo_color = Color(1.0, 0.99, 0.85)
			mat.emission = Color(0.85, 0.85, 0.7)
			mat.roughness = 0.05
			mat.metallic = 0.15
			
		CheeseType.HEAVY_CHEESE:
			mat.albedo_color = Color(0.61, 0.15, 0.69)
			mat.emission = Color(0.5, 0.0, 0.8)
			
		CheeseType.SPOILED_CONFUSION:
			mat.albedo_color = Color(0.46, 1.0, 0.01)
			mat.emission = Color(0.35, 0.9, 0.0)

	if mesh_instance:
		mesh_instance.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		cheese_collected.emit(int(type))
		respawn()
