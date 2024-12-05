extends RigidBody3D

#Controllable parameters
@export var human_control: bool = false;
@export var control_thrust_force: float = 75.0;
@export var roll_force: float = 30.0;
@export var thrust_force: float = 500.0;
@export var bound_dist: float = 50.0;
@export var height_bound_dist: float = 100.0;
@export var spawn_pos_margin = 15
@export var spawn_height_margin = 15
@export var spawn_height_average = 45
@export var spawn_rot_degrees_margin = 15

# Thruster Objects
@onready var thrust_main: Node3D = $thrust_main
@onready var thrust_pitch_pos: Node3D = $thrust_pitch_pos
@onready var thrust_pitch_neg: Node3D = $thrust_pitch_neg
@onready var thrust_yaw_pos: Node3D = $thrust_yaw_pos
@onready var thrust_yaw_neg: Node3D = $thrust_yaw_neg
@onready var thrust_roll_pos1: Node3D = $thrust_roll_pos1
@onready var thrust_roll_pos2: Node3D = $thrust_roll_pos2
@onready var thrust_roll_neg1: Node3D = $thrust_roll_neg1
@onready var thrust_roll_neg2: Node3D = $thrust_roll_neg2

# Object references
var actor: RigidBody3D = self;
@onready var ai_controller: AIController3D = $AIController3D
@onready var target: Node3D = $"../Target"
@onready var ground: Node3D = $"../Ground"
var ground_scene: PackedScene = load("res://scenes/ground.tscn")

