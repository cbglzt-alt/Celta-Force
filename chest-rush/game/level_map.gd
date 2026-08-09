class_name LevelMap
extends Node2D
## 解析 ASCII 地图，生成墙、可摧毁物、撤离点、刷怪点。
## 图例：# 墙(永久挡视野) o 可摧毁障碍(存活时挡视野) C 宝箱
##       E 撤离点 S 刷怪点 P 玩家出生点 . 地板

signal destructible_destroyed(d)

const TILE := 32
const DestructibleScene := preload("res://game/destructible.tscn")

const MAP: Array[String] = [
	"########################################",
	"#P....#....C...#......#....C....#.....E#",
	"#.....#........#..S....#.........#..S..#",
	"#..C...#...o....#......#....o....#.....#",
	"#......#........#..C...#..........#..C.#",
	"#......#....o...#......##.#####........#",
	"#..S...#........####.###.......#....o..#",
	"#......#...C....#......#...C...#.....S.#",
	"#......#........#..o...#.......#.......#",
	"###.####...S...#......#....C..#...C....#",
	"#.....#.........#...C..#o......#.......#",
	"#..C..#....o....#......#....S..#....o..#",
	"#.....#.........##.#####.......#.......#",
	"#.....#....C....#.....o....C...#..C....#",
	"#.o...#.........#..S......o...#......o.#",
	"#.....#####.#####..............#....S..#",
	"#.....#........#....C....S.C..#........#",
	"#......#...C....#...............#......#",
	"#..S...#........#....o......C..#....o..#",
	"#......#....o...#.........#....#.......#",
	"#......#........#...C.....#..S.####.##.#",
	"#......####.#####.........#...........E#",
	"#....o...........C........S......o.....#",
	"########################################",
]

var width: int
var height: int
var walls: Dictionary = {}      # Vector2i -> true
var obstacles: Dictionary = {}  # Vector2i -> Destructible (存活时挡视野)
var chests: Array = []
var spawn_points: Array[Vector2] = []
var player_start := Vector2.ZERO
var exits: Array = []           # Dictionary{area, marker, tile, unlocked}


func _ready() -> void:
	_build()


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


func unlock_exits() -> void:
	for rec in exits:
		rec.unlocked = true
		# 点亮火把：从昏暗转为明亮，并加一圈暖光晕示意"可撤离"
		rec.marker.modulate = Color(1.3, 1.15, 0.7)
		var glow := Polygon2D.new()
		glow.polygon = Player.circle_poly(20.0, 24)
		glow.color = Color(1.0, 0.8, 0.4, 0.22)
		glow.z_index = -1
		rec.marker.add_child(glow)


func _build() -> void:
	height = MAP.size()
	width = MAP[0].length()
	for row in MAP:
		assert(row.length() == width, "地图行宽不一致: %s" % row)

	# 地板：用 dungeon 石板瓦片平铺（替代纯色背景）
	_build_floor()

	var wall_body := StaticBody2D.new()
	wall_body.collision_layer = 4
	wall_body.collision_mask = 0
	var wall_visual := WallVisual.new()

	for y in height:
		for x in width:
			var c := MAP[y][x]
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
					wall_visual.rects.append(Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)))
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
				"E":
					exits.append(_make_exit(center, t))
				"S":
					spawn_points.append(center)
				"P":
					player_start = center

	wall_visual.tex = load("res://assets/tiles/wall_top.png")
	add_child(wall_body)
	add_child(wall_visual)
	_build_decor()  # 装饰层：墙面火把 + 地面杂物（纯视觉，不占格不碰撞）
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
			# 墙与存活障碍不可通行；宝箱可通行（怪可越过）
			if walls.has(t) or (obstacles.get(t) != null and is_instance_valid(obstacles[t])):
				_astar.set_point_disabled(id, true)
	# 连接四方向相邻格
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			var id := _pid(t)
			for off in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = t + off
				if in_bounds(n):
					_astar.connect_points(id, _pid(n))


## 障碍被摧毁后开放该格并重算连通
func notify_walkable_changed(t: Vector2i) -> void:
	_astar.set_point_disabled(_pid(t), false)


## 返回从 from 到 to 的世界坐标路径（含起点），无路径时返回空
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := _pid(world_to_tile(from))
	var b := _pid(world_to_tile(to))
	if not _astar.has_point(a) or not _astar.has_point(b):
		return PackedVector2Array()
	var pts := _astar.get_point_path(a, b)
	return pts


const TORCH_SPRITE := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/items and trap_animation/torch/torch_1.png"


func _make_exit(center: Vector2, t: Vector2i) -> Dictionary:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	cs.shape = shape
	# 撤离门：火把 sprite（熄=锁定暗色，燃=解锁亮起发光）
	var marker := Sprite2D.new()
	marker.texture = load(TORCH_SPRITE)
	marker.scale = Vector2(2.2, 2.2)
	marker.modulate = Color(0.35, 0.35, 0.4)  # 锁定：昏暗
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
		notify_walkable_changed(d.tile)  # 开放该格，怪物可通行
	destructible_destroyed.emit(d)


