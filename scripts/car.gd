class_name Car
extends CharacterBody3D

const ACCELERATION_SPEED = 15.0
const REVERSE_SPEED = 5.0

const DRIFT_ACCELERATION_FACTOR = 0.925
const DRIFT_STRAFE_SPEED = 3.0

const STEERING_SPEED = 10.0 # how fast the steering angle will change
const MAX_STEERING_ANGLE = 25.0
const DRIFT_STEER_FACTOR = 1.1 # how much more the car steers during drifts

const BRAKE_FRICTION = 10.0
const CRUISE_FRICTION = 1.0
const DRIFT_FRICTION = 2.0

const VEHICLE_ROTATION_SPEED = 5.0

const GRASS_SPEED_FACTOR = 0.5
const BOOST_SPEED_FACTOR = 10.0

@export var checkpoints : Array[Area3D]
var current_checkpoint : int = 0
var current_lap = 0
@export var max_laps = 3

@export var start_ui : Control
@export var end_ui : Control
@export var race_ui : RaceUI

@export var end_title_label : Label
@export var end_time_label: Label

var time_race_started = -999999
var time_race_ended = 0

const MAX_RACE_TIME = 240_000

var forward_velocity := 0.0
var strafe_velocity := 0.0
var steering_angle := 0.0
var forward_direction : Vector3 = Vector3.FORWARD
var right_direction : Vector3 = Vector3.RIGHT
var any_checkpoint_hit = false

@onready var wheel_fl: MeshInstance3D = $"vehicle-speedster/vehicle-speedster/wheel-fl"
@onready var wheel_fr: MeshInstance3D = $"vehicle-speedster/vehicle-speedster/wheel-fr"
@onready var wheel_bl: MeshInstance3D = $"vehicle-speedster/vehicle-speedster/wheel-bl"
@onready var wheel_br: MeshInstance3D = $"vehicle-speedster/vehicle-speedster/wheel-br"
@onready var vehicle_body: MeshInstance3D = $"vehicle-speedster/vehicle-speedster"

@onready var vehicle_node: Node3D = $"vehicle-speedster"
@onready var orientator: Node3D = $orientator

@export var countdown_nodes : Array[Node3D]

const ROTATION_OFFSET = Vector3(90.0, 180.0, 0.0)
var floor_normal : Vector3 = Vector3.UP
var on_grass = false
var on_boost = false

func _ready() -> void:
	forward_direction = get_global_transform().basis * Vector3.FORWARD
	right_direction = get_global_transform().basis * Vector3.RIGHT
	
	for i in checkpoints.size():
		checkpoints[i].body_entered.connect(on_checkpoint_enter.bind(i))

func on_checkpoint_enter(body, idx) -> void:
	if body != self:
		return
	var next_checkpoint = (current_checkpoint + 1) % checkpoints.size()
	if next_checkpoint == idx:
		current_checkpoint = idx
		if idx == 0:
			current_lap += 1
			if current_lap == max_laps:
				_end_race("You Win!")
	elif idx == 0 and any_checkpoint_hit:
		race_ui.flash_checkpoint_missed()
	any_checkpoint_hit = true

