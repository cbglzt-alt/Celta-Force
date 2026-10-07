class_name MapGenerator
extends RefCounted
## 岛屿式程序化地图：有机陆地 + 海湾/水道 + 功能点。
## 输出 ASCII Array[String] 供 LevelMap 解析。
## 图例：# 水/虚空(不可走) . 地板 C 宝箱 o 障碍 E 出口 S 刷怪点 P 玩家起点 H 房屋

const W := 40
const H := 24

var _rng := RandomNumberGenerator.new()
var _grid: Array[String] = []
var _rooms: Array[Rect2i] = []


static func generate(seed_val: int, chest_count: int, obstacle_count: int, spawn_count: int, house_count: int) -> Array[String]:
	var gen := MapGenerator.new()
	gen._rng.seed = seed_val
	gen._build_islands()
	gen._place_features(chest_count, obstacle_count, spawn_count, house_count)
	return gen._grid


func _build_islands() -> void:
	_grid.clear()
	for y in H:
		_grid.append("#".repeat(W))
	var blobs: Array[Dictionary] = []
	blobs.append({
		"cx": 0.48 + _rng.randf_range(-0.04, 0.04),
		"cy": 0.50 + _rng.randf_range(-0.05, 0.05),
		"rx": 0.34 + _rng.randf_range(0.0, 0.06),
		"ry": 0.30 + _rng.randf_range(0.0, 0.05),
		"noise": 0.18,
	})
	if _rng.randf() < 0.85:
		blobs.append({
			"cx": 0.72 + _rng.randf_range(-0.05, 0.05),
			"cy": 0.38 + _rng.randf_range(-0.08, 0.08),
			"rx": 0.18 + _rng.randf_range(0.0, 0.05),
			"ry": 0.16 + _rng.randf_range(0.0, 0.04),
			"noise": 0.22,
		})
	if _rng.randf() < 0.55:
		blobs.append({
			"cx": 0.28 + _rng.randf_range(-0.05, 0.05),
			"cy": 0.62 + _rng.randf_range(-0.06, 0.06),
			"rx": 0.16 + _rng.randf_range(0.0, 0.04),
			"ry": 0.14 + _rng.randf_range(0.0, 0.04),
			"noise": 0.22,
		})
	for y in H:
		for x in W:
			if _in_any_blob(x, y, blobs):
				_set_char(x, y, ".")
	# 兜底：若 blob 失败仍全水，强制中心椭圆陆地
	if _count_land() < 30:
		_paint_main_ellipse()
	_erode_coast(4 + _rng.randi_range(0, 3))
	if _rng.randf() < 0.45:
		_carve_lake()
	_smooth_land(2)
	_remove_tiny_islands(8)
	_ensure_main_landmass(140)
	# 最终保底：仍无足够陆地则再铺主椭圆（侵蚀后可能被吃光）
	if _count_land() < 80:
		_paint_main_ellipse()
		_smooth_land(1)
	_discover_rooms()
	for x in W:
		_set_char(x, 0, "#")
		_set_char(x, H - 1, "#")
	for y in H:
		_set_char(0, y, "#")
		_set_char(W - 1, y, "#")


func _in_any_blob(x: int, y: int, blobs: Array[Dictionary]) -> bool:
	var fx := float(x) / float(maxi(W - 1, 1))
	var fy := float(y) / float(maxi(H - 1, 1))
	for b in blobs:
		var cx := float(b["cx"])
		var cy := float(b["cy"])
		var rx := maxf(float(b["rx"]), 0.05)
		var ry := maxf(float(b["ry"]), 0.05)
		var noise_amp := float(b["noise"])
		var dx := (fx - cx) / rx
		var dy := (fy - cy) / ry
		var d2 := dx * dx + dy * dy
		var n := _edge_noise(x, y) * noise_amp
		if d2 < 1.0 - n:
			return true
	return false


func _edge_noise(x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263 + int(_rng.seed)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 1023) / 511.5 - 1.0


