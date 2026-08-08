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
		rec.marker.color = Color("#22c55e")


func _build() -> void:
	height = MAP.size()
	width = MAP[0].length()
	for row in MAP:
		assert(row.length() == width, "地图行宽不一致: %s" % row)

	var bg := GridBG.new()
	bg.setup(width, height, TILE)
	add_child(bg)

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

	add_child(wall_body)
	add_child(wall_visual)
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


func _make_exit(center: Vector2, t: Vector2i) -> Dictionary:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE - 4, TILE - 4)
	cs.shape = shape
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)])
	marker.color = Color("#7f1d1d")
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


## 地板与网格线
class GridBG extends Node2D:
	var w: int
	var h: int
	var ts: int

	func setup(_w: int, _h: int, _ts: int) -> void:
		w = _w
		h = _h
		ts = _ts
		z_index = -10

	func _draw() -> void:
		draw_rect(Rect2(0, 0, w * ts, h * ts), Color("#262a35"))
		var line := Color("#2f3442")
		for x in w + 1:
			draw_line(Vector2(x * ts, 0), Vector2(x * ts, h * ts), line)
		for y in h + 1:
			draw_line(Vector2(0, y * ts), Vector2(w * ts, y * ts), line)


## 墙体一次性绘制
class WallVisual extends Node2D:
	var rects: Array[Rect2] = []

	func _draw() -> void:
		for r in rects:
			draw_rect(r, Color("#5b6472"))
			draw_rect(r, Color("#6e7787"), false, 2.0)
