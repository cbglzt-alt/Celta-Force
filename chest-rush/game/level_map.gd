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
var house_tiles: Dictionary = {}  # Vector2i -> true（房屋占格，掉落物避开）
var tree_tiles: Dictionary = {}   # Vector2i -> true（树占格，掉落物避开）
var spawn_points: Array[Vector2] = []
var player_start := Vector2.ZERO
var exits: Array = []           # Dictionary{area, marker, tile, unlocked}


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


## 俯视深度：Y 越大越靠前。房屋/树/单位共用
func depth_z(world_y: float) -> int:
	return int(world_y)


## 掉落物是否应避开（墙/水/房屋/树/宝箱/障碍）
func is_drop_blocked(world_pos: Vector2) -> bool:
	var t := world_to_tile(world_pos)
	if not in_bounds(t):
		return true
	if walls.has(t) or house_tiles.has(t) or tree_tiles.has(t) or chest_tiles.has(t):
		return true
	var o = obstacles.get(t)
	if o != null and is_instance_valid(o):
		return true
	return false


## 在 origin 附近找可落点，避免金币挂在房/树上
func find_drop_pos(origin: Vector2, radius := 28.0, tries := 12) -> Vector2:
	if not is_drop_blocked(origin):
		return origin
	for i in tries:
		var ang := float(i) * TAU / float(tries) + randf() * 0.4
		var p := origin + Vector2(cos(ang), sin(ang)) * (radius * (0.45 + randf() * 0.55))
		if not is_drop_blocked(p):
			return p
	for dy in [16.0, 28.0, 40.0]:
		var p2 := origin + Vector2(0, dy)
		if not is_drop_blocked(p2):
			return p2
	return origin + Vector2(0, 24)



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

	var wall_body := StaticBody2D.new()
	wall_body.collision_layer = 4
	wall_body.collision_mask = 0

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

	# 官方结构：水面 + 抬升草岛 + 南向石崖
	_build_terrain()
	add_child(wall_body)
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
			if walls.has(t) or chest_tiles.has(t) or (obstacles.get(t) != null and is_instance_valid(obstacles[t])):
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
func _make_house(center: Vector2, t: Vector2i) -> void:
	house_tiles[t] = true
	var body := StaticBody2D.new()
	body.collision_layer = 4  # 底碰撞：挡玩家/召唤物；上/左/右可绕
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 14)
	cs.shape = shape
	cs.position = Vector2(0, 14)
	body.add_child(cs)
	var idx := randi() % Art.HOUSE_VARIANTS.size()
	var sprite := Sprite2D.new()
	sprite.texture = load(Art.HOUSE_VARIANTS[idx])
	sprite.scale = Vector2(0.5, 0.5)
	sprite.offset = Vector2(0, -32)
	sprite.z_as_relative = false
	body.add_child(sprite)
	add_child(body)
	body.global_position = center
	var foot_y := center.y + 14.0
	body.z_index = depth_z(foot_y)
	sprite.z_index = body.z_index


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
	# 岸边装饰：陆地南缘（邻水）散落岩石
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			if walls.has(t):
				continue
			var below := t + Vector2i(0, 1)
			if in_bounds(below) and walls.has(below) and rng.randf() < 0.12:
				var key: String = ["rock1", "rock2", "rock3", "rock4"][rng.randi() % 4]
				_add_ts_decor(key, tile_to_world(t) + Vector2(0, 8), rng)