func _physics_process(delta: float) -> void:
	if time_race_ended > time_race_started:
		return
		
	if Time.get_ticks_msec() <= time_race_started:
		var seconds : int = (time_race_started - Time.get_ticks_msec() + 900) / 1_000
		for node in countdown_nodes:
			node.hide()
		if seconds < countdown_nodes.size():
			countdown_nodes[seconds].show()
		return
	race_ui.show()
		
	if Time.get_ticks_msec() > time_race_started + MAX_RACE_TIME:
		_end_race("Time's Up!")
	var speed_factor := 1.0
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		floor_normal = floor_normal.lerp(Vector3.UP, Easing.exp_smooth(1.0, delta)).normalized()
	else:
		floor_normal = get_floor_normal()
		if get_last_slide_collision():
			for i in get_last_slide_collision().get_collision_count():
				var collider = get_last_slide_collision().get_collider(i)
				on_grass = collider.is_in_group("grass")
				on_boost = collider.is_in_group("boost")
		if on_boost:
			print("boost")
			speed_factor *= BOOST_SPEED_FACTOR
		if on_grass:
			speed_factor *= GRASS_SPEED_FACTOR
		
	orientator.look_at(orientator.global_position + floor_normal, forward_direction, false)
	var orientator_quat = Quaternion(orientator.basis) * Quaternion.from_euler(Vector3(deg_to_rad(ROTATION_OFFSET.x), deg_to_rad(ROTATION_OFFSET.y), deg_to_rad(ROTATION_OFFSET.z)))
	var vehicle_quat = Quaternion(vehicle_node.basis)
	vehicle_node.basis = Basis(vehicle_quat.slerp(orientator_quat, Easing.exp_smooth(VEHICLE_ROTATION_SPEED, delta)))
		
	var forward_acceleration : float = 0.0
	var strafe_acceleration : float = 0.0
	var wheel_friction := CRUISE_FRICTION
	var surface_friction := BRAKE_FRICTION
	
	forward_velocity = velocity.dot(forward_direction)
	strafe_velocity = velocity.dot(right_direction)
	
	if Input.is_action_pressed("accelerate") or on_boost:
		forward_acceleration += ACCELERATION_SPEED
		if on_boost:
			wheel_friction = surface_friction
	elif Input.is_action_pressed("reverse"):
		if forward_velocity <= 0.1: # reverse
			forward_acceleration -= REVERSE_SPEED
		else: # brake
			wheel_friction = surface_friction
	
	# handle steering
	var target_steering_angle = 0.0
	if Input.is_action_pressed("steer_left"):
		target_steering_angle += MAX_STEERING_ANGLE
	if Input.is_action_pressed("steer_right"):
		target_steering_angle -= MAX_STEERING_ANGLE
	
	steering_angle = lerp(steering_angle, target_steering_angle, Easing.exp_smooth(STEERING_SPEED, delta))
	
	var steering_factor := (forward_velocity + strafe_velocity) / (ACCELERATION_SPEED * 8)
	
	# apply hand brake
	var handbrake_active := Input.is_action_pressed("handbrake") and (forward_acceleration > 0.0 or forward_velocity > 0.0) and is_on_floor()
	if handbrake_active:
		strafe_acceleration += (steering_angle / MAX_STEERING_ANGLE) * DRIFT_STRAFE_SPEED
		forward_velocity *= DRIFT_ACCELERATION_FACTOR
		wheel_friction = BRAKE_FRICTION
		surface_friction = DRIFT_FRICTION
		steering_factor *= DRIFT_STEER_FACTOR
		
	# rotation of vehicle body and wheels
	vehicle_body.rotation_degrees = vehicle_body.rotation_degrees.lerp(
		Vector3(0, (steering_angle * steering_factor * 6), steering_angle * steering_factor * 2) if handbrake_active else Vector3.ZERO,
		Easing.exp_smooth(VEHICLE_ROTATION_SPEED, delta)	
	)
	
	var circumference_fl : float = wheel_fl.get_aabb().get_longest_axis_size() * PI
	var circumference_fr : float = wheel_fr.get_aabb().get_longest_axis_size() * PI
	var circumference_bl : float = wheel_bl.get_aabb().get_longest_axis_size() * PI
	var circumference_br : float = wheel_br.get_aabb().get_longest_axis_size() * PI
	
	wheel_fl.rotation_degrees = Vector3(
		wheel_fl.rotation_degrees.x - (forward_velocity / circumference_fl), 
		steering_angle - (vehicle_body.rotation_degrees.y * 2.0), 0.0)
	wheel_fr.rotation_degrees = Vector3(
		wheel_fr.rotation_degrees.x - (forward_velocity / circumference_fr), 
		steering_angle - (vehicle_body.rotation_degrees.y * 2.0), 0.0)
		
	wheel_bl.rotation_degrees = Vector3(
		wheel_bl.rotation_degrees.x - (forward_velocity / circumference_bl), 
		0.0, 0.0)
	wheel_br.rotation_degrees = Vector3(
		wheel_br.rotation_degrees.x - (forward_velocity / circumference_br), 
		0.0, 0.0)
		
	if not is_on_floor():
		wheel_friction = 0.0
		surface_friction = 0.0
		
	# apply local velocity
	forward_velocity += ((forward_acceleration * wheel_friction * speed_factor) - (forward_velocity * wheel_friction / speed_factor)) * delta
	strafe_velocity += ((strafe_acceleration * surface_friction * speed_factor) - (strafe_velocity * surface_friction / speed_factor)) * delta
	
	if is_on_floor():
		# apply steer
		rotate_y(deg_to_rad(steering_angle * steering_factor))
		forward_direction = get_global_transform().basis * Vector3.FORWARD
		right_direction = get_global_transform().basis * Vector3.RIGHT
		
		# apply velocity
		velocity = (forward_direction * forward_velocity) + (right_direction * strafe_velocity) + Vector3(0.0, velocity.y, 0.0)

	move_and_slide()
	
func lerp(a, b, t : float) -> float:
	return a + (b - a) * t

func _on_start_button_pressed() -> void:
	time_race_started = Time.get_ticks_msec() + 3_000
	start_ui.hide()
	
func _end_race(title : String) -> void:
	time_race_ended = Time.get_ticks_msec()
	end_title_label.text = title
	
	var time_elapsed = time_race_ended - time_race_started
	
	var minutes : int = time_elapsed / 60_000
	var seconds : int = ((time_elapsed + 500) / 1_000) % 60
	end_time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	race_ui.hide()
	end_ui.show()

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
