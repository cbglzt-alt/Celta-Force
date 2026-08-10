extends CanvasLayer
## 代码构建的灰盒 HUD：状态栏、强化栏、倒计时、横幅、结算面板。

var game: Node2D
var _font: Font

var _hp_fg: ColorRect
var _hp_text: Label
var _gold_label: Label
var _quest_label: Label
var _round_label: Label
var _time_label: Label
var _vision_label: Label
var _up_labels := {}
var _ghost_labels: Array = []
var _countdown_label: Label
var _banner: Label
var _banner_tween: Tween
var _alert_root: Control
var _alert: Label
var _alert_tween: Tween
var _result_panel: ColorRect
var _result_title: Label
var _result_stats: Label


func _ready() -> void:
	# Web 端无系统字体，优先用随包子集字体（Noto Sans SC，OFL 许可）
	_font = load("res://game/fonts/NotoSansSC-Subset.otf")
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(
			["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "sans-serif"])
		_font = sf
	_build_ui()


func setup(g: Node2D) -> void:
	game = g
	refresh()


func refresh() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	_hp_fg.size.x = 210.0 * clampf(p.hp / p.max_hp, 0.0, 1.0)
	_hp_text.text = "HP %d/%d" % [maxi(int(p.hp), 0), int(p.max_hp)]
	_gold_label.text = "金币 %d" % game.gold
	_quest_label.text = "任务道具 %d/%d" % [game.quest_items, game.quest_target]
	if game.extract_running():
		_round_label.text = "波次 %d" % game.round_num
	else:
		_round_label.text = "波次 %d（下波 %ds）" % [game.round_num, int(ceil(game.round_time_left()))]
	var t := int(game.run_time)
	_time_label.text = "时间 %02d:%02d" % [t / 60, t % 60]
	_vision_label.text = "视野道具 x%d（Q 使用） 视野半径 %d" % [game.vision_items, game.vision_radius()]
	_refresh_upgrade("attack", "[1] 攻击")
	_refresh_upgrade("speed", "[2] 移速")
	_refresh_upgrade("hp", "[3] 生命上限")
	# 3 只鬼槽位：颜色 + 名字 + 伤害
	for i in mini(_ghost_labels.size(), p.weapons.size()):
		var w = p.weapons[i]
		var l: Label = _ghost_labels[i]
		l.text = "%s %d" % [w.data.display_name, int(w.data.damage * w.damage_mult)]
		l.add_theme_color_override("font_color", w.data.color)
	if _countdown_label.visible and game.extract_running():
		_countdown_label.text = "撤离倒计时 %.1f" % game.extract_time_left()


func message(text: String, duration := 2.2) -> void:
	_banner.text = text
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


## 全屏大字警告（精英刷出等强提示）
func alert_big(text: String, duration := 2.8) -> void:
	_alert.text = text
	if _alert_tween and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_root.visible = true
	_alert_root.modulate = Color(1, 1, 1, 1)
	_alert.modulate = Color(1, 1, 1, 0)
	_alert.scale = Vector2(0.85, 0.85)
	# 等一帧让布局算好 pivot，避免缩放到屏幕外
	await get_tree().process_frame
	if not is_instance_valid(_alert):
		return
	_alert.pivot_offset = _alert.size * 0.5
	_alert_tween = create_tween()
	_alert_tween.set_parallel(true)
	_alert_tween.tween_property(_alert, "modulate:a", 1.0, 0.2)
	_alert_tween.tween_property(_alert, "scale", Vector2(1.05, 1.05), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_alert_tween.chain().set_parallel(false)
	_alert_tween.tween_property(_alert, "scale", Vector2.ONE, 0.12)
	_alert_tween.tween_interval(duration)
	_alert_tween.tween_property(_alert, "modulate:a", 0.0, 0.5)
	_alert_tween.tween_callback(func():
		if is_instance_valid(_alert_root):
			_alert_root.visible = false
	)


func set_countdown_visible(v: bool) -> void:
	_countdown_label.visible = v


func show_result(win: bool, title: String, stats: String) -> void:
	_result_title.text = title
	_result_title.add_theme_color_override(
		"font_color", Color("#4ade80") if win else Color("#f87171"))
	_result_stats.text = stats
	_countdown_label.visible = false
	_result_panel.visible = true


func _input(event: InputEvent) -> void:
	if game != null and game.over and event.is_action_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------- UI 构建 ----------

func _build_ui() -> void:
	# 左上：HP / 金币 / 任务
	var tl := VBoxContainer.new()
	tl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(14, 10)
	tl.add_theme_constant_override("separation", 4)
	add_child(tl)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color("#3f3f46")
	hp_bg.custom_minimum_size = Vector2(210, 20)
	tl.add_child(hp_bg)
	_hp_fg = ColorRect.new()
	_hp_fg.color = Color("#22c55e")
	_hp_fg.size = Vector2(210, 20)
	hp_bg.add_child(_hp_fg)
	_hp_text = _mk_label(tl, "HP", 14)
	_gold_label = _mk_label(tl, "", 16)
	_gold_label.add_theme_color_override("font_color", Color("#facc15"))
	_quest_label = _mk_label(tl, "", 16)
	_quest_label.add_theme_color_override("font_color", Color("#e879f9"))

	# 3 只鬼槽位（左中）
	var ghosts := HBoxContainer.new()
	ghosts.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	ghosts.grow_vertical = Control.GROW_DIRECTION_BOTH
	ghosts.position = Vector2(14, -30)
	ghosts.add_theme_constant_override("separation", 16)
	add_child(ghosts)
	for i in 3:
		_ghost_labels.append(_mk_label(ghosts, "", 16))

	# 右上：波次 / 时间
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-180, 10)
	tr.add_theme_constant_override("separation", 4)
	add_child(tr)
	_round_label = _mk_label(tr, "", 16)
	_time_label = _mk_label(tr, "", 16)

	# 左下：强化
	var bl := HBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bl.position = Vector2(14, -40)
	bl.add_theme_constant_override("separation", 24)
	add_child(bl)
	_up_labels["attack"] = _mk_label(bl, "", 15)
	_up_labels["speed"] = _mk_label(bl, "", 15)
	_up_labels["hp"] = _mk_label(bl, "", 15)

	# 右下：视野
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br.position = Vector2(-280, -40)
	add_child(br)
	_vision_label = _mk_label(br, "", 15)

	# 顶部中央：撤离倒计时
	_countdown_label = _mk_label(self, "", 34)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_countdown_label.custom_minimum_size = Vector2(600, 50)
	_countdown_label.position = Vector2(-300, 6)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color("#f87171"))
	_countdown_label.visible = false

	# 中央横幅
	_banner = _mk_label(self, "", 26)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.custom_minimum_size = Vector2(800, 60)
	_banner.position = Vector2(-400, -120)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Color("#fde68a"))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.modulate.a = 0.0

	# 全屏大字警告：用满屏 CenterContainer，避免锚点 Label 尺寸为 0 画不出来
	_alert_root = Control.new()
	_alert_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alert_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_root.visible = false
	_alert_root.z_index = 40
	add_child(_alert_root)
	var alert_center := CenterContainer.new()
	alert_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_root.add_child(alert_center)
	_alert = _mk_label(alert_center, "", 52)
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert.add_theme_color_override("font_color", Color("#f0abfc"))
	_alert.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.18, 1))
	_alert.add_theme_constant_override("outline_size", 14)

	_build_result_panel()


func _build_result_panel() -> void:
	_result_panel = ColorRect.new()
	_result_panel.color = Color(0, 0, 0, 0.72)
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	add_child(_result_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	_result_title = _mk_label(vb, "", 44)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_stats = _mk_label(vb, "", 20)
	_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _mk_label(vb, "按 R 重新开始", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "重新开始 (R)"
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_restart)
	vb.add_child(btn)


func _refresh_upgrade(track: String, label: String) -> void:
	var l: Label = _up_labels[track]
	var lv: int = game.up_levels[track]
	if lv >= game.upgrade_max_level:
		l.text = "%s Lv.%d 满级" % [label, lv]
		l.add_theme_color_override("font_color", Color("#9ca3af"))
	else:
		var c: int = game.upgrade_cost(track)
		l.text = "%s Lv.%d $%d" % [label, lv, c]
		l.add_theme_color_override("font_color",
			Color("#4ade80") if game.gold >= c else Color("#9ca3af"))


func _mk_label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l
