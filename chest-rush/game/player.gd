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

@onready var _pivot: Node2D = $Pivot
var _sprite: AnimatedSprite2D


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	# 用 dungeon 像素 sprite（priest 驭鬼者），替代色块三角
	_sprite = _make_sprite(Art.frames_of("player"))
	_pivot.add_child(_sprite)
	# 挂 3 只鬼（本关固定装备，来自 LOADOUT 的 .tres）
	for i in Weapon.LOADOUT.size():
		var w := Weapon.new()
		add_child(w)
		w.setup(i, self)
		weapons.append(w)


func _make_sprite(paths: Array[String]) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 6.0)
	sf.set_animation_loop("idle", true)
	for p in paths:
		var tex := load(p)
		if tex:
			sf.add_frame("idle", tex)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.scale = Vector2(2.0, 2.0)  # 16px 放大到 ~32px 贴合格子
	s.play("idle")
	return s


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * base_speed * speed_mult
	move_and_slide()
	# 像素 sprite 不旋转（会糊），用水平翻转表左右朝向
	if abs(dir.x) > 0.01:
		_sprite.flip_h = dir.x < 0.0


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
	_sprite.modulate = c
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1), 0.18)


static func circle_poly(r: float, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
