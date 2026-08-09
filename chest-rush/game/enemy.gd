class_name Enemy
extends CharacterBody2D
## 追击型怪物：数值由 EnemyData(.tres) 驱动，随波次增强，任务完成后可暴走。

signal died(pos, gold)

## 数值来源（单一事实：game/data/enemy.tres）
const DATA: EnemyData = preload("res://game/data/enemy.tres")

var hp: float
var speed: float
var damage: float
var gold_drop: int
var contact_cooldown: float
var enraged := false

var _player: Node2D
var _fog: Node2D
var _level: Node2D
var _path := PackedVector2Array()
var _path_idx := 0
var _repath := 0.0
var _touch_timer := 0.0
var _base_color := Color("#ef4444")

@onready var _body: Polygon2D = $Body
@onready var _hit_area: Area2D = $HitArea


var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	# 用 dungeon 像素 sprite（skeleton 鬼奴），替代色块圆
	_sprite = _make_sprite(Art.frames_of("enemy"))
	add_child(_sprite)
	# 隐藏旧色块体（保留节点以免破坏场景引用）
	_body.visible = false


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
	_sprite.modulate = _base_color


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		velocity = Vector2.ZERO
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

	_touch_timer -= delta
	if _touch_timer <= 0.0:
		for b in _hit_area.get_overlapping_bodies():
			if b.is_in_group("player"):
				b.take_damage(damage)
				_touch_timer = contact_cooldown
				break


func _process(_delta: float) -> void:
	if _fog != null:
		visible = _fog.is_visible_world(global_position)


func take_damage(n: float, from_pos: Vector2, color := Color(1, 1, 1)) -> void:
	hp -= n
	_flash()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n), color)
	if hp <= 0.0:
		died.emit(global_position, gold_drop)
		set_deferred("monitoring", false)
		hide()
		call_deferred("queue_free")


func _flash() -> void:
	_sprite.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", _base_color if enraged else Color(1, 1, 1), 0.12)
