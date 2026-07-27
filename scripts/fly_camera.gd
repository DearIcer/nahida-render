extends Camera3D
# 移植自 Unity FirstPersonController：WASD 移动，鼠标视角，Q/E 升降，Esc 释放鼠标

@export var walk_speed := 1.5
@export var up_down_speed := 1.0
@export var mouse_sensitivity := 0.15
@export var lock_cursor := false

var _pitch := 0.0
var _yaw := 0.0

func _ready() -> void:
	_pitch = rad_to_deg(rotation.x)
	_yaw = rad_to_deg(rotation.y)
	if lock_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -89.0, 89.0)
		rotation = Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)
	if event is InputEventMouseButton and event.pressed and not lock_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= global_basis.z
	if Input.is_key_pressed(KEY_S):
		dir += global_basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= global_basis.x
	if Input.is_key_pressed(KEY_D):
		dir += global_basis.x
	if dir.length_squared() > 0.0:
		global_position += dir.normalized() * walk_speed * delta
	if Input.is_key_pressed(KEY_E):
		global_position.y += up_down_speed * delta
	if Input.is_key_pressed(KEY_Q):
		global_position.y -= up_down_speed * delta