func _erode_coast(passes: int) -> void:
	for _i in passes:
		var candidates: Array[Vector2i] = []
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				if _get_char(x, y) != ".":
					continue
				var water_n := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						if _get_char(x + ox, y + oy) == "#":
							water_n += 1
				if water_n >= 4 and _rng.randf() < 0.12 + float(water_n - 4) * 0.04:
					candidates.append(Vector2i(x, y))
		for c in candidates:
			_set_char(c.x, c.y, "#")


func _carve_lake() -> void:
	var lands: Array[Vector2i] = []
	for y in range(3, H - 3):
		for x in range(3, W - 3):
			if _get_char(x, y) == ".":
				lands.append(Vector2i(x, y))
	if lands.is_empty():
		return
	var c: Vector2i = lands[_rng.randi() % lands.size()]
	var rr := 2 + _rng.randi_range(0, 2)
	for y in range(c.y - rr, c.y + rr + 1):
		for x in range(c.x - rr, c.x + rr + 1):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= rr * rr + _rng.randi_range(-1, 1):
				if x > 1 and y > 1 and x < W - 2 and y < H - 2:
					_set_char(x, y, "#")


func _smooth_land(iters: int) -> void:
	for _i in iters:
		var add: Array[Vector2i] = []
		var rem: Array[Vector2i] = []
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var n := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						if _get_char(x + ox, y + oy) == ".":
							n += 1
				if _get_char(x, y) == "#" and n >= 6:
					add.append(Vector2i(x, y))
				elif _get_char(x, y) == "." and n <= 2:
					rem.append(Vector2i(x, y))
		for p2 in add:
			_set_char(p2.x, p2.y, ".")
		for p2 in rem:
			_set_char(p2.x, p2.y, "#")


func _remove_tiny_islands(min_size: int) -> void:
	var seen: Dictionary = {}
	for y in H:
		for x in W:
			if _get_char(x, y) != "." or seen.has(Vector2i(x, y)):
				continue
			var comp: Array[Vector2i] = []
			var q: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not q.is_empty():
				var cur: Vector2i = q.pop_back()
				comp.append(cur)
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n2: Vector2i = cur + off
					if n2.x < 0 or n2.y < 0 or n2.x >= W or n2.y >= H:
						continue
					if seen.has(n2) or _get_char(n2.x, n2.y) != ".":
						continue
					seen[n2] = true
					q.append(n2)
			if comp.size() < min_size:
				for p3 in comp:
					_set_char(p3.x, p3.y, "#")


func _ensure_main_landmass(min_cells: int) -> void:
	if _count_land() < 20:
		_paint_main_ellipse()
	var best: Array[Vector2i] = _largest_land_component()
	if best.size() >= min_cells:
		return
	for _i in 8:
		var ring: Array[Vector2i] = []
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				if _get_char(x, y) != "#":
					continue
				var n := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if _get_char(x + ox, y + oy) == ".":
							n += 1
				if n >= 2:
					ring.append(Vector2i(x, y))
		for p2 in ring:
			_set_char(p2.x, p2.y, ".")
		best = _largest_land_component()
		if best.size() >= min_cells:
			break


func _largest_land_component() -> Array[Vector2i]:
	var seen: Dictionary = {}
	var best: Array[Vector2i] = []
	for y in H:
		for x in W:
			if _get_char(x, y) != "." or seen.has(Vector2i(x, y)):
				continue
			var comp: Array[Vector2i] = []
			var q: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not q.is_empty():
				var cur: Vector2i = q.pop_back()
				comp.append(cur)
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n2: Vector2i = cur + off
					if n2.x < 0 or n2.y < 0 or n2.x >= W or n2.y >= H:
						continue
					if seen.has(n2) or _get_char(n2.x, n2.y) != ".":
						continue
					seen[n2] = true
					q.append(n2)
			if comp.size() > best.size():
				best = comp
	return best


