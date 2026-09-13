class_name MapGenerator
extends RefCounted
## BSP 程序化地图生成器：递归分割 → 房间 → 走廊 → 放置功能元素。
## 输出 ASCII Array[String] 供 LevelMap 解析。
## 图例：# 墙 . 地板 C 宝箱 o 障碍 E 出口 S 刷怪点 P 玩家起点

const W := 40
const H := 24
const MIN_ROOM_W := 6
const MIN_ROOM_H := 5
const MAX_SPLIT_DEPTH := 5

var _rng := RandomNumberGenerator.new()
var _grid: Array[String] = []
var _rooms: Array[Rect2i] = []
var _corridors: Array[Rect2i] = []


## 生成地图。seed_val 控制随机性（同 seed = 同布局）。
## chest_count / obstacle_count / spawn_count 控制各元素数量。
static func generate(seed_val: int, chest_count: int, obstacle_count: int, spawn_count: int) -> Array[String]:
	var gen := MapGenerator.new()
	gen._rng.seed = seed_val
	gen._init_grid()
	gen._split_and_build(Rect2i(1, 1, W - 2, H - 2), 0)
	gen._place_features(chest_count, obstacle_count, spawn_count)
	return gen._grid


func _init_grid() -> void:
	_grid.clear()
	for y in H:
		var row := ""
		for x in W:
			row += "#"
		_grid.append(row)
	# 用可变字符串填充内部为地板
	for y in range(1, H - 1):
		var chars := _grid[y].to_utf8_buffer()
		# to_utf8_buffer 返回 PackedByteArray，需要用别的方式
	# 直接重建行
	_grid.clear()
	for y in H:
		if y == 0 or y == H - 1:
			_grid.append("#".repeat(W))
		else:
			_grid.append("#" + ".".repeat(W - 2) + "#")


## BSP 递归分割
func _split_and_build(rect: Rect2i, depth: int) -> void:
	if depth >= MAX_SPLIT_DEPTH:
		_carve_room(rect)
		return
	var can_split_h := rect.size.x > MIN_ROOM_W * 2 + 3
	var can_split_v := rect.size.y > MIN_ROOM_H * 2 + 3
	if not can_split_h and not can_split_v:
		_carve_room(rect)
		return
	# 随机选切割方向（偏好长边）
	var split_h := can_split_h and (not can_split_v or _rng.randf() < float(rect.size.x) / float(rect.size.x + rect.size.y))
	if split_h:
		var split_x := _rng.randi_range(MIN_ROOM_W + 1, int(rect.size.x) - MIN_ROOM_W - 2)
		split_x += rect.position.x
		_split_and_build(Rect2i(rect.position.x, rect.position.y, split_x - rect.position.x, rect.size.y), depth + 1)
		_split_and_build(Rect2i(split_x, rect.position.y, rect.size.x - (split_x - rect.position.x), rect.size.y), depth + 1)
	else:
		var split_y := _rng.randi_range(MIN_ROOM_H + 1, int(rect.size.y) - MIN_ROOM_H - 2)
		split_y += rect.position.y
		_split_and_build(Rect2i(rect.position.x, rect.position.y, rect.size.x, split_y - rect.position.y), depth + 1)
		_split_and_build(Rect2i(rect.position.x, split_y, rect.size.x, rect.size.y - (split_y - rect.position.y)), depth + 1)


## 在 BSP 叶节点内挖房间（留 1 格墙边距）
func _carve_room(rect: Rect2i) -> void:
	var pad := 1
	var rx := maxi(rect.position.x + pad, 1)
	var ry := maxi(rect.position.y + pad, 1)
	var rw := maxi(int(rect.size.x) - pad * 2, MIN_ROOM_W)
	var rh := maxi(int(rect.size.y) - pad * 2, MIN_ROOM_H)
	rx = mini(rx, W - rw - 2)
	ry = mini(ry, H - rh - 2)
	_rooms.append(Rect2i(rx, ry, rw, rh))
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if x > 0 and x < W - 1 and y > 0 and y < H - 1:
				_set_char(x, y, ".")


