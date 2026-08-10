class_name Destructible
extends StaticBody2D
## 可摧毁物。
## OBSTACLE 障碍：血量制，近战可打，存活时挡视野。
## CHEST 宝箱：贴近读条开启（与攻击伤害脱钩，防"加伤→秒开箱"滚雪球）。

signal destroyed(d)

enum Kind { OBSTACLE, CHEST }

const TRAP_DIR := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/items and trap_animation/"
## 障碍物：mini_chest 小宝箱（closed 4帧 + open 4帧，统一形象不用随机 box）
const OBSTACLE_CLOSED := ["mini_chest/mini_chest_1.png", "mini_chest/mini_chest_2.png", "mini_chest/mini_chest_3.png", "mini_chest/mini_chest_4.png"]
const OBSTACLE_OPEN := ["mini_chest/mini_chest_open_1.png", "mini_chest/mini_chest_open_2.png", "mini_chest/mini_chest_open_3.png", "mini_chest/mini_chest_open_4.png"]
## 宝箱：关闭动画 + 打开动画（最明显的 chest 系列）
const CHEST_CLOSED := ["chest/chest_1.png", "chest/chest_2.png", "chest/chest_3.png", "chest/chest_4.png"]
const CHEST_OPEN := ["chest/chest_open_1.png", "chest/chest_open_2.png", "chest/chest_open_3.png", "chest/chest_open_4.png"]

@export var obstacle_hp := 90.0
@export var chest_open_time := 3.5  # 贴近读条秒数
@export var chest_open_range := 40.0  # 触发读条的距离

var kind: Kind
var hp := 90.0
var has_quest := false
var tile := Vector2i.ZERO

var _open_progress := 0.0
var _opening := false
var _player: Node2D
var _progress_bar: ColorRect

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("destructibles")


var _sprite: AnimatedSprite2D


func setup(k: Kind, t: Vector2i) -> void:
	kind = k
	tile = t
	_body.visible = false  # 隐藏占位色块，用多帧动画
	_sprite = AnimatedSprite2D.new()
	_sprite.scale = Vector2(2.0, 2.0)
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 5.0)
	sf.set_animation_loop("idle", true)
	var frames: Array
	if kind == Kind.OBSTACLE:
		hp = obstacle_hp
		frames = OBSTACLE_CLOSED  # 障碍统一 mini_chest 小宝箱
	else:
		frames = CHEST_CLOSED
	for f in frames:
		sf.add_frame("idle", load(TRAP_DIR + f))
	_sprite.sprite_frames = sf
	_sprite.play("idle")
	add_child(_sprite)


## 宝箱贴近读条
func _process(delta: float) -> void:
	if kind != Kind.CHEST:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if not _player.alive:
		_set_opening(false)
		return
	var in_range: bool = global_position.distance_to(_player.global_position) <= chest_open_range
	_set_opening(in_range)
	if _opening:
		_open_progress += delta
		_update_bar()
		if _open_progress >= chest_open_time:
			_open()


var _bar_root: ColorRect  # 读条根节点（底），前景是其子节点


func _set_opening(v: bool) -> void:
	if v == _opening:
		return
	_opening = v
	if v and _bar_root == null:
		_make_bar()
	elif not v and _bar_root != null:
		_clear_bar()
		_open_progress = 0.0  # 离开重置，须一口气读满


func _clear_bar() -> void:
	if _bar_root != null:
		_bar_root.queue_free()  # 连根（含前景子节点）一起销毁
		_bar_root = null
		_progress_bar = null


func _make_bar() -> void:
	# 读条底 + 前景（贴在宝箱下方——上方可能贴墙被挡，下方总是地板）
	_bar_root = ColorRect.new()
	_bar_root.color = Color(0, 0, 0, 0.6)
	_bar_root.size = Vector2(28, 5)
	_bar_root.position = Vector2(-14, 17)
	_bar_root.z_index = 20
	add_child(_bar_root)
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color("#e8c07a")
	_progress_bar.size = Vector2(0, 5)
	_bar_root.add_child(_progress_bar)


func _update_bar() -> void:
	if _progress_bar != null:
		_progress_bar.size.x = 28.0 * clampf(_open_progress / chest_open_time, 0.0, 1.0)


var _opened := false  # 宝箱已开启（留原地成打开状态，不碰撞可走过）


func _open() -> void:
	# 播开箱动画（chest_open 系列），播完停在打开帧、关碰撞、发掉落信号，不销毁
	_play_open()


func _play_open() -> void:
	_opened = true
	set_process(false)  # 停止读条检测
	_clear_bar()  # 清理读条（连根销毁，不残留）
	var sf := SpriteFrames.new()
	sf.add_animation("open")
	sf.set_animation_speed("open", 8.0)
	sf.set_animation_loop("open", false)
	for f in CHEST_OPEN:
		sf.add_frame("open", load(TRAP_DIR + f))
	_sprite.sprite_frames = sf
	_sprite.play("open")
	# 播完掉落物，宝箱定格在 open 最后一帧（开盖亮金光），留原地不销毁
	destroyed.emit(self)
	await _sprite.animation_finished
	_sprite.stop()
	_sprite.frame = CHEST_OPEN.size() - 1  # 定格开盖亮金光的最后一帧
	# 关闭碰撞，玩家可走过（不再是障碍/索敌目标/视野遮挡）
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("destructibles")


## 障碍用武器伤害打；宝箱免疫一切攻击（只能贴近读条）
func take_damage(n: float, _from_pos := Vector2.ZERO, color := Color(1, 1, 1)) -> void:
	if kind == Kind.CHEST:
		return  # 宝箱不受攻击
	hp -= n
	_shake()
	var game = get_tree().get_first_node_in_group("game")
	if game and hp > 0:
		game.spawn_float_text(global_position, "-%d" % int(n), color)
	if hp <= 0:
		_break_open()  # 打烂：播 open 留存（开盖/碎裂可走过），不销毁


## 障碍物被打烂：播开盖/碎裂动画，留原地成破损状态（不碰撞可走过），掉少量金币
func _break_open() -> void:
	_opened = true
	set_process(false)
	var sf := SpriteFrames.new()
	sf.add_animation("open")
	sf.set_animation_speed("open", 8.0)
	sf.set_animation_loop("open", false)
	# 障碍箱的"开"：播它的后几帧（破损/塌陷感），用同一组帧的倒放即可
	var frames: Array = OBSTACLE_OPEN  # 打烂播 open 帧（开盖）
	for f in frames:
		sf.add_frame("open", load(TRAP_DIR + f))
	_sprite.sprite_frames = sf
	_sprite.play("open")
	_sprite.modulate = Color(0.6, 0.55, 0.6)  # 变暗示意已破损
	destroyed.emit(self)
	$CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("destructibles")


func _shake() -> void:
	var node: CanvasItem = _sprite if _sprite != null else _body
	node.modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate", Color(1, 1, 1), 0.15)
	var p0: Vector2 = (node as Node2D).position
	tw.tween_property(node, "position", p0 + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.05)
	tw.tween_property(node, "position", p0, 0.1)


func _square_poly(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
