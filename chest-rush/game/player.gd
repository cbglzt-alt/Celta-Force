class_name Player
extends CharacterBody2D
## 俯视实时移动 + 鼠标瞄准近战挥击。

signal died

@export var base_speed := 170.0
@export var base_damage := 25.0
@export var max_hp := 100.0
@export var attack_cooldown := 0.4

var hp: float
var damage_mult := 1.0
var speed_mult := 1.0
var alive := true

var _attack_timer := 0.0

@onready var _pivot: Node2D = $Pivot
@onready var _body: Polygon2D = $Pivot/Body
@onready var _attack_area: Area2D = $Pivot/AttackArea
@onready var _swing_flash: Polygon2D = $Pivot/SwingFlash


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	# 朝 +X 的三角，Pivot 旋转瞄准
	_body.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-10, 11), Vector2(-6, 0), Vector2(-10, -11)])
	_body.color = Color("#4ade80")
	# 挥击弧光
	var arc := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		var a := lerpf(-0.8, 0.8, i / 8.0)
		arc.append(Vector2(cos(a), sin(a)) * 46.0)
	_swing_flash.polygon = arc
	_swing_flash.color = Color(1, 1, 1, 0.55)
	_swing_flash.visible = false


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * base_speed * speed_mult
	move_and_slide()
	_pivot.rotation = (get_global_mouse_position() - global_position).angle()
	_attack_timer -= delta
	if Input.is_action_pressed("attack") and _attack_timer <= 0.0:
		_swing()


func _swing() -> void:
	_attack_timer = attack_cooldown
	_swing_flash.visible = true
	_swing_flash.modulate.a = 0.9
	var tw := create_tween()
	tw.tween_property(_swing_flash, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_swing_flash.hide)
	var dmg := base_damage * damage_mult
	for b in _attack_area.get_overlapping_bodies():
		if b.is_in_group("enemies"):
			b.take_damage(dmg, global_position)
		elif b.is_in_group("destructibles"):
			b.hit(1)


func take_damage(n: float) -> void:
	if not alive:
		return
	hp -= n
	_flash_body(Color("#ef4444"))
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n), Color("#f87171"))
	if hp <= 0.0:
		alive = false
		died.emit()


func heal(n: float) -> void:
	hp = minf(hp + n, max_hp)


func _flash_body(c: Color) -> void:
	_body.color = c
	var tw := create_tween()
	tw.tween_property(_body, "color", Color("#4ade80"), 0.18)


static func circle_poly(r: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