# Reward variables
var prev_dist: float = 100000
var target_radius: float = 15.0
var should_reset: bool = false
var has_collided: bool = false
var collision_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# Activate collision detection for self
	actor.contact_monitor = true;
	actor.max_contacts_reported = 1;


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# Discrete controls (Also allows human input
	
	# Check if need to reset visible thrusters
	if (human_control && Input.is_action_just_released("thrust")) || ai_controller.thrust == 0:
		thrust_main.visible = false
	if (human_control && Input.is_action_just_released("pitch_pos")) || ai_controller.pitch_roll_yaw[0] != 2:
		thrust_pitch_pos.visible = false
	if (human_control && Input.is_action_just_released("pitch_neg")) || ai_controller.pitch_roll_yaw[0] != 0:
		thrust_pitch_neg.visible = false
	if (human_control && Input.is_action_just_released("yaw_pos")) || ai_controller.pitch_roll_yaw[2] != 2:
		thrust_yaw_pos.visible = false
	if (human_control && Input.is_action_just_released("yaw_neg")) || ai_controller.pitch_roll_yaw[2] != 0:
		thrust_yaw_neg.visible = false
	if (human_control && Input.is_action_just_released("roll_pos")) || ai_controller.pitch_roll_yaw[1] != 2:
		thrust_roll_pos1.visible = false
		thrust_roll_pos2.visible = false
	if (human_control && Input.is_action_just_released("roll_neg")) || ai_controller.pitch_roll_yaw[1] != 0:
		thrust_roll_neg1.visible = false
		thrust_roll_neg2.visible = false
	
	# This is not really accurate to how rocket works
	# Gimbaled thrust might be cool 
	# https://imgs.search.brave.com/LP-tqyN3jlycu30MnluaJv7DFnE7GJaesB5dBMy-C3o/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9pLnNz/dGF0aWMubmV0L0Fu/MEZtLmdpZg.gif
	var torque_vector = Vector3.ZERO
	if (human_control && Input.is_action_pressed("pitch_pos")) || ai_controller.pitch_roll_yaw[0] == 2:
		thrust_pitch_pos.visible = true
		torque_vector.x += control_thrust_force
	if (human_control && Input.is_action_pressed("pitch_neg")) || ai_controller.pitch_roll_yaw[0] == 0:
		thrust_pitch_neg.visible = true
		torque_vector.x -= control_thrust_force
	if (human_control && Input.is_action_pressed("yaw_pos")) || ai_controller.pitch_roll_yaw[2] == 2:
		thrust_yaw_pos.visible = true
		torque_vector.z += control_thrust_force
	if (human_control && Input.is_action_pressed("yaw_neg")) || ai_controller.pitch_roll_yaw[2] == 0:
		thrust_yaw_neg.visible = true
		torque_vector.z -= control_thrust_force
	if (human_control && Input.is_action_pressed("roll_pos")) || ai_controller.pitch_roll_yaw[1] == 2:
		thrust_roll_pos1.visible = true
		thrust_roll_pos2.visible = true
		torque_vector.y += roll_force
	if (human_control && Input.is_action_pressed("roll_neg")) || ai_controller.pitch_roll_yaw[1] == 0:
		thrust_roll_neg1.visible = true
		thrust_roll_neg2.visible = true
		torque_vector.y -= roll_force
	
	if (human_control && Input.is_action_pressed("thrust")) || ai_controller.thrust == 1:
		thrust_main.visible = true
		actor.apply_force(actor.transform.basis.y * thrust_force)
	
	## Continuous controls
	#
	#var torque_vector = ai_controller.pitch_roll_yaw * Vector3(control_thrust_force, roll_force, control_thrust_force)
	#var default_y_scale_control_thruster = 0.317
	#
	#thrust_pitch_pos.scale.y = ai_controller.pitch_roll_yaw[0] * default_y_scale_control_thruster
	#thrust_pitch_neg.scale.y = -ai_controller.pitch_roll_yaw[0] * default_y_scale_control_thruster
	#
	#thrust_roll_pos1.scale.y = ai_controller.pitch_roll_yaw[1] * default_y_scale_control_thruster
	#thrust_roll_pos2.scale.y = ai_controller.pitch_roll_yaw[1] * default_y_scale_control_thruster
	#thrust_roll_neg1.scale.y = -ai_controller.pitch_roll_yaw[1] * default_y_scale_control_thruster
	#thrust_roll_neg2.scale.y = -ai_controller.pitch_roll_yaw[1] * default_y_scale_control_thruster
	#
	#thrust_yaw_pos.scale.y = ai_controller.pitch_roll_yaw[2] * default_y_scale_control_thruster
	#thrust_yaw_neg.scale.y = -ai_controller.pitch_roll_yaw[2] * default_y_scale_control_thruster

	# Apply torque
	actor.apply_torque(actor.transform.basis * torque_vector)
	
	
	## Apply thrust
	#var default_y_scale_main_thruster = 1.0
	#actor.apply_force(actor.transform.basis.y * ai_controller.thrust * thrust_force)
	#thrust_main.scale.y = ai_controller.thrust * default_y_scale_main_thruster
	
	# Reward based on if agent is approaching location
	var dist = actor.position.distance_to(target.position)
	if dist < prev_dist:
		ai_controller.reward += 0.2 * get_time_reward_scale()
	else:
		ai_controller.reward -= 0.2
	prev_dist = dist
	
	# Give negative reward for main_thurst after landing
	if has_collided:
		if ai_controller.thrust == 1:
			ai_controller.reward -= .5
	
	# Reward based on angular velocity
	ai_controller.reward += 0.1 * score_angular_velocity()
	
	# Check bounds
	if abs(actor.position.x) > bound_dist || abs(actor.position.y) > bound_dist || abs(actor.position.z) > height_bound_dist:
		# Going out of bounds penalty
		ai_controller.reward -= 5000
		
		# Reset
		should_reset = true
		ai_controller.reset()
		


