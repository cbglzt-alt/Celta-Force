class_name Destructible
extends StaticBody2D
## 可摧毁物。
## OBSTACLE 障碍：血量制，近战可打，存活时挡视野。
## CHEST 宝箱：贴近读条开启（与攻击伤害脱钩，防"加伤→秒开箱"滚雪球）。

signal destroyed(d)

enum Kind { OBSTACLE, CHEST }

## 宝箱/障碍精灵路径
const CHEST_TEX := Art.CHEST_SPRITE         # GoldMine_Active（192×128）
const CHEST_OPEN_TEX := Art.CHEST_OPEN_SPRITE  # GoldMine_Inactive
## 障碍物用建筑（有 Destroyed 状态）


@export var obstacle_hp := 90.0
@export var chest_open_time := 3.5  # 贴近读条秒数
@export var chest_open_range := 40.0  # 触发读条的距离

var kind: Kind
var hp := 90.0
var has_quest := false
var tile := Vector2i.ZERO
var _obstacle_idx := 0  # 障碍建筑变体索引

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
	_body.visible = false
	_sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	if k == Kind.OBSTACLE:
		hp = obstacle_hp
		# 障碍用建筑精灵（128×192 或 256×192），缩放 0.5 + 底部碰撞
		_obstacle_idx = randi() % Art.OBSTACLE_BUILDINGS.size()
		var building = Art.OBSTACLE_BUILDINGS[_obstacle_idx]
		var tex: Texture2D = load(building.tex)
		if tex:
			sf.add_frame("idle", tex)
		_sprite.scale = Vector2(0.5, 0.5)
		_sprite.offset = Vector2(0, -32)  # 底部对齐
		_sprite.z_index = 1  # 渲染在玩家之上
		# 加底部碰撞（与房屋一致）
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(36, 14)
		cs.shape = shape
		cs.position = Vector2(0, 14)
		body.add_child(cs)
		add_child(body)
	else:
		# 宝箱用 GoldMine（192×128），缩放 0.5 + 底部碰撞
		var ctex: Texture2D = load(CHEST_TEX)
		if ctex:
			sf.add_frame("idle", ctex)
		_sprite.scale = Vector2(0.5, 0.5)
		_sprite.offset = Vector2(0, -16)  # 底部对齐
		_sprite.z_index = 1
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(36, 14)
		cs.shape = shape
		cs.position = Vector2(0, 14)
		body.add_child(cs)
		add_child(body)
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
	set_process(false)
	_clear_bar()
	# 切换为开启状态精灵 + 弹跳 tween
	var open_tex: Texture2D = load(CHEST_OPEN_TEX)
	if open_tex and _sprite.sprite_frames:
		_sprite.sprite_frames.clear("idle")
		_sprite.sprite_frames.add_frame("idle", open_tex)
		_sprite.play("idle")
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(0.6, 0.6), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_sprite, "scale", Vector2(0.5, 0.5), 0.1)
	destroyed.emit(self)
	await tw.finished
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


func _break_open() -> void:
	_opened = true
	set_process(false)
	# 障碍被打烂：切换为 Destroyed 精灵 + 变暗
	var building = Art.OBSTACLE_BUILDINGS[_obstacle_idx]
	var destroyed_tex: Texture2D = load(building.destroyed)
	if destroyed_tex and _sprite.sprite_frames:
		_sprite.sprite_frames.clear("idle")
		_sprite.sprite_frames.add_frame("idle", destroyed_tex)
		_sprite.play("idle")
	destroyed.emit(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "modulate", Color(0.5, 0.45, 0.5), 0.2)
	tw.tween_property(_sprite, "scale", _sprite.scale * 0.8, 0.2)
	await tw.finished
	# 关闭碰撞（StaticBody2D 的碰撞）
	for child in get_children():
		if child is StaticBody2D:
			for cs in child.get_children():
				if cs is CollisionShape2D:
					cs.set_deferred("disabled", true)
	remove_from_group("destructibles")
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
