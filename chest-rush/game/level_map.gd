class_name LevelMap
extends Node2D
## 解析 ASCII 地图，生成墙、可摧毁物、撤离点、刷怪点。
## 图例：# 墙(永久挡视野) o 可摧毁障碍(存活时挡视野) C 宝箱
##       E 撤离点 S 刷怪点 P 玩家出生点 . 地板
## 地图数据由 game.gd 通过 setup_level() 注入；不再硬编码 const MAP。

signal destructible_destroyed(d)

const TILE := 32
const DestructibleScene := preload("res://game/destructible.tscn")

## 当前关卡的 ASCII 地图（由 game.gd 设置）
var map_data: Array[String] = []
var tile_theme: String = "grass"
var decor_theme: String = "grassland"

var width: int
var height: int
var walls: Dictionary = {}      # Vector2i -> true
var obstacles: Dictionary = {}  # Vector2i -> Destructible (存活时挡视野)
var chests: Array = []
var chest_tiles: Dictionary = {}  # Vector2i -> true（宝箱格，寻路不可通行）
var spawn_points: Array[Vector2] = []
var player_start := Vector2.ZERO
var exits: Array = []           # Dictionary{area, marker, tile, unlocked}
var water_tiles: Dictionary = {}  # Vector2i -> true（水格，不可通行）


func _ready() -> void:
	# 不自动构建；由 game.gd 调用 setup_level() + build()
	# 如果 map_data 已被设置（探针等直接调用），则自动构建
	if not map_data.is_empty():
		_build()


func setup_level(_data) -> void:
	pass  # 关卡参数由 game.gd 直接设置；地图数据通过 setup_level_data 注入


func setup_level_data(map: Array[String]) -> void:
	map_data = map.duplicate()


func setup_theme(tt: String, dt: String) -> void:
	tile_theme = tt
	decor_theme = dt


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i((p / TILE).floor())


func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t) * TILE + Vector2(TILE * 0.5, TILE * 0.5)


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


## 墙体永久挡视野，可摧毁障碍存活时挡视野
func blocks_vision(t: Vector2i) -> bool:
	if not in_bounds(t):
		return true
	if walls.has(t):
		return true
	var o = obstacles.get(t)
	return o != null and is_instance_valid(o)


## 房间探测：从某格向四周扩散到墙，返回房间矩形（铺满整个房间）。
func room_square(center_t: Vector2i, max_half := 8) -> Rect2i:
	var left := 0
	var right := 0
	var up := 0
	var down := 0
	while left < max_half and not blocks_vision(center_t + Vector2i(-(left + 1), 0)):
		left += 1
	while right < max_half and not blocks_vision(center_t + Vector2i(right + 1, 0)):
		right += 1
	while up < max_half and not blocks_vision(center_t + Vector2i(0, -(up + 1))):
		up += 1
	while down < max_half and not blocks_vision(center_t + Vector2i(0, down + 1)):
		down += 1
	return Rect2i(center_t - Vector2i(left, up), Vector2i(left + right + 1, up + down + 1))


func unlock_exits() -> void:
	for rec in exits:
		rec.unlocked = true
		rec.marker.modulate = Color(1.3, 1.15, 0.7)
		var glow := Polygon2D.new()
		glow.polygon = Player.circle_poly(24.0, 24)
		glow.color = Color(1.0, 0.85, 0.3, 0.22)
		glow.z_index = -1
		rec.marker.add_child(glow)