## 装饰层：墙面火把 + 地面杂物。纯视觉，不占格、不碰撞、不影响寻路/视野。
## 原则：只用"一眼就是环境"的装饰（破砖/碎骨/烛台），禁用道具外形（药水瓶/地刺）以免误导。
const DECOR_DIR := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/items and trap_animation/"
## 墙面火把 / 烛台：4 帧动画（烛火摇曳）
const WALL_TORCH := ["torch/side_torch_1.png", "torch/side_torch_2.png", "torch/side_torch_3.png", "torch/side_torch_4.png"]
const CANDLE := ["torch/candlestick_2_1.png", "torch/candlestick_2_2.png", "torch/candlestick_2_3.png", "torch/candlestick_2_4.png"]
## 地面杂物：破砖/碎骨（单帧）
const FLOOR_PROPS: Array = [
	["res://assets/tiles/debris_a.png"],   # 破砖
	["res://assets/tiles/debris_c.png"],   # 碎骨堆
	CANDLE,                                 # 烛台（动画）
]

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728  # 固定种子：每次进图装饰布局一致（契合固定关卡设定）
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			if not walls.has(t):
				continue
			# 墙面火把：这格是墙、且下方是地板（墙脚）→ 在墙脚插火把
			var below := t + Vector2i(0, 1)
			if in_bounds(below) and not blocks_vision(below) and rng.randf() < 0.16:
				_add_sprite(WALL_TORCH, tile_to_world(t) + Vector2(0, 8), 2.0, 5)
			# 地面杂物：墙格跳过，下面是地板格才撒（稀疏）
	for y in height:
		for x in width:
			var t := Vector2i(x, y)
			if walls.has(t) or obstacles.has(t):
				continue
			# 避开关键格（出生点/宝箱/门/刷怪点所在的明确功能格由字符保证非墙非障碍即可）
			if MAP[y][x] != ".":
				continue
			if rng.randf() < 0.05:
				var pick: Array = FLOOR_PROPS[rng.randi() % FLOOR_PROPS.size()]
				_add_sprite(pick, tile_to_world(t) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), 1.8, -5)


func _add_sprite(frames: Array, pos: Vector2, scale: float, z: int) -> void:
	# 单帧用 Sprite2D，多帧用 AnimatedSprite2D（烛火/火把摇曳）
	var s: Node2D
	if frames.size() > 1:
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		sf.set_animation_speed("idle", 5.0)
		sf.set_animation_loop("idle", true)
		for f in frames:
			var p: String = f if f.begins_with("res://") else DECOR_DIR + f
			sf.add_frame("idle", load(p))
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sf
		anim.play("idle")
		s = anim
	else:
		var sp := Sprite2D.new()
		var single: String = frames[0]
		sp.texture = load(single if single.begins_with("res://") else DECOR_DIR + single)
		s = sp
	s.scale = Vector2(scale, scale)
	s.z_index = z
	add_child(s)
	s.global_position = pos


## 地板：用 dungeon 石板瓦片平铺（放大 2 倍 + 淡网格线），替代纯色背景
func _build_floor() -> void:
	var f := FloorBG.new()
	f.setup(width, height, TILE, load("res://assets/tiles/floor.png"))
	add_child(f)


## 地板：瓦片贴图平铺 + 淡网格
class FloorBG extends Node2D:
	var w: int
	var h: int
	var ts: int
	var tex: Texture2D

	func setup(_w: int, _h: int, _ts: int, _tex: Texture2D) -> void:
		w = _w
		h = _h
		ts = _ts
		tex = _tex
		z_index = -10

	func _draw() -> void:
		# 逐格绘制，draw_texture_rect 拉伸 16px 瓦片到 32px 格
		var cell := Vector2(ts, ts)
		for y in h:
			for x in w:
				draw_texture_rect(tex, Rect2(Vector2(x * ts, y * ts), cell), false)
		# 淡网格线（保持格子可读性）
		var line := Color(0, 0, 0, 0.18)
		for x in w + 1:
			draw_line(Vector2(x * ts, 0), Vector2(x * ts, h * ts), line)
		for y in h + 1:
			draw_line(Vector2(0, y * ts), Vector2(w * ts, y * ts), line)


## 墙体一次性绘制： dungeon 砖纹瓦片 + 深色描边
class WallVisual extends Node2D:
	var rects: Array[Rect2] = []
	var tex: Texture2D

	func _draw() -> void:
		for r in rects:
			if tex:
				draw_texture_rect(tex, r, false)
				draw_rect(r, Color(0, 0, 0, 0.25), false, 1.0)  # 勾边分出格子
			else:
				draw_rect(r, Color("#4a3b52"))
				draw_rect(r, Color("#6b5578"), false, 2.0)
