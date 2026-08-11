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
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect

const HP_BAR_W := 36.0
const HP_BAR_H := 5.0


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
	_make_hp_bar()
	# 挂 3 只鬼（本关固定装备，来自 LOADOUT 的 .tres）
	for i in Weapon.LOADOUT.size():
		var w := Weapon.new()
		add_child(w)
		w.setup(i, self)
		weapons.append(w)


## 头顶常驻血条（观察受击）；数值仍在 HUD 左上角
func _make_hp_bar() -> void:
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0, 0, 0, 0.65)
	_hp_bar_bg.size = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_bg.position = Vector2(-HP_BAR_W * 0.5, -30)
	_hp_bar_bg.z_index = 15
	_hp_bar_bg.name = "HpBarBg"
	add_child(_hp_bar_bg)
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color("#22c55e")
	_hp_bar.size = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_bg.add_child(_hp_bar)
	refresh_hp_bar()


func refresh_hp_bar() -> void:
	if _hp_bar == null or max_hp <= 0.0:
		return
	_hp_bar.size.x = HP_BAR_W * clampf(hp / max_hp, 0.0, 1.0)


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
	var dir := TouchControls.move_dir
	if dir == Vector2.ZERO:
		# 无触摸（或摇杆在死区）时回退键盘
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
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


## 攻击强化：按各鬼 upgrade_scale 微分增长（域后期追上，体现范围强势）
## 域额外：每级范围 ×(1+6%)，满级约 +30%
func apply_attack_upgrade(level: int, per_level: float) -> void:
	damage_mult = pow(per_level, level)
	for w in weapons:
		var scale: float = 1.0
		if w.data != null:
			scale = w.data.upgrade_scale
		w.damage_mult = pow(per_level, float(level) * scale)
		if w.data != null and w.data.pattern == WeaponData.Pattern.AURA:
			w.apply_range_mult(1.0 + float(level) * 0.06)
		else:
			w.apply_range_mult(1.0)


func take_damage(n: float) -> void:
	if not alive:
		return
	hp -= n
	refresh_hp_bar()
	_flash_body(Color("#ef4444"))
	if alive:
		_play("hurt")  # 受击后仰
	var game = get_tree().get_first_node_in_group("game")
	if game:
		# 加粗大红字，盖过氛围色偏蓝；略抬高避开头顶血条
		var shown := maxi(int(round(n)), 1)
		game.spawn_float_text(global_position + Vector2(0, -38), "-%d" % shown, Color("#ef4444"), true)
	if hp <= 0.0:
		alive = false
		_play("death")  # 倒地
		died.emit()


func heal(n: float) -> void:
	hp = minf(hp + n, max_hp)
	refresh_hp_bar()


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