func _build() -> void:
	height = map_data.size()
	width = map_data[0].length()
	for row in map_data:
		assert(row.length() == width, "地图行宽不一致: %s" % row)

	_build_floor()

	var wall_body := StaticBody2D.new()
	wall_body.collision_layer = 4
	wall_body.collision_mask = 0
	var wall_visual := WallVisual.new()

	for y in height:
		for x in width:
			var c := map_data[y][x]
			var t := Vector2i(x, y)
			var center := tile_to_world(t)
			match c:
				"#":
					walls[t] = true
					var cs := CollisionShape2D.new()
					var shape := RectangleShape2D.new()
					shape.size = Vector2(TILE, TILE)
					cs.shape = shape
					cs.position = center
					wall_body.add_child(cs)
					wall_visual.wall_tiles.append(t)
				"o", "C":
					var d = DestructibleScene.instantiate()
					add_child(d)
					d.global_position = center
					d.setup(Destructible.Kind.OBSTACLE if c == "o" else Destructible.Kind.CHEST, t)
					d.destroyed.connect(_on_destructible_destroyed)
					if c == "o":
						obstacles[t] = d
					else:
						chests.append(d)
						chest_tiles[t] = true
				"E":
					exits.append(_make_exit(center, t))
				"S":
					spawn_points.append(center)
				"P":
					player_start = center
				"H":
					_make_house(center, t)
				"W":
					water_tiles[t] = true
					# 水面精灵（z=-9 在地板之上、其余之下）+ 全格碰撞
					var wbody := StaticBody2D.new()
					wbody.collision_layer = 4
					wbody.collision_mask = 0
					var wcs := CollisionShape2D.new()
					var wshape := RectangleShape2D.new()
					wshape.size = Vector2(TILE, TILE)
					wcs.shape = wshape
					wcs.position = center
					wbody.add_child(wcs)
					var wsprite := Sprite2D.new()
					wsprite.texture = load(Art.WATER_SPRITE)
					wsprite.scale = Vector2(0.5, 0.5)  # 64→32px
					wsprite.z_index = -9
					wbody.add_child(wsprite)
					wbody.position = center
					add_child(wbody)
				"B":
					# 桥：无碰撞（可通行），精灵在水之上
					var bsprite := Sprite2D.new()
					bsprite.texture = Art.slice_grid(Art.BRIDGE_SPRITE, 64, 1, 1)
					bsprite.scale = Vector2(0.5, 0.5)  # 64→32px
					bsprite.z_index = -7  # 在水面(-9)之上
					add_child(bsprite)
					bsprite.position = center

	add_child(wall_body)
	add_child(wall_visual)
	_build_decor()
	assert(not chests.is_empty(), "地图没有宝箱")
	assert(spawn_points.size() > 0, "地图没有刷怪点")
	assert(exits.size() >= 2, "撤离点不足 2 个")
	_build_pathfinding()


# ---------- 寻路（怪物 A*，障碍摧毁后重算） ----------

var _astar := AStar2D.new()


func _pid(t: Vector2i) -> int:
	return t.y * width + t.x


func _build_pathfinding() -> void:
	_astar.clear()
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			var id := _pid(t)
			_astar.add_point(id, tile_to_world(t))
			if walls.has(t) or chest_tiles.has(t) or water_tiles.has(t) or (obstacles.get(t) != null and is_instance_valid(obstacles[t])):
				_astar.set_point_disabled(id, true)
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			var id := _pid(t)
			for off in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = t + off
				if in_bounds(n):
					_astar.connect_points(id, _pid(n))


func notify_walkable_changed(t: Vector2i) -> void:
	_astar.set_point_disabled(_pid(t), false)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _pid(world_to_tile(from))
	var b := _pid(world_to_tile(to))
	if not _astar.has_point(a) or not _astar.has_point(b):
		return PackedVector2Array()
	var pts := _astar.get_point_path(a, b)
	return pts


func _make_exit(center: Vector2, t: Vector2i) -> Dictionary:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	cs.shape = shape
	# 撤离点：蓝色塔楼 sprite（暗=锁定，亮=解锁）
	var marker := Sprite2D.new()
	marker.texture = load(Art.EXIT_SPRITE)
	marker.scale = Vector2(0.25, 0.25)  # 128x256 → 32x64
	marker.modulate = Color(0.35, 0.35, 0.4)
	area.add_child(cs)
	area.add_child(marker)
	add_child(area)
	area.global_position = center
	var rec := {"area": area, "marker": marker, "tile": t, "unlocked": false}
	area.body_entered.connect(func(body): _on_exit_body(body, rec))
	return rec


func _on_exit_body(body: Node2D, rec: Dictionary) -> void:
	if body.is_in_group("player") and rec.unlocked:
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.try_extract()


