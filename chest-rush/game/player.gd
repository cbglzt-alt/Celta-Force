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
var stunned := false     # 被敲门鬼定身：锁移动，武器照打

var weapons: Array = []

const WeaponScript := preload("res://game/weapon.gd")

@onready var _pivot: Node2D = $Pivot
var _sprite: AnimatedSprite2D


var _anim := "idle"


func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	# 主角：dungeon priest（驭鬼者，与怪物同风格统一）。只 4 帧 idle（全套动画留待匹配包，见 roadmap）
	_sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 6.0)
	sf.set_animation_loop("idle", true)
	for p in Art.frames_of("player"):
		sf.add_frame("idle", load(p))
	_sprite.sprite_frames = sf
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.play("idle")
	_pivot.add_child(_sprite)
	# 挂 3 只鬼（本关固定装备，来自 LOADOUT 的 .tres）
	for i in Weapon.LOADOUT.size():
		var w := Weapon.new()
		add_child(w)
		w.setup(i, self)
		weapons.append(w)


func _play(name: String) -> void:
	if _anim == name:
		return
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(name):
		_anim = name
		_sprite.play(name)


func _physics_process(_delta: float) -> void:
	if not alive:
		return
	# 定身：锁移动（塔防的"塔"仍开火，只是不能走位）
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		_play("idle")
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * base_speed * speed_mult
	move_and_slide()
	# 像素 sprite 不旋转（会糊），用水平翻转表左右朝向
	if abs(dir.x) > 0.01:
		_sprite.flip_h = dir.x < 0.0
	# 移动播 walk、静止播 idle
	_play("walk" if velocity.length() > 5.0 else "idle")


## 被敲门鬼定身：锁移动 + 锁开火（真定身，只能硬扛，才有压迫感）
func apply_stun(duration: float) -> void:
	if not alive:
		return
	stunned = true
	_set_weapons_enabled(false)  # 定身时 3 鬼停火
	_sprite.modulate = Color(0.6, 0.6, 1.0)  # 泛蓝示意被定
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "定!", Color("#93c5fd"))
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		stunned = false
		_set_weapons_enabled(true)
		_sprite.modulate = Color(1, 1, 1)


func _set_weapons_enabled(v: bool) -> void:
	for w in weapons:
		w.set_physics_process(v)


func set_damage_mult(mult: float) -> void:
	damage_mult = mult
	for w in weapons:
		w.damage_mult = mult


func take_damage(n: float) -> void:
	if not alive:
		return
	hp -= n
	_flash_body(Color("#ef4444"))
	if alive:
		_play("hurt")  # 受击后仰
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n), Color("#f87171"))
	if hp <= 0.0:
		alive = false
		_play("death")  # 倒地
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
