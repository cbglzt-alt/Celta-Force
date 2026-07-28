class_name FogOfWar
extends Node2D
## 三态战争迷雾（仿保卫萝卜4）：未探索=全黑，已探索=暗，可见=无遮挡。
## 玩家视野半径内 BFS 蔓延，墙体与存活的障碍阻挡蔓延（但墙格本身可见）。

enum { UNSEEN, SEEN, VISIBLE }

var level: Node2D
var player: Node2D
var vision_radius := 3

var _w: int
var _h: int
var _states := PackedByteArray()
var _last_tile := Vector2i(-9999, -9999)


func setup(level_map: Node2D) -> void:
	level = level_map
	_w = level.width
	_h = level.height
	_states = PackedByteArray()
	_states.resize(_w * _h)  # 全部 UNSEEN


func is_visible_world(p: Vector2) -> bool:
	if level == null:
		return true
	var t: Vector2i = level.world_to_tile(p)
	if not level.in_bounds(t):
		return false
	return _states[t.y * _w + t.x] == VISIBLE


func force_update() -> void:
	_last_tile = Vector2i(-9999, -9999)
	_process(0.0)


func _process(_delta: float) -> void:
	if level == null or player == null or not is_instance_valid(player):
		return
	var t: Vector2i = level.world_to_tile(player.global_position)
	if t == _last_tile:
		return
	_last_tile = t
	_reveal(t)


func _reveal(center: Vector2i) -> void:
	# 旧的可见格降级为已探索
	for i in _states.size():
		if _states[i] == VISIBLE:
			_states[i] = SEEN
	# BFS：墙体格标记可见但不继续蔓延
	var queue: Array[Vector2i] = [center]
	var dist := {center: 0}
	_states[center.y * _w + center.x] = VISIBLE
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = dist[cur]
		if d >= vision_radius:
			continue
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + off
			if dist.has(n) or not level.in_bounds(n):
				continue
			dist[n] = d + 1
			_states[n.y * _w + n.x] = VISIBLE
			if not level.blocks_vision(n):
				queue.push_back(n)
	queue_redraw()


func _draw() -> void:
	var ts: int = level.TILE
	for y in _h:
		for x in _w:
			var s: int = _states[y * _w + x]
			if s == UNSEEN:
				draw_rect(Rect2(x * ts, y * ts, ts, ts), Color(0, 0, 0, 1))
			elif s == SEEN:
				draw_rect(Rect2(x * ts, y * ts, ts, ts), Color(0, 0, 0, 0.55))