func _on_destructible_destroyed(d) -> void:
	if obstacles.get(d.tile) == d:
		obstacles.erase(d.tile)
		notify_walkable_changed(d.tile)
	elif chest_tiles.has(d.tile):
		chest_tiles.erase(d.tile)
		notify_walkable_changed(d.tile)
	destructible_destroyed.emit(d)


## 房屋：StaticBody2D 底部碰撞 + 精灵在 z_index=1（玩家可从上方/侧面穿过，底部挡住）
## 房屋不加入 walls 字典（不挡视野/寻路），只做物理碰撞
func _make_house(center: Vector2, _t: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4  # 同墙体层：挡玩家/敌人/LOS
	body.collision_mask = 0
	# 底部碰撞条（只有房屋底部挡路，上方/侧面可穿过）
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 14)
	cs.shape = shape
	cs.position = Vector2(0, 14)  # 偏向底部
	body.add_child(cs)
	# 房屋精灵（128×192 缩放 0.5 = 64×96px，底部对齐格子底边）
	var idx := randi() % Art.HOUSE_VARIANTS.size()
	var sprite := Sprite2D.new()
	sprite.texture = load(Art.HOUSE_VARIANTS[idx])
	sprite.scale = Vector2(0.5, 0.5)
	sprite.offset = Vector2(0, -32)  # 上移使底部对齐格底
	sprite.z_index = 1  # 在玩家(0)之上，玩家可"走到房屋后面"
	body.add_child(sprite)
	add_child(body)
	body.global_position = center


## 装饰层：地面树木/灌木/岩石（按关卡主题选择）。纯视觉 + 底部碰撞。
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	var decor_keys: Array = Art.DECOR_THEMES.get(decor_theme, ["rock1", "rock2"])
	if decor_keys.is_empty():
		decor_keys = ["rock1"]
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			if walls.has(t) or obstacles.has(t):
				continue
			if map_data[y][x] != ".":
				continue
			if rng.randf() < 0.08:
				var key: String = decor_keys[rng.randi() % decor_keys.size()]
				_add_ts_decor(key, tile_to_world(t) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4)), rng)
	# 墙面装饰：墙脚放岩石（替代旧版火把）
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			if not walls.has(t):
				continue
			var below := t + Vector2i(0, 1)
			if in_bounds(below) and not blocks_vision(below) and rng.randf() < 0.10:
				var key: String = ["rock1", "rock2", "rock3", "rock4"][rng.randi() % 4]
				_add_ts_decor(key, tile_to_world(t) + Vector2(0, 6), rng)


