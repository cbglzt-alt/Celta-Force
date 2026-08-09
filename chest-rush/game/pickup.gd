class_name Pickup
extends Area2D
## 掉落物：金币 / 视野道具 / 任务道具。玩家触碰自动拾取。

enum Kind { GOLD, VISION, QUEST }

var kind: Kind
var amount := 0
var fog: Node2D

var _visual: Node2D

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func setup(k: Kind, amt: int, fog_ref: Node2D) -> void:
	kind = k
	amount = amt
	fog = fog_ref
	# 掉落物用 tileset 现成 sprite：金币/蓝瓶(视野)/钥匙(任务)
	var tex_path := ""
	match kind:
		Kind.GOLD:
			tex_path = "res://assets/tiles/gold.png"
		Kind.VISION:
			tex_path = "res://assets/tiles/vision.png"
		Kind.QUEST:
			tex_path = "res://assets/tiles/quest.png"
	_body.visible = false  # 隐藏占位色块
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.scale = Vector2(2.0, 2.0)
	add_child(s)
	_visual = s
	# 呼吸缩放（作用在 sprite 上）
	var tw := create_tween().set_loops()
	tw.tween_property(_visual, "scale", Vector2(2.3, 2.3), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "scale", Vector2(1.8, 1.8), 0.5).set_trans(Tween.TRANS_SINE)


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
