extends Node3D
class_name AIController3D

enum ControlModes { INHERIT_FROM_SYNC, HUMAN, TRAINING, ONNX_INFERENCE, RECORD_EXPERT_DEMOS }
@export var control_mode: ControlModes = ControlModes.INHERIT_FROM_SYNC
@export var onnx_model_path := ""
@export var reset_after := 1000

@export_group("Record expert demos mode options")
## Path where the demos will be saved. The file can later be used for imitation learning.
@export var expert_demo_save_path: String
## The action that erases the last recorded episode from the currently recorded data.
@export var remove_last_episode_key: InputEvent
## Action will be repeated for n frames. Will introduce control lag if larger than 1.
## Can be used to ensure that action_repeat on inference and training matches
## the recorded demonstrations.
@export var action_repeat: int = 1

@export_group("Multi-policy mode options")
## Allows you to set certain agents to use different policies.
## Changing has no effect with default SB3 training. Works with Rllib example.
## Tutorial: https://github.com/edbeeching/godot_rl_agents/blob/main/docs/TRAINING_MULTIPLE_POLICIES.md
@export var policy_name: String = "shared_policy"

var onnx_model: ONNXModel

var heuristic := "human"
var done := false
var reward := 0.0
var n_steps := 0
var needs_reset := false

var _player: RigidBody3D
var _target: Node3D

var pitch_roll_yaw: Vector3 = Vector3(1,1,1)
var thrust: int = 0

func _ready():
	add_to_group("AGENT")
	init($"..", $"../../Target")


func init(player: RigidBody3D, target):
	_player = player
	_target = target


#-- Methods that need implementing using the "extend script" option in Godot --#
func get_obs() -> Dictionary:
	var obs := [
		_player.position.x,
		_player.position.y,
		_player.position.z,
		_player.rotation_degrees.x,
		_player.rotation_degrees.y,
		_player.rotation_degrees.z,
		_player.linear_velocity.x,
		_player.linear_velocity.y,
		_player.linear_velocity.z,
		_player.angular_velocity.x,
		_player.angular_velocity.y,
		_player.angular_velocity.z,
		_target.position.x,
		_target.position.y,
		_target.position.z,
	]
	
	return {"obs": obs}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return {
		#"pitch_roll_yaw": {"size": 3, "action_type": "continuous"},
		#"thrust":{"size":1, "action_type": "continuous"},
		"pitch": {"size": 3, "action_type": "discrete"},
		"roll": {"size": 3, "action_type": "discrete"},
		"yaw": {"size": 3, "action_type": "discrete"},
		"thrust": {"size": 2, "action_type": "discrete"},
	}


func set_action(action) -> void:
	# Get pitch roll yaw values
	pitch_roll_yaw = Vector3(action["pitch"], action["roll"], action["yaw"])
	thrust = action["thrust"]
	#pitch_roll_yaw = Vector3(action["pitch_roll_yaw"][0], action["pitch_roll_yaw"][1], action["pitch_roll_yaw"][2])
	## Get thrust value, map from range -1-1 to range 0-1
	#thrust = (action["thrust"][0] + 1)/2


#-----------------------------------------------------------------------------#


#-- Methods that sometimes need implementing using the "extend script" option in Godot --#
# Only needed if you are recording expert demos with this AIController
func get_action() -> Array:
	assert(false, "the get_action method is not implemented in extended AIController but demo_recorder is used")
	return []

# -----------------------------------------------------------------------------#


func _physics_process(delta):
	n_steps += 1
	if n_steps > reset_after:
		needs_reset = true


func get_obs_space():
	# may need overriding if the obs space is complex
	var obs = get_obs()
	return {
		"obs": {"size": [len(obs["obs"])], "space": "box"},
	}


func reset():
	n_steps = 0
	needs_reset = false


func reset_if_done():
	if done:
		reset()


func set_heuristic(h):
	# sets the heuristic from "human" or "model" nothing to change here
	heuristic = h


func get_done():
	return done


func set_done_false():
	done = false


func zero_reward():
	reward = 0.0