## 用 tiny-swords 装饰精灵放置地面/墙面装饰
## 树用 4 帧网格动画（Tree.png row0），灌木用缩放呼吸，岩石静态
func _add_ts_decor(key: String, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var path: String = Art.DECOR[key]
	var cell: int = Art.DECOR_CELL.get(key, 64)
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var is_tree := key == "tree"
	var is_bush := cell >= 128 and not is_tree
	var sc := 0.20 if is_tree else (0.30 if is_bush else 0.30)

	if is_tree:
		# 树：用 Tree.png 的 4 帧网格动画（row0 摇曳帧）+ 底部碰撞
		var sf := SpriteFrames.new()
		sf.add_animation("sway")
		sf.set_animation_speed("sway", 3.0)
		sf.set_animation_loop("sway", true)
		for g in Art.TREE_FRAMES:
			var frame_tex: Texture2D = Art.slice_grid(path, cell, g.x, g.y)
			if frame_tex:
				sf.add_frame("sway", frame_tex)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = sf
		s.scale = Vector2(sc, sc)
		s.offset = Vector2(0, -8)  # 底部对齐格子底边
		s.z_index = 3  # 渲染在墙体之上
		s.play("sway")
		s.frame = rng.randi() % Art.TREE_FRAMES.size()
		s.sprite_frames.set_animation_speed("sway", rng.randf_range(2.5, 4.0))
		# 用 StaticBody2D 包裹：底部树干碰撞，上方/侧面可穿过
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(10, 8)  # 细树干碰撞
		cs.shape = shape
		cs.position = Vector2(0, 6)
		body.add_child(cs)
		body.add_child(s)
		add_child(body)
		body.global_position = pos
	else:
		# 灌木/岩石：静态首帧
		var sprite_tex: Texture2D = tex
		if cell > 0 and tex.get_width() > cell:
			var src_img := tex.get_image()
			var img_h := src_img.get_height()
			var sub := Image.create(cell, img_h, false, Image.FORMAT_RGBA8)
			sub.blit_rect(src_img, Rect2i(0, 0, cell, img_h), Vector2i.ZERO)
			sprite_tex = ImageTexture.create_from_image(sub)
		var s := Sprite2D.new()
		s.texture = sprite_tex
		s.scale = Vector2(sc, sc)
		s.z_index = -5
		add_child(s)
		s.global_position = pos
		# 灌木用缩放呼吸
		if is_bush:
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "scale", Vector2(sc * 1.08, sc * 1.08), 1.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(s, "scale", Vector2(sc, sc), 1.5).set_trans(Tween.TRANS_SINE)


## 地板：用关卡专属色板瓦片平铺
func _build_floor() -> void:
	var atlas_path: String = Art.TILE_ATLASES.get(tile_theme, Art.FLAT_ATLAS)
	var f := FloorBG.new()
	f.setup(width, height, TILE, load(atlas_path))
	add_child(f)


## 地板：从图集取草地变体平铺 + 淡网格
class FloorBG extends Node2D:
	var w: int
	var h: int
	var ts: int
	var atlas: Texture2D
	var _rng := RandomNumberGenerator.new()
	var _floor_tiles: Array[Texture2D] = []

	func setup(_w: int, _h: int, _ts: int, _atlas: Texture2D) -> void:
		w = _w
		h = _h
		ts = _ts
		atlas = _atlas
		z_index = -10
		_rng.seed = 20260728
		# 从图集直接切草地变体（兼容不同色板图集）
		if atlas != null:
			var img := atlas.get_image()
			for g in Art.GRASS_TILES:
				var sub := Image.create(Art.SRC_TILE, Art.SRC_TILE, false, Image.FORMAT_RGBA8)
				sub.blit_rect(img, Rect2i(g.x * Art.SRC_TILE, g.y * Art.SRC_TILE, Art.SRC_TILE, Art.SRC_TILE), Vector2i.ZERO)
				_floor_tiles.append(ImageTexture.create_from_image(sub))

	func _draw() -> void:
		var cell := Vector2(ts, ts)
		if _floor_tiles.is_empty():
			# 兜底：纯色草地背景
			draw_rect(Rect2(0, 0, w * ts, h * ts), Color(0.6, 0.74, 0.31), true)
		else:
			for y in h:
				for x in w:
					var tex: Texture2D = _floor_tiles[_rng.randi() % _floor_tiles.size()]
					draw_texture_rect(tex, Rect2(Vector2(x * ts, y * ts), cell), false)


## 墙体一次性绘制：深色实体 + 描边（不用图集瓦片，避免拼接问题）
class WallVisual extends Node2D:
	var wall_tiles: Array[Vector2i] = []
	var _wall_set: Dictionary = {}  # Vector2i -> true，O(1) 查找

	func _ready() -> void:
		_wall_set.clear()
		for t in wall_tiles:
			_wall_set[t] = true

	func _draw() -> void:
		var ts := 32
		var cell := Vector2(ts, ts)
		var wall_col := Color(0.18, 0.16, 0.22)
		var edge_col := Color(0.10, 0.09, 0.14)
		for t in wall_tiles:
			var dest := Rect2(Vector2(t.x * ts, t.y * ts), cell)
			var below := Vector2i(t.x, t.y + 1)
			# 墙顶（下方是地板）用稍亮色，墙身用深色
			if _is_wall(below):
				draw_rect(dest, wall_col, true)
			else:
				draw_rect(dest, Color(0.22, 0.20, 0.27), true)
			draw_rect(dest, edge_col, false, 1.0)

	func _is_wall(t: Vector2i) -> bool:
		return _wall_set.has(t)
