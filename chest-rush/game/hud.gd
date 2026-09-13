extends CanvasLayer
## 代码构建的灰盒 HUD：状态栏、强化栏、倒计时、横幅、结算面板。

var game: Node2D
var _font: Font

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
var _result_button: Button
var _level_label: Label

var _ui_scale := 1.0  # 手机端按物理宽度反放大 UI
var _pending_message := ""  # UI 构建前收到的消息，构建后重放


func _ready() -> void:
	# 暂停时仍需处理 R 键重启/下一关
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Web 端无系统字体，优先用随包子集字体（Noto Sans SC，OFL 许可）
	_font = load("res://game/fonts/NotoSansSC-Subset.otf")
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(
			["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "sans-serif"])
		_font = sf
	# Web 上引擎启动时窗口尺寸可能未定，延迟到首帧后再计算缩放
	await get_tree().process_frame
	_ui_scale = _calc_ui_scale()
	_build_ui()
	if _pending_message != "":
		message(_pending_message)
		_pending_message = ""
	if game != null:
		refresh()
	# 窗口尺寸变化（旋转/拉伸）时重新计算并重建 UI
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	await get_tree().process_frame
	var s := _calc_ui_scale()
	if absf(s - _ui_scale) < 0.05:
		return
	_ui_scale = s
	# 重建 UI（清掉旧节点再构建，保证字号/位置按新系数生效）
	for c in get_children():
		c.queue_free()
	_build_ui()
	setup(game)


## 手机端画布被整体缩小（如 1280 逻辑宽缩到 ~390 CSS 宽），UI 需按画布
## 实际渲染缩放反放大，保证最小字体物理尺寸 ≥12px。桌面窗口不缩小则保持 1.0。
## 用 viewport 的 canvas_transform 直接读渲染缩放——比 DisplayServer 窗口
## API 可靠（后者在 Web/headless 下返回值不稳定，甚至含 devicePixelRatio）。
func _calc_ui_scale() -> float:
	var s := get_viewport().get_canvas_transform().get_scale().x
	if s <= 0.0:
		return 1.0
	return clampf(1.0 / s, 1.0, 4.0)


func setup(g: Node2D) -> void:
	game = g
	if _hp_text == null:
		return  # UI 尚未构建（_ready 在等首帧），构建完成后会刷新
	refresh()


func refresh() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	if _level_label != null:
		_level_label.text = "第 %d/%d 关 · %s" % [game.current_level + 1, game.level_total, game.level_name]
	_hp_text.text = "HP %d/%d" % [maxi(int(p.hp), 0), int(p.max_hp)]
	p.refresh_hp_bar()
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
	if _banner == null:
		# UI 尚未构建（_ready 在等首帧），缓存消息待构建后重放
		_pending_message = text
		return
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


func show_result(win: bool, title: String, stats: String, button_text := "重新开始 (R)") -> void:
	_result_title.text = title
	_result_title.add_theme_color_override(
		"font_color", Color("#4ade80") if win else Color("#f87171"))
	_result_stats.text = stats
	_countdown_label.visible = false
	_result_panel.visible = true
	# 更新按钮文字
	if _result_button != null:
		_result_button.text = button_text


func _input(event: InputEvent) -> void:
	if game != null and game.over and event.is_action_pressed("restart"):
		_restart()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------- UI 构建 ----------

func _build_ui() -> void:
	var s: float = _ui_scale
	# 左上：关卡名 / HP 数值 / 金币 / 任务
	var tl := VBoxContainer.new()
	tl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(14 * s, 10 * s)
	tl.add_theme_constant_override("separation", int(4 * s))
	add_child(tl)
	_level_label = _mk_label(tl, "", 14)
	_level_label.add_theme_color_override("font_color", Color("#93c5fd"))
	_hp_text = _mk_label(tl, "HP", 14)
	_gold_label = _mk_label(tl, "", 16)
	_gold_label.add_theme_color_override("font_color", Color("#facc15"))
	_quest_label = _mk_label(tl, "", 16)
	_quest_label.add_theme_color_override("font_color", Color("#e879f9"))

	# 右上：波次 / 时间 / 视野
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-200 * s, 10 * s)
	tr.add_theme_constant_override("separation", int(4 * s))
	add_child(tr)
	_round_label = _mk_label(tr, "", 16)
	_time_label = _mk_label(tr, "", 16)
	_vision_label = _mk_label(tr, "", 14)

	# ---- 左下：技能栏（SmallBlueRoundButton 背景 + 图标 + 文字）----
	var skill_panel := PanelContainer.new()
	skill_panel.add_theme_stylebox_override("panel", _mk_tex_style(Art.UI_PANEL_9, 64))
	skill_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	skill_panel.position = Vector2(8 * s, -64 * s)
	skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_panel)
	var ghosts := HBoxContainer.new()
	ghosts.add_theme_constant_override("separation", int(6 * s))
	skill_panel.add_child(ghosts)
	var icon_keys := ["Regular_01.png", "Regular_02.png", "Regular_03.png"]
	for i in 3:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", _mk_tex_style(Art.UI_SKILL_BTN, 32))
		slot.custom_minimum_size = Vector2(44 * s, 44 * s)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghosts.add_child(slot)
		var slot_h := HBoxContainer.new()
		slot_h.add_theme_constant_override("separation", int(3 * s))
		slot_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(slot_h)
		var icon := TextureRect.new()
		icon.texture = load(Art.UI_ICONS_DIR + icon_keys[i])
		icon.custom_minimum_size = Vector2(20 * s, 20 * s)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		slot_h.add_child(icon)
		var l := _mk_label(slot_h, "", 13)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ghost_labels.append(l)

	# ---- 右下：强化栏（SmallBlueSquareButton 背景 + 文字）----
	var up_panel := PanelContainer.new()
	up_panel.add_theme_stylebox_override("panel", _mk_tex_style(Art.UI_PANEL_9, 64))
	up_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	up_panel.position = Vector2(-200 * s, -100 * s)
	up_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(up_panel)
	var up_vb := VBoxContainer.new()
	up_vb.add_theme_constant_override("separation", int(3 * s))
	up_panel.add_child(up_vb)
	for key in ["attack", "speed", "hp"]:
		var up_slot := PanelContainer.new()
		up_slot.add_theme_stylebox_override("panel", _mk_tex_style(Art.UI_UP_BTN_BLUE, 32))
		up_slot.custom_minimum_size = Vector2(180 * s, 26 * s)
		up_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		up_vb.add_child(up_slot)
		_up_labels[key] = _mk_label(up_slot, "", 14)
		_up_labels[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_up_labels[key].vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 顶部中央：撤离倒计时
	_countdown_label = _mk_label(self, "", 34)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_countdown_label.custom_minimum_size = Vector2(600 * s, 50 * s)
	_countdown_label.position = Vector2(-300 * s, 6 * s)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color("#f87171"))
	_countdown_label.visible = false

	# 中央横幅
	_banner = _mk_label(self, "", 26)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.custom_minimum_size = Vector2(800 * s, 60 * s)
	_banner.position = Vector2(-400 * s, -160 * s)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Color("#fde68a"))
	_banner.add_theme_constant_override("outline_size", int(6 * s))
	_banner.modulate.a = 0.0

	# 全屏大字警告
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

	_build_result_panel()