func _on_body_entered(body: Node) -> void:
	if !has_collided:
		has_collided = true
		# Create timer for until the rocket must be standing
		collision_timer = Timer.new()
		actor.add_child(collision_timer)
		collision_timer.wait_time = 7
		collision_timer.start()
		collision_timer.timeout.connect(_on_collision_timer_timeout)
		
		# Add score based on initial landing
		ai_controller.reward += 200 * score_rotation()
		ai_controller.reward += 300 * score_speed()
		ai_controller.reward += 100 * score_location()
		
		#print(100 * score_rotation(), "\t", 100 * score_speed(), "\t", 100 * score_location(), "\t", 100 * score_rotation() + 100 * score_speed() + 100 * score_location())

func _on_collision_timer_timeout():
	# Remove timer
	for child in actor.get_children():
		if child.name.match("@Timer@*"):
			actor.remove_child(child)
			
	# Score based on final landing
	ai_controller.reward += 1000 * score_rotation()
	ai_controller.reward += 100 * score_speed()
	ai_controller.reward += 500 * score_location()
	
	# Reset
	should_reset = true
	ai_controller.reset()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if should_reset:
		#ground.call("_generate")
		var prev_ground = actor.get_node("../Ground")
		actor.get_parent().remove_child(prev_ground)
		prev_ground.queue_free()
		var ground_instance = ground_scene.instantiate()
		ground_instance.name = "Ground"
		actor.get_parent().add_child(ground_instance)
		actor.position = Vector3(randf_range(-spawn_pos_margin, spawn_pos_margin), spawn_height_average + randf_range(-spawn_height_margin, spawn_height_margin), randf_range(-spawn_pos_margin, spawn_pos_margin))
		
		var spawn_rot_rad_margin = deg_to_rad(spawn_rot_degrees_margin)
		actor.rotation = Vector3(randf_range(-spawn_rot_rad_margin, spawn_rot_rad_margin), randf_range(-spawn_rot_rad_margin, spawn_rot_rad_margin), randf_range(-spawn_rot_rad_margin, spawn_rot_rad_margin))
		actor.linear_velocity = Vector3(0,0,0)
		actor.angular_velocity = Vector3(0,0,0)
		should_reset = false
		has_collided = false
		ai_controller.reset()
		ai_controller.reward = 0


# Potential reward function improvements
# Add punishment for being on the wall
#    Maybe a collider on the rocket body that if it touches something will greatly decrease reward
#    Maybe greatly decrease landing rewards when scoring close to the target_radius

# Gets how upright the rocket is, scored from 0-1
func score_rotation() -> float:
	# Get quaternions
	var actor_quat = Quaternion(actor.basis)
	var target_quat = Quaternion(1,0,0,0)
	
	# Get dot product, clamped to avoid floating point precision errors
	var dot_product = actor_quat.dot(target_quat)
	var clamped_dot = clamp(dot_product, -1.0, 1.0)
	
	# Get difference from 0-1
	var angle_difference = 2 * acos(abs(clamped_dot))
	var accuracy = (angle_difference/PI)
	return accuracy;

# Get the score multiplier falloff for speed, currently linear function from 1 to -inf
func score_speed() -> float:
	const max_speed = 1.0
	var speed = sqrt(actor.linear_velocity.length_squared())
	return -(speed/max_speed) + 1

# score multiplier falloff for location, linear func fron 1 to -inf
func score_location() -> float:
	var distance = actor.position.distance_to(target.position)
	var wall_margin = 2
	
	# disincentivise being near crater edge
	if target_radius - wall_margin <= distance && distance <= target_radius + wall_margin:
		return -3
	return -(distance/target_radius) + 1

func score_angular_velocity() -> float:
	const max_angular_velocity = 0.5
	return -(actor.angular_velocity.length()/max_angular_velocity) + 1

func get_time_reward_scale() -> float:
	const time_till_decrease = 2000
	const max_time = 3000
	if ai_controller.n_steps < time_till_decrease:
		return 1.0
	elif ai_controller.n_steps > max_time:
		return 0.0
	else:
		return (-1/(max_time-time_till_decrease)) * (ai_controller.n_steps - time_till_decrease)
