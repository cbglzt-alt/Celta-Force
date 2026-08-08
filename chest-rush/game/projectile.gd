class_name Projectile
extends Area2D
## BOLT 直线弹：朝方向飞行，命中单体敌人，出射程即销毁。

var damage := 10.0
var dir := Vector2.RIGHT
var max_range := 200.0
var speed := 420.0
var color := Color.WHITE

var _traveled := 0.0
var _dead := false

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)


func setup(dmg: float, direction: Vector2, rng: float, col: Color) -> void:
	damage = dmg
	dir = direction
	max_range = rng
	color = col
	_body.polygon = Player.circle_poly(4.0, 6)
	_body.color = col
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step := speed * delta
	global_position += dir * step
	_traveled += step
	if _traveled >= max_range:
		_despawn()


func _despawn() -> void:
	if _dead:
		return
	_dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	hide()
	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("enemies"):
		body.take_damage(damage, global_position - dir * 10.0, color)
		_despawn()
	elif body.is_in_group("destructibles") or body is StaticBody2D:
		_despawn()  # 弹撞墙/障碍即销毁（攻击不可穿墙）