func _build_result_panel() -> void:
	_result_panel = ColorRect.new()
	_result_panel.color = Color(0, 0, 0, 0.78)
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	add_child(_result_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(center)
	# 用 Banner_Horizontal 做面板背景
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _mk_tex_style(Art.UI_BANNER_H, 64))
	panel.custom_minimum_size = Vector2(480 * _ui_scale, 320 * _ui_scale)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(16 * _ui_scale))
	panel.add_child(vb)
	_result_title = _mk_label(vb, "", 44)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_stats = _mk_label(vb, "", 20)
	_result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _mk_label(vb, "按 R 重新开始", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 用 Button_Blue_9Slides 做按钮背景
	var btn := Button.new()
	btn.text = "重新开始 (R)"
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", maxi(12, int(round(20 * _ui_scale))))
	btn.add_theme_stylebox_override("normal", _mk_tex_style(Art.UI_BTN_BLUE_9, 64))
	btn.add_theme_stylebox_override("hover", _mk_tex_style(Art.UI_BTN_HOVER_9, 64))
	btn.add_theme_stylebox_override("pressed", _mk_tex_style(Art.UI_BTN_HOVER_9, 64))
	btn.pressed.connect(_restart)
	vb.add_child(btn)
	_result_button = btn


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
	l.add_theme_font_size_override("font_size", maxi(12, int(round(size * _ui_scale))))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", maxi(3, int(round(4 * _ui_scale))))
	parent.add_child(l)
	return l


## 9-slice 面板样式：纹理边框保持 64px 不变形，内容边距只用 4px
func _mk_tex_style(tex_path: String, border: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(tex_path)
	sb.set_texture_margin(SIDE_LEFT, border)
	sb.set_texture_margin(SIDE_RIGHT, border)
	sb.set_texture_margin(SIDE_TOP, border)
	sb.set_texture_margin(SIDE_BOTTOM, border)
	# 关键：显式设置小内容边距，否则默认=texture_margin(64px) 会导致面板过大
	sb.set_content_margin_all(maxi(2, int(round(4 * _ui_scale))))
	return sb