func _discover_rooms() -> void:
	_rooms.clear()
	var lands := _largest_land_component()
	if lands.is_empty():
		return
	var targets := 5 + _rng.randi_range(0, 3)
	var tries := 0
	while _rooms.size() < targets and tries < 80:
		tries += 1
		var p2: Vector2i = lands[_rng.randi() % lands.size()]
		var rw := 5 + _rng.randi_range(0, 4)
		var rh := 4 + _rng.randi_range(0, 3)
		var rx := clampi(p2.x - rw / 2, 1, W - rw - 2)
		var ry := clampi(p2.y - rh / 2, 1, H - rh - 2)
		var land_n := 0
		var total := rw * rh
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				if _get_char(x, y) == ".":
					land_n += 1
		if float(land_n) / float(total) < 0.7:
			continue
		var rect := Rect2i(rx, ry, rw, rh)
		var overlap := false
		for o in _rooms:
			if rect.intersects(o.grow(-1)):
				overlap = true
				break
		if overlap:
			continue
		_rooms.append(rect)
	if _rooms.is_empty():
		var minx := W
		var miny := H
		var maxx := 0
		var maxy := 0
		for p3 in lands:
			minx = mini(minx, p3.x)
			miny = mini(miny, p3.y)
			maxx = maxi(maxx, p3.x)
			maxy = maxi(maxy, p3.y)
		var cx := (minx + maxx) / 2
		var cy := (miny + maxy) / 2
		_rooms.append(Rect2i(clampi(cx - 3, 1, W - 8), clampi(cy - 2, 1, H - 6), 6, 4))


func _place_features(chest_count: int, obstacle_count: int, spawn_count: int, house_count: int) -> void:
	_rooms.sort_custom(func(a, b): return a.position.x + a.position.y < b.position.x + b.position.y)
	if not _rooms.is_empty():
		var r: Rect2i = _rooms[0]
		var pp := _find_land_in_room(r, true)
		if pp.x >= 0:
			_set_char(pp.x, pp.y, "P")
	if _rooms.size() >= 2:
		var last: Rect2i = _rooms[_rooms.size() - 1]
		var ep := _find_land_in_room(last, false)
		if ep.x >= 0:
			_set_char(ep.x, ep.y, "E")
	if _rooms.size() >= 3:
		var prev: Rect2i = _rooms[_rooms.size() - 2]
		var ep2 := _find_land_in_room(prev, false)
		if ep2.x >= 0 and _get_char(ep2.x, ep2.y) == ".":
			_set_char(ep2.x, ep2.y, "E")
	_ensure_exits(2)

	var placed := 0
	var tries := 0
	var chest_pos: Array[Vector2i] = []
	const CHEST_MIN_SEP := 3
	while placed < chest_count and tries < 700:
		tries += 1
		var r2: Rect2i = _rooms[_rng.randi() % _rooms.size()] if not _rooms.is_empty() else Rect2i(2, 2, W - 4, H - 4)
		var cx := _rng.randi_range(r2.position.x, r2.position.x + maxi(r2.size.x - 1, 0))
		var cy := _rng.randi_range(r2.position.y, r2.position.y + maxi(r2.size.y - 2, 0))
		if not _can_place_chest(cx, cy, chest_pos, CHEST_MIN_SEP):
			continue
		_set_char(cx, cy, "C")
		chest_pos.append(Vector2i(cx, cy))
		placed += 1
	tries = 0
	while placed < chest_count and tries < 900:
		tries += 1
		var cx2 := _rng.randi_range(2, W - 3)
		var cy2 := _rng.randi_range(2, H - 4)
		if not _can_place_chest(cx2, cy2, chest_pos, CHEST_MIN_SEP):
			continue
		_set_char(cx2, cy2, "C")
		chest_pos.append(Vector2i(cx2, cy2))
		placed += 1

	placed = 0
	tries = 0
	while placed < obstacle_count and tries < 500:
		tries += 1
		var ox := _rng.randi_range(2, W - 3)
		var oy := _rng.randi_range(2, H - 3)
		if _get_char(ox, oy) != ".":
			continue
		if _near_char(ox, oy, "C", 2) or _near_char(ox, oy, "P", 2) or _near_char(ox, oy, "E", 1):
			continue
		if not _near_char(ox, oy, "#", 2) and _rng.randf() < 0.55:
			continue
		_set_char(ox, oy, "o")
		placed += 1

	placed = 0
	tries = 0
	while placed < spawn_count and tries < 500:
		tries += 1
		var sx := _rng.randi_range(2, W - 3)
		var sy := _rng.randi_range(2, H - 3)
		if _get_char(sx, sy) != ".":
			continue
		if _is_chest_south(sx, sy) or _near_char(sx, sy, "P", 3):
			continue
		_set_char(sx, sy, "S")
		placed += 1

	placed = 0
	tries = 0
	while placed < house_count and tries < 250:
		tries += 1
		var hx := _rng.randi_range(3, W - 4)
		var hy := _rng.randi_range(3, H - 4)
		if _get_char(hx, hy) != ".":
			continue
		if _near_char(hx, hy, "C", 2) or _near_char(hx, hy, "P", 2) or _near_char(hx, hy, "E", 2):
			continue
		var land_n := 0
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if _get_char(hx + ox, hy + oy) == ".":
					land_n += 1
		if land_n < 6:
			continue
		_set_char(hx, hy, "H")
		placed += 1

	_ensure_chest_access()
	_ensure_exits(2)


