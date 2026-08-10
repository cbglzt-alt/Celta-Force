class_name Enemy
extends CharacterBody2D
## 追击型怪物：数值由 EnemyData(.tres) 驱动，随波次增强，任务完成后可暴走。

signal died(pos, gold)

## 数值来源（单一事实：game/data/enemy.tres）
const DATA: EnemyData = preload("res://game/data/enemy.tres")

var hp: float
var max_hp: float
var speed: float
var damage: float
var gold_drop: int
var contact_cooldown: float
var enraged := false
var stunned := false  # 被敲门鬼定身：锁移动

var _player: Node2D
var _fog: Node2D
var _level: Node2D
var _path := PackedVector2Array()
var _path_idx := 0
var _repath := 0.0
var _touch_timer := 0.0
var _base_color := Color("#ef4444")
var _base_modulate := Color(1, 1, 1)

@onready var _body: Polygon2D = $Body
@onready var _hit_area: Area2D = $HitArea


var _sprite: AnimatedSprite2D
var _hp_bar: ColorRect
var _hp_bar_t := 0.0
var _anim := "idle"
var _attacking := false
var _dying := false


func _ready() -> void:
	add_to_group("enemies")
	# 鬼奴：skeleton1 全套动画（idle/walk/attack/hurt/death）
	_sprite = AnimHelper.build_sprite(Art.anims_of("skeleton1"), 9.0, 2.0)
	add_child(_sprite)
	_body.visible = false
	_make_hp_bar()


## 切换动画（相同则不重播；death 优先于 _dying 锁）
func _play(name: String) -> void:
	if _anim == name:
		return
	if _dying and name != "death":
		return
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(name):
		_anim = name
		_sprite.play(name)


## 头顶血条：底条+前景条，受击才显示，3s 无伤害自动隐藏
func _make_hp_bar() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(28, 4)
	bg.position = Vector2(-14, -26)
	bg.z_index = 15
	bg.visible = false
	bg.name = "HpBarBg"
	add_child(bg)
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color("#ef4444")
	_hp_bar.size = Vector2(28, 4)
	bg.add_child(_hp_bar)


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
	s.scale = Vector2(2.0, 2.0)
	s.play("idle")
	return s


## 由 Game 在 add_child 后调用
func setup(round_num: int, is_enraged: bool, player_ref: Node2D, fog_ref: Node2D, level_ref: Node2D) -> void:
	hp = DATA.hp_at(round_num)
	max_hp = hp
	damage = DATA.damage_at(round_num)
	gold_drop = DATA.gold_at(round_num)
	speed = DATA.speed_at(round_num)
	contact_cooldown = DATA.contact_cooldown
	_player = player_ref
	_fog = fog_ref
	_level = level_ref
	if is_enraged:
		apply_enrage()


func apply_enrage() -> void:
	if enraged:
		return
	enraged = true
	speed *= DATA.enrage_speed_mult
	contact_cooldown *= DATA.enrage_cooldown_mult
	_base_color = Color("#ff7b00")
	_base_modulate = _base_color
	_sprite.modulate = _base_color


## 被敲门鬼定身：锁移动（友军误伤/清场风险收益）
func apply_stun(duration: float) -> void:
	if _dying:
		return
	stunned = true
	_sprite.modulate = Color(0.6, 0.6, 1.0)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "定!", Color("#93c5fd"))
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and not _dying:
		stunned = false
		_sprite.modulate = _base_modulate


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		velocity = Vector2.ZERO
		return
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		if not _dying and not _attacking:
			_play("idle")
		return
	# 寻路追击：周期性重算 A* 路径，沿路径走；近身则直冲
	_repath -= delta
	var to_player: Vector2 = _player.global_position - global_position
	if _repath <= 0.0:
		_repath = 0.5
		if _level != null:
			_path = _level.find_path(global_position, _player.global_position)
			_path_idx = 0
	var dir: Vector2
	if to_player.length() < 40.0 or _path.is_empty():
		dir = to_player.normalized()
	else:
		# 沿路径点前进
		while _path_idx < _path.size() and global_position.distance_to(_path[_path_idx]) < 10.0:
			_path_idx += 1
		if _path_idx < _path.size():
			dir = (_path[_path_idx] - global_position).normalized()
		else:
			dir = to_player.normalized()
	velocity = dir * speed
	move_and_slide()
	# 像素 sprite 不旋转，用水平翻转表朝向
	if abs(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0

	# 动画状态：受击/攻击/死亡优先，否则按移动切 walk/idle
	if not _dying and not _attacking:
		_play("walk" if velocity.length() > 5.0 else "idle")

	_touch_timer -= delta
	if _touch_timer <= 0.0:
		for b in _hit_area.get_overlapping_bodies():
			if b.is_in_group("player"):
				_touch_timer = contact_cooldown
				_attack(b)  # 攻击动画与伤害同步：挥刀命中帧才结算
				break


## 攻击与动画同步：播 attack 动画，在挥刀命中帧（约 40% 处）才结算伤害
func _attack(target: Node2D) -> void:
	if _dying or _attacking:
		return
	_attacking = true
	_play("attack")
	# 命中帧：动画进度 ~40%（9帧×9fps≈1s，命中约 0.4s）
	var anim_len: float = _sprite.sprite_frames.get_frame_count("attack") / _sprite.sprite_frames.get_animation_speed("attack")
	await get_tree().create_timer(anim_len * 0.4).timeout
	if not _dying and is_instance_valid(target) and target.alive:
		# 命中时仍须在范围内（抬手期间玩家可走位躲开）
		if global_position.distance_to(target.global_position) < 55.0:
			target.take_damage(damage)
	await _sprite.animation_finished
	_attacking = false
	_anim = ""  # 强制下一帧重切回 walk/idle


func _process(delta: float) -> void:
	if _fog != null:
		visible = _fog.is_visible_world(global_position)
	# 血条无伤害 3s 后隐藏
	if _hp_bar_t > 0.0:
		_hp_bar_t -= delta
		if _hp_bar_t <= 0.0:
			var bg := get_node_or_null("HpBarBg")
			if bg:
				bg.visible = false


func take_damage(n: float, from_pos: Vector2, color := Color(1, 1, 1)) -> void:
	if _dying:
		return
	hp -= n
	_flash()
	_show_hp_bar()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n), color)
	if hp <= 0.0:
		_die()
	elif not _attacking:
		_play("hurt")  # 受击后仰（未在挥刀时）


## 死亡：播 death 动画，播完再销毁（不再瞬移消失）
func _die() -> void:
	_dying = true
	set_physics_process(false)  # 停止移动/寻路/伤害
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	var bg := get_node_or_null("HpBarBg")
	if bg:
		bg.visible = false
	died.emit(global_position, gold_drop)
	_play("death")
	await _sprite.animation_finished
	call_deferred("queue_free")


func _show_hp_bar() -> void:
	var bg := get_node_or_null("HpBarBg")
	if bg:
		bg.visible = true
		_hp_bar.size.x = 28.0 * clampf(hp / max_hp, 0.0, 1.0)
		_hp_bar_t = 3.0  # 3s 无伤害自动隐藏


func _flash() -> void:
	_sprite.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	var restore := Color(0.6, 0.6, 1.0) if stunned else _base_modulate
	tw.tween_property(_sprite, "modulate", restore, 0.12)
