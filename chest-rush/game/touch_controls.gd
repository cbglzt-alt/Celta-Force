class_name TouchControls
extends CanvasLayer
## 移动端触控层：动态虚拟摇杆（屏幕任意位置按下出现）+ 购买/视野触摸按钮。
## 纯代码构建，风格与 hud.gd 一致；仅触屏设备启用，键盘/鼠标输入完全不受影响。
##
## 设计：
## - 摇杆：下半屏任意位置按下 → 该处生成底盘+摇杆头；拖动输出方向（0~1 力度）；
##   松手消失。player.gd 优先读取 move_dir，无触摸时回退键盘。
## - 按钮：右侧竖排 3 购买键（攻/速/命）+ 视野键，按下直接调 game._buy / _use_vision。
## - 按钮区域按下不会触发摇杆（_point_on_button 排除）。

## 当前摇杆方向（0~1 力度，未激活为 ZERO）。player.gd 优先读它。
static var move_dir := Vector2.ZERO
## 是否处于触控模式（有触屏硬件或触摸平台）
static var active := false

const JOY_RADIUS := 64.0      # 摇杆底盘半径
const KNOB_RADIUS := 26.0     # 摇杆头半径
const DEAD_ZONE := 0.12       # 摇杆死区（避免轻微抖动）

var _joy_index := -1          # 摇杆占用的手指 index（-1 = 空闲）
var _joy_origin := Vector2.ZERO
var _base: Control
var _knob: Control
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 120  # 盖在 HUD 之上，但摇杆区避开左上/左下信息栏
	active = DisplayServer.is_touchscreen_available() \
		or OS.has_feature("touch") \
		or DisplayServer.get_name() in ["Android", "iOS"]
	if not active:
		visible = false
		return
	_build_joystick()
	_build_buttons()


func _exit_tree() -> void:
	move_dir = Vector2.ZERO


# ---------- 摇杆 ----------

func _build_joystick() -> void:
	# 底盘：半透明圆盘 + 描边
	_base = Control.new()
	_base.visible = false
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.z_index = 100
	add_child(_base)
	_base.add_child(_make_circle(JOY_RADIUS, Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.35)))
	# 摇杆头：小实心圆
	_knob = Control.new()
	_knob.visible = false
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.z_index = 101
	add_child(_knob)
	_knob.add_child(_make_circle(KNOB_RADIUS, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.7)))


func _input(event: InputEvent) -> void:
	if not active or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# 手指落下：摇杆空闲 且 不在按钮上 → 在此处开摇杆
			if _joy_index == -1 and not _point_on_button(event.position):
				_joy_index = event.index
				_joy_origin = event.position
				_show_joy(event.position)
		else:
			if event.index == _joy_index:
				_release_joy()
	elif event is InputEventScreenDrag:
		if event.index == _joy_index:
			_update_joy(event.position)


func _show_joy(at: Vector2) -> void:
	_base.position = at - Vector2(JOY_RADIUS, JOY_RADIUS)
	_knob.position = at - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	_base.visible = true
	_knob.visible = true
	move_dir = Vector2.ZERO


func _update_joy(pos: Vector2) -> void:
	var offset := pos - _joy_origin
	var clamped := offset.limit_length(JOY_RADIUS)
	var dir := clamped / JOY_RADIUS
	if dir.length() < DEAD_ZONE:
		dir = Vector2.ZERO
	move_dir = dir
	# 摇杆头跟随（限位在底盘内）
	_knob.position = _joy_origin + clamped - Vector2(KNOB_RADIUS, KNOB_RADIUS)


func _release_joy() -> void:
	_joy_index = -1
	_base.visible = false
	_knob.visible = false
	move_dir = Vector2.ZERO


# ---------- 按钮 ----------

func _build_buttons() -> void:
	var margin := 24
	var size := Vector2(84, 84)
	var gap := 12
	# 右侧竖排：视野(小) + 攻击 + 移速 + 生命
	var actions: Array = [
		["视野", "use_vision", Color("#a78bfa")],
		["攻击", "buy_attack", Color("#fb923c")],
		["移速", "buy_speed", Color("#4ade80")],
		["生命", "buy_hp", Color("#f87171")],
	]
	for i in actions.size():
		var is_vision: bool = (i == 0)
		var bsize: Vector2 = Vector2(84, 56) if is_vision else size
		var b := _make_button(actions[i][0], actions[i][2], bsize)
		b.position = Vector2(
			get_viewport().get_visible_rect().size.x - bsize.x - margin,
			get_viewport().get_visible_rect().size.y - (actions.size() - i) * (size.y + gap) - margin
		)
		if is_vision:
			b.position.y += (size.y - bsize.y)  # 视野键靠上对齐
		_buttons.append(b)
	# 按钮监听：按下直接调 game 方法（与键盘 action 等效）
	_buttons[1].button_down.connect(_buy_attack)
	_buttons[2].button_down.connect(_buy_speed)
	_buttons[3].button_down.connect(_buy_hp)
	_buttons[0].button_down.connect(_use_vision)


func _make_button(text: String, color: Color, bsize: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.size = bsize
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.30)
	normal.set_corner_radius_all(14)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(color.r, color.g, color.b, 0.55)
	pressed.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	add_child(b)
	return b


func _point_on_button(p: Vector2) -> bool:
	for b in _buttons:
		if b.visible and b.get_global_rect().has_point(p):
			return true
	return false


func _game() -> Node:
	return get_tree().get_first_node_in_group("game")


func _buy_attack() -> void:
	var g := _game()
	if g:
		g._buy("attack")


func _buy_speed() -> void:
	var g := _game()
	if g:
		g._buy("speed")


func _buy_hp() -> void:
	var g := _game()
	if g:
		g._buy("hp")


func _use_vision() -> void:
	var g := _game()
	if g:
		g._use_vision()


# ---------- 绘制辅助 ----------

func _make_circle(r: float, fill: Color, border: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = fill
	# 描边：外圈放大一点的暗环
	var ring := Polygon2D.new()
	ring.polygon = pts
	ring.color = border
	ring.position = Vector2.ZERO
	ring.z_index = -1
	poly.add_child(ring)
	return poly
