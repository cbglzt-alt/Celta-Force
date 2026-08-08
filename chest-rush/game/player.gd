class_name Player
extends CharacterBody2D
## 移动的塔：WASD 走位 + 被动攻击（3 只"鬼"自动索敌开火）。

signal died

@export var base_speed := 170.0
@export var max_hp := 100.0

var hp: float
var damage_mult := 1.0   # 全局伤害倍率（attack 强化乘入各鬼）
var speed_mult := 1.0
var alive := true

var weapons: Array = []

const WeaponScript := preload("res://game/weapon.gd")

@onready var _body: Polygon2D = $Pivot/Body


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	# 朝 +X 的三角（视觉朝向保留，随移动方向转）
	_body.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-10, 11), Vector2(-6, 0), Vector2(-10, -11)])
	_body.color = Color("#4ade80")
	# 挂 3 只鬼（本关固定装备，来自 LOADOUT 的 .tres）
	for i in Weapon.LOADOUT.size():
		var w := Weapon.new()
		add_child(w)
		w.setup(i, self)
		weapons.append(w)


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * base_speed * speed_mult
	move_and_slide()
	if dir.length() > 0.01:
		$Pivot.rotation = dir.angle()


func set_damage_mult(mult: float) -> void:
	damage_mult = mult
	for w in weapons:
		w.damage_mult = mult


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
