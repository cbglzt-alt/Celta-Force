class_name Pickup
extends Area2D
## 掉落物：金币 / 视野道具 / 任务道具。玩家触碰自动拾取。

enum Kind { GOLD, VISION, QUEST }

var kind: Kind
var amount := 0
var fog: Node2D

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	# 呼吸缩放
	var tw := create_tween().set_loops()
	tw.tween_property(_body, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_body, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_SINE)


func setup(k: Kind, amt: int, fog_ref: Node2D) -> void:
	kind = k
	amount = amt
	fog = fog_ref
	match kind:
		Kind.GOLD:
			_body.polygon = Player.circle_poly(7.0, 8)
			_body.color = Color("#facc15")
		Kind.VISION:
			_body.polygon = PackedVector2Array([
				Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
			_body.color = Color("#22d3ee")
		Kind.QUEST:
			_body.polygon = _star_poly(11.0, 5.0)
			_body.color = Color("#e879f9")


func _process(_delta: float) -> void:
	if fog != null:
		visible = fog.is_visible_world(global_position)
	# 兜底：玩家站定开箱时，已在拾取范围内的新生掉落需主动吸附（body_entered 不重触发）
	# 半径需 > 玩家贴箱最近距离（碰撞13+箱半宽~20）+ 金币偏移，约 45px
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.alive and global_position.distance_to(p.global_position) < 45.0:
		var game = get_tree().get_first_node_in_group("game")
		if game:
			game.collect(self)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.collect(self)
	queue_free()


func _star_poly(r1: float, r2: float, points := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r1 if i % 2 == 0 else r2
		var a := -PI / 2 + PI * i / points
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
