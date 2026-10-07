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
						_make_anim_pickup(Art.GOLD_CHEST_HL, 128, base_scale, true)
					else:
						_make_static_pickup(Art.GOLD_CHEST_TEX, base_scale)
				"monster":
					# 怪物金币：G_Spawn 只播一次落地，停在最后一帧
					_make_anim_pickup(Art.GOLD_MONSTER_TEX, 128, base_scale * 0.8, false)
				"obstacle":
					var obs_tex := Art.GOLD_OBSTACLE_TEX if randf() < 0.6 else Art.GOLD_OBSTACLE_TEX2
					_make_static_pickup(obs_tex, base_scale)
				_:
					_make_static_pickup(Art.GOLD_CHEST_TEX, base_scale)
		Kind.VISION:
			_make_static_pickup(Art.VISION_PICKUP, base_scale)
		Kind.QUEST:
			_make_static_pickup(Art.QUEST_PICKUP, base_scale)
	# 怪物金币：播完再生效轻微呼吸；其它立即呼吸
	if gold_source == "monster" and _visual is AnimatedSprite2D:
		var anim := _visual as AnimatedSprite2D
		if not anim.animation_finished.is_connected(_on_monster_spawn_finished):
			anim.animation_finished.connect(_on_monster_spawn_finished, CONNECT_ONE_SHOT)
	else:
		_start_breath(_visual)


func _on_monster_spawn_finished() -> void:
	if _visual is AnimatedSprite2D:
		var anim := _visual as AnimatedSprite2D
		if anim.sprite_frames != null:
			var last := maxi(anim.sprite_frames.get_frame_count(anim.animation) - 1, 0)
			anim.frame = last
			anim.pause()
		_start_breath(anim)


func _start_breath(node: Node2D) -> void:
	if node == null:
		return
	var breath_sc := node.scale.x
	var tw := create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(breath_sc * 1.15, breath_sc * 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2(breath_sc * 0.85, breath_sc * 0.85), 0.5).set_trans(Tween.TRANS_SINE)


func _make_static_pickup(tex_path: String, sc: float) -> void:
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.scale = Vector2(sc, sc)
	add_child(s)
	_visual = s


## loop=false：只播一次（怪物落地），停在最后一帧
func _make_anim_pickup(strip_path: String, cell: int, sc: float, loop := true) -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 10.0 if not loop else 8.0)
	sf.set_animation_loop("idle", loop)
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
	add_child(s)
	s.play("idle")
	if not loop:
		var frames := sf.get_frame_count("idle")
		if frames > 0:
			var dur := float(frames) / maxf(sf.get_animation_speed("idle"), 0.01)
			# 兜底：部分平台 animation_finished 不稳，到时强制停末帧
			get_tree().create_timer(dur).timeout.connect(
				func() -> void:
					if is_instance_valid(s) and s.is_playing():
						s.frame = maxi(frames - 1, 0)
						s.pause()
						_start_breath(s)
			, CONNECT_ONE_SHOT)
	_visual = s


func _process(_delta: float) -> void:
	z_as_relative = false
	z_index = int(global_position.y)
	if fog != null:
		visible = fog.is_visible_world(global_position)
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