## 在两房间中心之间挖 L 形走廊
func _connect_rooms() -> void:
	for i in range(1, _rooms.size()):
		var a: Rect2i = _rooms[i - 1]
		var b: Rect2i = _rooms[i]
		var ax := a.position.x + a.size.x / 2
		var ay := a.position.y + a.size.y / 2
		var bx := b.position.x + b.size.x / 2
		var by := b.position.y + b.size.y / 2
		# 先水平后垂直（或反之，随机）
		if _rng.randf() < 0.5:
			_carve_corridor(ax, bx, ay)
			_carve_corridor(ay, by, bx, true)
		else:
			_carve_corridor(ay, by, ax, true)
			_carve_corridor(ax, bx, by)
	# 额外连一些非相邻房间增加回路
	for i in range(_rooms.size() - 2):
		if _rng.randf() < 0.3:
			var a: Rect2i = _rooms[i]
			var b: Rect2i = _rooms[_rng.randi_range(i + 2, _rooms.size() - 1)]
			var ax := a.position.x + a.size.x / 2
			var ay := a.position.y + a.size.y / 2
			var bx := b.position.x + b.size.x / 2
			var by := b.position.y + b.size.y / 2
			_carve_corridor(ax, bx, ay)
			_carve_corridor(ay, by, bx, true)


func _carve_corridor(a: int, b: int, fixed: int, vertical := false) -> void:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	for i in range(lo, hi + 1):
		if vertical:
			if i > 0 and i < H - 1 and fixed > 0 and fixed < W - 1:
				_set_char(fixed, i, ".")
				_corridors.append(Rect2i(fixed, i, 1, 1))
		else:
			if i > 0 and i < W - 1 and fixed > 0 and fixed < H - 1:
				_set_char(i, fixed, ".")
				_corridors.append(Rect2i(i, fixed, 1, 1))


## 放置功能元素
func _place_features(chest_count: int, obstacle_count: int, spawn_count: int) -> void:
	# 连接走廊
	_connect_rooms()
	# 按位置排序房间（左上 → 右下），放起点/出口
	_rooms.sort_custom(func(a, b): return a.position.x + a.position.y < b.position.x + b.position.y)
	# 玩家起点：第一个房间中心
	if not _rooms.is_empty():
		var r: Rect2i = _rooms[0]
		_set_char(r.position.x + 1, r.position.y + 1, "P")
	# 撤离点：最后一个房间 + 倒数第二个房间
	if _rooms.size() >= 2:
		var last: Rect2i = _rooms[_rooms.size() - 1]
		_set_char(last.position.x + last.size.x - 2, last.position.y + last.size.y - 2, "E")
	if _rooms.size() >= 3:
		var prev: Rect2i = _rooms[_rooms.size() - 2]
		_set_char(prev.position.x + 1, prev.position.y + prev.size.y - 2, "E")
	# 宝箱：各房间随机放
	var placed := 0
	var tries := 0
	while placed < chest_count and tries < 200:
		tries += 1
		var r: Rect2i = _rooms[_rng.randi() % _rooms.size()]
		var cx := _rng.randi_range(r.position.x, r.position.x + r.size.x - 1)
		var cy := _rng.randi_range(r.position.y, r.position.y + r.size.y - 1)
		if _get_char(cx, cy) == ".":
			_set_char(cx, cy, "C")
			placed += 1
	# 障碍物：走廊和房间随机放
	placed = 0
	tries = 0
	while placed < obstacle_count and tries < 200:
		tries += 1
		var r: Rect2i = _rooms[_rng.randi() % _rooms.size()]
		var ox := _rng.randi_range(r.position.x, r.position.x + r.size.x - 1)
		var oy := _rng.randi_range(r.position.y, r.position.y + r.size.y - 1)
		if _get_char(ox, oy) == ".":
			_set_char(ox, oy, "o")
			placed += 1
	# 刷怪点：各房间分散
	placed = 0
	tries = 0
	while placed < spawn_count and tries < 200:
		tries += 1
		var r: Rect2i = _rooms[_rng.randi() % _rooms.size()]
		var sx := _rng.randi_range(r.position.x, r.position.x + r.size.x - 1)
		var sy := _rng.randi_range(r.position.y, r.position.y + r.size.y - 1)
		if _get_char(sx, sy) == ".":
			_set_char(sx, sy, "S")
			placed += 1


func _set_char(x: int, y: int, c: String) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	var row := _grid[y]
	_grid[y] = row.substr(0, x) + c + row.substr(x + 1)


func _get_char(x: int, y: int) -> String:
	if x < 0 or x >= W or y < 0 or y >= H:
		return "#"
	return _grid[y][x]
