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


func setup(k: Kind, amt: int, fog_ref: Node2D, gold_source := "") -> void:
	kind = k
	amount = amt
	fog = fog_ref
	_body.visible = false
	var base_scale := 0.4
	match kind:
		Kind.GOLD:
			match gold_source:
				"chest":
					# 宝箱金币：Gold Stone 3 + 高光动画
					var hl_tex := load(Art.GOLD_CHEST_HL)
					if hl_tex and hl_tex.get_width() > 128:
						# 动画条带 768×128 = 6帧
						_make_anim_pickup(Art.GOLD_CHEST_HL, 128, base_scale)
					else:
						_make_static_pickup(Art.GOLD_CHEST_TEX, base_scale)
				"monster":
					# 怪物金币：G_Spawn 动画 896×128 = 7帧
					_make_anim_pickup(Art.GOLD_MONSTER_TEX, 128, base_scale * 0.8)
				"obstacle":
					# 障碍金币：Gold Stone 2 或 1（静态，随机）
					var obs_tex := Art.GOLD_OBSTACLE_TEX if randf() < 0.6 else Art.GOLD_OBSTACLE_TEX2
					_make_static_pickup(obs_tex, base_scale)
				_:
					_make_static_pickup(Art.GOLD_CHEST_TEX, base_scale)
		Kind.VISION:
			_make_static_pickup(Art.VISION_PICKUP, base_scale)
		Kind.QUEST:
			_make_static_pickup(Art.QUEST_PICKUP, base_scale)
	# 呼吸缩放
	var breath_sc := _visual.scale.x
	var tw := create_tween().set_loops()
	tw.tween_property(_visual, "scale", Vector2(breath_sc * 1.15, breath_sc * 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_visual, "scale", Vector2(breath_sc * 0.85, breath_sc * 0.85), 0.5).set_trans(Tween.TRANS_SINE)


func _make_static_pickup(tex_path: String, sc: float) -> void:
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.scale = Vector2(sc, sc)
	add_child(s)
	_visual = s


func _make_anim_pickup(strip_path: String, cell: int, sc: float) -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 8.0)
	sf.set_animation_loop("idle", true)
	var tex: Texture2D = load(strip_path)
	if tex and tex.get_width() > cell:
		var n := int(tex.get_width() / cell)
		for i in n:
			var ft := Art.slice_strip(strip_path, cell, i)
			if ft:
				sf.add_frame("idle", ft)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.scale = Vector2(sc, sc)
	s.play("idle")
	add_child(s)
	_visual = s


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
