extends Node3D

@export var Target : Node3D
@export var OffsetPosition : Vector3 = Vector3.UP
@export var OffsetRotation : Vector3 = Vector3.ZERO

@export var CameraMoveSpeed : float = 15.0
@export var CameraRotateSpeed : float = 10.0

func _process(delta: float) -> void:
	global_position = global_position.lerp(Target.global_position + OffsetPosition, Easing.exp_smooth(CameraMoveSpeed, delta))
	
	var current_rotation := Quaternion(get_global_basis())
	var target_rotation := Quaternion(Target.get_global_basis()) * Quaternion.from_euler(Vector3(deg_to_rad(OffsetRotation.x), deg_to_rad(OffsetRotation.y), deg_to_rad(OffsetRotation.z)))
	transform.basis = Basis(current_rotation.slerp(target_rotation, Easing.exp_smooth(CameraRotateSpeed, delta)))