## 用 tiny-swords 装饰精灵放置地面/墙面装饰
## 树用 4 帧网格动画（Tree.png row0），灌木用缩放呼吸，岩石静态
func _add_ts_decor(key: String, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var path: String = Art.DECOR[key]
	var cell: int = Art.DECOR_CELL.get(key, 64)
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var is_tree := key == "tree"
	var is_bush := key.begins_with("bush")
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
		s.offset = Vector2(0, -8)
		s.z_as_relative = false
		s.play("sway")
		s.frame = rng.randi() % Art.TREE_FRAMES.size()
		s.sprite_frames.set_animation_speed("sway", rng.randf_range(2.5, 4.0))
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(10, 8)
		cs.shape = shape
		cs.position = Vector2(0, 6)
		body.add_child(cs)
		body.add_child(s)
		add_child(body)
		body.global_position = pos
		var tt := world_to_tile(pos)
		tree_tiles[tt] = true
		var foot_y := pos.y + 6.0
		body.z_index = depth_z(foot_y)
		s.z_index = body.z_index
	elif is_bush:
		# 灌木：静态首帧 + 缩放呼吸（帧间偏移太大不能做动画）
		var sprite_tex: Texture2D = tex
		if cell > 0 and tex.get_width() > cell:
			sprite_tex = Art.slice_strip(path, cell, 0)
		var s := Sprite2D.new()
		s.texture = sprite_tex
		s.scale = Vector2(sc, sc)
		s.z_index = -5
		add_child(s)
		s.global_position = pos
		# 轻微缩放呼吸
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "scale", Vector2(sc * 1.08, sc * 1.08), 1.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "scale", Vector2(sc, sc), 1.5).set_trans(Tween.TRANS_SINE)

## 官方宣传图结构：水底 + 草岛 + 南向 elevation 石崖
func _build_terrain() -> void:
	var terrain := TerrainVisual.new()
	terrain.setup(width, height, TILE, walls)
	add_child(terrain)


## 从图集切一格；fill_transparent 时填实，避免透出水/底色
static func _slice_tile(img: Image, g: Vector2i, fill_transparent: bool = true) -> Texture2D:
	if img == null:
		return null
	var src := Rect2i(g.x * Art.SRC_TILE, g.y * Art.SRC_TILE, Art.SRC_TILE, Art.SRC_TILE)
	if not Rect2i(Vector2i.ZERO, img.get_size()).encloses(src):
		return null
	var sub := Image.create(Art.SRC_TILE, Art.SRC_TILE, false, Image.FORMAT_RGBA8)
	sub.blit_rect(img, src, Vector2i.ZERO)
	if not fill_transparent:
		return ImageTexture.create_from_image(sub)
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var sn := 0
	for py in Art.SRC_TILE:
		for px in Art.SRC_TILE:
			var c: Color = sub.get_pixel(px, py)
			if c.a > 0.78:
				sr += c.r
				sg += c.g
				sb += c.b
				sn += 1
	if sn <= 0:
		return ImageTexture.create_from_image(sub)
	var fill := Color(sr / sn, sg / sn, sb / sn, 1.0)
	for py in Art.SRC_TILE:
		for px in Art.SRC_TILE:
			var c2: Color = sub.get_pixel(px, py)
			if c2.a < 0.99:
				if c2.a < 0.05:
					sub.set_pixel(px, py, fill)
				else:
					sub.set_pixel(px, py, Color(c2.r, c2.g, c2.b, 1.0).lerp(fill, 1.0 - c2.a))
	return ImageTexture.create_from_image(sub)


static func _slice_opaque_tile(img: Image, g: Vector2i) -> Texture2D:
	return _slice_tile(img, g, true)


