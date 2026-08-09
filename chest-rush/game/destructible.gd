class_name Destructible
extends StaticBody2D
## 可摧毁物。
## OBSTACLE 障碍：血量制，近战可打，存活时挡视野。
## CHEST 宝箱：贴近读条开启（与攻击伤害脱钩，防"加伤→秒开箱"滚雪球）。

signal destroyed(d)

enum Kind { OBSTACLE, CHEST }

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


var _sprite: Sprite2D


func setup(k: Kind, t: Vector2i) -> void:
	kind = k
	tile = t
	if kind == Kind.OBSTACLE:
		hp = obstacle_hp
		_body.color = Color("#8b6f47")  # 障碍暂留色块（木箱/石块 sprite 后补）
		_body.polygon = _square_poly(13.0)
	else:
		# 宝箱用 tileset 现成 sprite
		_body.visible = false
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://assets/tiles/chest.png")
		_sprite.scale = Vector2(2.0, 2.0)
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


func _set_opening(v: bool) -> void:
	if v == _opening:
		return
	_opening = v
	if v and _progress_bar == null:
		_make_bar()
	elif not v and _progress_bar != null:
		_progress_bar.queue_free()
		_progress_bar = null
		_open_progress = 0.0  # 离开重置，须一口气读满


func _make_bar() -> void:
	# 读条底 + 前景（贴在宝箱下方——上方可能贴墙被挡，下方总是地板）
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(28, 5)
	bg.position = Vector2(-14, 17)
	bg.z_index = 20
	add_child(bg)
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color("#e8c07a")
	_progress_bar.size = Vector2(0, 5)
	bg.add_child(_progress_bar)


func _update_bar() -> void:
	if _progress_bar != null:
		_progress_bar.size.x = 28.0 * clampf(_open_progress / chest_open_time, 0.0, 1.0)


func _open() -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "开", Color("#e8c07a"))
	destroyed.emit(self)
	queue_free()


## 障碍用武器伤害打；宝箱免疫一切攻击（只能贴近读条）
func take_damage(n: float, _from_pos := Vector2.ZERO, color := Color(1, 1, 1)) -> void:
	if kind == Kind.CHEST:
		return  # 宝箱不受攻击
	hp -= n
	_shake()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n) if hp > 0 else "碎", color)
	if hp <= 0:
		destroyed.emit(self)
		queue_free()


func _shake() -> void:
	var node: CanvasItem = _sprite if (kind == Kind.CHEST and _sprite != null) else _body
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