func _find_land_in_room(r: Rect2i, prefer_nw: bool) -> Vector2i:
	var cells: Array[Vector2i] = []
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if _get_char(x, y) == ".":
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return Vector2i(-1, -1)
	if prefer_nw:
		cells.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	else:
		cells.sort_custom(func(a, b): return a.x + a.y > b.x + b.y)
	return cells[0]


func _ensure_exits(need: int) -> void:
	var have := 0
	for y in H:
		for x in W:
			if _get_char(x, y) == "E":
				have += 1
	var tries := 0
	while have < need and tries < 200:
		tries += 1
		var x := _rng.randi_range(2, W - 3)
		var y := _rng.randi_range(2, H - 3)
		if _get_char(x, y) != ".":
			continue
		if _near_char(x, y, "P", 4):
			continue
		_set_char(x, y, "E")
		have += 1


func _set_char(x: int, y: int, c: String) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	var row := _grid[y]
	_grid[y] = row.substr(0, x) + c + row.substr(x + 1)


func _get_char(x: int, y: int) -> String:
	if x < 0 or x >= W or y < 0 or y >= H:
		return "#"
	return _grid[y][x]


func _can_place_chest(cx: int, cy: int, existing: Array[Vector2i], min_sep: int) -> bool:
	if cx < 1 or cy < 1 or cx >= W - 1 or cy >= H - 2:
		return false
	if _get_char(cx, cy) != ".":
		return false
	if _get_char(cx, cy + 1) != ".":
		return false
	for dy in range(0, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x == cx and y == cy:
				continue
			if x < 0 or y < 0 or x >= W or y >= H:
				return false
			var c := _get_char(x, y)
			if c == "C" or c == "H" or c == "o" or c == "E" or c == "P":
				return false
	var p2 := Vector2i(cx, cy)
	for other in existing:
		if maxi(absi(p2.x - other.x), absi(p2.y - other.y)) < min_sep:
			return false
	return true


func _is_chest_south(x: int, y: int) -> bool:
	if y <= 0:
		return false
	return _get_char(x, y - 1) == "C"


func _near_char(x: int, y: int, ch: String, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var xx := x + dx
			var yy := y + dy
			if xx < 0 or yy < 0 or xx >= W or yy >= H:
				continue
			if _get_char(xx, yy) == ch:
				return true
	return false


func _ensure_chest_access() -> void:
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if _get_char(x, y) != "C":
				continue
			var sy := y + 1
			if sy >= H - 1:
				continue
			var c := _get_char(x, sy)
			if c != "." and c != "#":
				_set_char(x, sy, ".")


func _count_land() -> int:
	var n := 0
	for y in H:
		for x in W:
			if _get_char(x, y) == ".":
				n += 1
	return n


func _paint_main_ellipse() -> void:
	for y in range(2, H - 2):
		for x in range(3, W - 3):
			var dx := (float(x) / float(maxi(W - 1, 1)) - 0.50) / 0.34
			var dy := (float(y) / float(maxi(H - 1, 1)) - 0.50) / 0.30
			var n := _edge_noise(x, y) * 0.12
			if dx * dx + dy * dy < 1.0 - n:
				_set_char(x, y, ".")