## 地形：大范围水面 + 草岛 + 南向石崖 + 岸边泡沫动画
## 水面向外多铺，避免相机在地图四角看到清空色黑块
class TerrainVisual extends Node2D:
	const WATER_MARGIN := 14
	const FOAM_SCALE := 0.55
	const FOAM_FPS := 10.0

	var w: int
	var h: int
	var ts: int
	var _wall_set: Dictionary = {}
	var _grass: Dictionary = {}
	var _cliff: Dictionary = {}
	var _water: Texture2D
	var _shadow: Texture2D
	var _foam_frames: Array[Texture2D] = []
	var _shore: Array[Vector2i] = []
	var _foam_i: int = 0
	var _foam_acc: float = 0.0

	func setup(_w: int, _h: int, _ts: int, wall_set: Dictionary) -> void:
		w = _w
		h = _h
		ts = _ts
		_wall_set = wall_set
		z_index = -10
		_load_textures()
		_build_shore_list()
		set_process(not _foam_frames.is_empty())
		queue_redraw()

	func _process(delta: float) -> void:
		if _foam_frames.is_empty():
			return
		_foam_acc += delta
		var step := 1.0 / FOAM_FPS
		if _foam_acc < step:
			return
		_foam_acc = fmod(_foam_acc, step)
		_foam_i = (_foam_i + 1) % _foam_frames.size()
		queue_redraw()

	func _load_textures() -> void:
		var water_tex: Texture2D = load(Art.WATER_TEX)
		if water_tex == null:
			water_tex = load(Art.WATER_BG_FREE)
		if water_tex != null:
			var wimg := water_tex.get_image()
			if wimg.get_width() != Art.SRC_TILE or wimg.get_height() != Art.SRC_TILE:
				wimg = wimg.duplicate()
				wimg.resize(Art.SRC_TILE, Art.SRC_TILE, Image.INTERPOLATE_NEAREST)
			_water = ImageTexture.create_from_image(wimg)
			var sh_tex: Texture2D = load(Art.SHADOW_TEX)
			if sh_tex == null:
				sh_tex = load(Art.SHADOW_TEX_FREE)
			if sh_tex != null:
				# Shadows.png 多为 192；缩到约 2 格宽作南侧投影
				var simg := sh_tex.get_image()
				simg = simg.duplicate()
				simg.resize(Art.SRC_TILE * 2, Art.SRC_TILE, Image.INTERPOLATE_NEAREST)
				_shadow = ImageTexture.create_from_image(simg)

		var flat: Texture2D = load(Art.FLAT_ATLAS)
		if flat != null:
			var fimg := flat.get_image()
			var gkeys: Array[Vector2i] = [
				Art.GRASS_CENTER, Art.GRASS_CENTER_ALT,
				Art.GRASS_N, Art.GRASS_S, Art.GRASS_W, Art.GRASS_E,
				Art.GRASS_NW, Art.GRASS_NE, Art.GRASS_SW, Art.GRASS_SE,
				Art.GRASS_W2, Art.GRASS_E2,
			]
			for g in gkeys:
				var fill := g == Art.GRASS_CENTER or g == Art.GRASS_CENTER_ALT
				var tex := LevelMap._slice_tile(fimg, g, fill)
				if tex != null:
					_grass[g] = tex
		# 圆润石柱崖：color1 右下，保留透明（不要填实成方砖）
		var cliff_atlas: Texture2D = load(Art.CLIFF_ATLAS)
		if cliff_atlas == null:
			cliff_atlas = load(Art.COLOR1_ATLAS)
		if cliff_atlas != null:
			var eimg := cliff_atlas.get_image()
			var ckeys: Array[Vector2i] = [
				Art.CLIFF_FACE_L, Art.CLIFF_FACE_C, Art.CLIFF_FACE_C2, Art.CLIFF_FACE_R,
				Art.CLIFF_DEEP_L, Art.CLIFF_DEEP_C, Art.CLIFF_DEEP_C2, Art.CLIFF_DEEP_R,
			]
			for g in ckeys:
				var tex2 := LevelMap._slice_tile(eimg, g, false)
				if tex2 != null:
					_cliff[g] = tex2
		# Foam.png 是圆形水花环；整格贴会变白方块。
		# 只切环的下弧，做成贴在石崖底边的横向水波条。
		var foam_tex: Texture2D = load(Art.WATER_FOAM)
		if foam_tex != null:
			var fimg2 := foam_tex.get_image()
			var cell := Art.FOAM_CELL
			var n: int = mini(Art.FOAM_FRAMES, int(fimg2.get_width() / maxi(cell, 1)))
			# 圆环最外下缘（更贴水面的细白浪）
			var src_x := 48
			var src_y := 120
			var src_w := 96
			var src_h := 24
			for i in n:
				var sub := Image.create(src_w, src_h, false, Image.FORMAT_RGBA8)
				sub.blit_rect(fimg2, Rect2i(i * cell + src_x, src_y, src_w, src_h), Vector2i.ZERO)
				# 去掉过淡像素，只留明显白浪
				for py in src_h:
					for px in src_w:
						var c: Color = sub.get_pixel(px, py)
						if c.a < 0.20:
							sub.set_pixel(px, py, Color(0, 0, 0, 0))
						elif c.a < 0.45 and c.r < 0.75:
							sub.set_pixel(px, py, Color(0, 0, 0, 0))
				_foam_frames.append(ImageTexture.create_from_image(sub))

	func _build_shore_list() -> void:
		_shore.clear()
		# 只在「陆地正南」的水格（石崖底边）放水波，不要四面乱贴
		for y in h:
			for x in w:
				var t := Vector2i(x, y)
				if not _is_water(t):
					continue
				if _is_land(Vector2i(x, y - 1)):
					_shore.append(t)
		# 地图最底边陆地：界外下一格也算崖底波
		for x in w:
			if _is_land(Vector2i(x, h - 1)):
				_shore.append(Vector2i(x, h))

	func _is_land(t: Vector2i) -> bool:
		if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
			return false
		return not _wall_set.has(t)

	func _is_water(t: Vector2i) -> bool:
		if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
			return true
		return _wall_set.has(t)

	func _pick_grass(t: Vector2i) -> Vector2i:
		var n := _is_land(Vector2i(t.x, t.y - 1))
		var e := _is_land(Vector2i(t.x + 1, t.y))
		var s := _is_land(Vector2i(t.x, t.y + 1))
		var ww := _is_land(Vector2i(t.x - 1, t.y))
		if not n and not ww and e and s:
			return Art.GRASS_NW
		if not n and not e and ww and s:
			return Art.GRASS_NE
		if not s and not ww and e and n:
			return Art.GRASS_SW
		if not s and not e and ww and n:
			return Art.GRASS_SE
		if not n and e and s and ww:
			return Art.GRASS_N
		if not s and n and e and ww:
			return Art.GRASS_S
		if not ww and n and e and s:
			return Art.GRASS_W if ((t.x + t.y) & 1) == 0 else Art.GRASS_W2
		if not e and n and ww and s:
			return Art.GRASS_E if ((t.x + t.y) & 1) == 0 else Art.GRASS_E2
		if not n and not ww:
			return Art.GRASS_NW
		if not n and not e:
			return Art.GRASS_NE
		if not s and not ww:
			return Art.GRASS_SW
		if not s and not e:
			return Art.GRASS_SE
		if not n:
			return Art.GRASS_N
		if not s:
			return Art.GRASS_S
		if not ww:
			return Art.GRASS_W
		if not e:
			return Art.GRASS_E
		if ((t.x * 3 + t.y * 7) & 1) == 0:
			return Art.GRASS_CENTER
		return Art.GRASS_CENTER_ALT

	func _pick_cliff_face(water_t: Vector2i) -> Vector2i:
		var y := water_t.y
		var left := water_t.x
		while true:
			var p := Vector2i(left - 1, y)
			var north := Vector2i(left - 1, y - 1)
			if not _is_water(p) or not _is_land(north):
				break
			left -= 1
		var right := water_t.x
		while true:
			var p2 := Vector2i(right + 1, y)
			var north2 := Vector2i(right + 1, y - 1)
			if not _is_water(p2) or not _is_land(north2):
				break
			right += 1
		var length := right - left + 1
		var idx := water_t.x - left
		var seq: Array[Vector2i] = [
			Art.CLIFF_FACE_L, Art.CLIFF_FACE_C, Art.CLIFF_FACE_C2, Art.CLIFF_FACE_R
		]
		if length <= 1:
			return seq[1]
		if length == 2:
			return seq[0] if idx == 0 else seq[3]
		if idx == 0:
			return seq[0]
		if idx == length - 1:
			return seq[3]
		var mid: Array[Vector2i] = [seq[1], seq[2]]
		return mid[(idx - 1) % 2]

	func _pick_cliff_deep(water_t: Vector2i) -> Vector2i:
		var face := _pick_cliff_face(Vector2i(water_t.x, water_t.y - 1))
		if face == Art.CLIFF_FACE_L:
			return Art.CLIFF_DEEP_L
		if face == Art.CLIFF_FACE_R:
			return Art.CLIFF_DEEP_R
		if face == Art.CLIFF_FACE_C2:
			return Art.CLIFF_DEEP_C2
		return Art.CLIFF_DEEP_C

	func _draw() -> void:
		var cell := Vector2(ts, ts)
		var m := WATER_MARGIN
		# 1) 大范围水面（含地图外），消灭四角黑块
		if _water != null:
			for y in range(-m, h + m):
				for x in range(-m, w + m):
					draw_texture_rect(_water, Rect2(Vector2(x * ts, y * ts), cell), false)
		else:
			draw_rect(Rect2(Vector2(-m * ts, -m * ts), Vector2((w + m * 2) * ts, (h + m * 2) * ts)), Color(0.28, 0.67, 0.66), true)

		# 2) 抬升阴影（tinyswords：阴影在可走面南侧一格）
		if _shadow != null:
			var sw := float(ts) * 1.55
			var sh := float(ts) * 0.80
			for y in h:
				for x in w:
					if not _is_land(Vector2i(x, y)):
						continue
					if _is_water(Vector2i(x, y + 1)):
						var sx := float(x * ts) + (float(ts) - sw) * 0.5
						var sy := float((y + 1) * ts) - sh * 0.20
						draw_texture_rect(_shadow, Rect2(sx, sy, sw, sh), false)

		# 3) 陆地草地
		var gcenter: Texture2D = _grass.get(Art.GRASS_CENTER, null)
		for y in h:
			for x in w:
				var t := Vector2i(x, y)
				if not _is_land(t):
					continue
				var gk: Vector2i = _pick_grass(t)
				var gtex: Texture2D = _grass.get(gk, gcenter)
				if gtex != null:
					draw_texture_rect(gtex, Rect2(Vector2(x * ts, y * ts), cell), false)

		# 4) 南向石崖
		for y in h:
			for x in w:
				var t2 := Vector2i(x, y)
				if not _is_water(t2):
					continue
				var north := Vector2i(x, y - 1)
				if _is_land(north):
					var ck: Vector2i = _pick_cliff_face(t2)
					var ctex: Texture2D = _cliff.get(ck, null)
					if ctex != null:
						draw_texture_rect(ctex, Rect2(Vector2(x * ts, y * ts), cell), false)
				elif y >= 1:
					var n2 := Vector2i(x, y - 1)
					var n3 := Vector2i(x, y - 2)
					if _is_water(n2) and _is_land(n3):
						var dk: Vector2i = _pick_cliff_deep(t2)
						var dtex: Texture2D = _cliff.get(dk, null)
						if dtex != null:
							draw_texture_rect(dtex, Rect2(Vector2(x * ts, y * ts), cell), false)

		# 5) 石崖最底边与水面相交处的白色水波（不要画在崖身中间）
		if not _foam_frames.is_empty() and not _shore.is_empty():
			var wave_h := float(ts) * 0.26
			var wave_w := float(ts) * 1.10
			for s in _shore:
				var phase: int = int(absi(s.x * 3 + s.y * 5)) % _foam_frames.size()
				var fi: int = (_foam_i + phase) % _foam_frames.size()
				var ft: Texture2D = _foam_frames[fi]
				# 主崖画在 s；若 s 正南还有加深崖，底边下移一格
				var bottom_row := s.y
				var deep := Vector2i(s.x, s.y + 1)
				if deep.y < h and _is_water(deep) and _is_land(Vector2i(s.x, s.y - 1)):
					# 与 _draw 加深崖条件一致：face 在 s，deep 在 s 南
					bottom_row = s.y + 1
				# 浪中心贴在石柱底缘（格底略上），大部分在水面里
				var cx := float(s.x * ts) + (float(ts) - wave_w) * 0.5
				var cy := float(bottom_row * ts) + float(ts) - wave_h * 0.55
				draw_texture_rect(ft, Rect2(cx, cy, wave_w, wave_h), false)
