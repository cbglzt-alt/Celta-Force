extends Node2D
## 对局编排：输入绑定、轮次刷怪、任务状态、暴走、撤离倒计时、胜负与重开。

const PlayerScene := preload("res://game/player.tscn")
const EnemyScene := preload("res://game/enemy.tscn")
const PickupScene := preload("res://game/pickup.tscn")

@export var quest_target := 3
@export var round_interval := 22.0
@export var extract_countdown := 75.0
@export var upgrade_base_cost := 30
@export var upgrade_cost_growth := 1.6
@export var upgrade_max_level := 4

var level: Node2D
var fog: Node2D
var player: Node2D
var hud: CanvasLayer

var gold := 0
var gold_earned := 0
var quest_items := 0
var vision_items := 0
var kills := 0
var round_num := 0
var run_time := 0.0
var enraged := false
var extraction_active := false
var over := false

var up_levels := {"attack": 0, "speed": 0, "hp": 0}

var _float_font: Font

@onready var _world: Node2D = $World
@onready var _effects: Node2D = $Effects
@onready var _round_timer: Timer = $RoundTimer
@onready var _extract_timer: Timer = $ExtractTimer


func _ready() -> void:
	add_to_group("game")
	_setup_input()
	level = $World/LevelMap
	fog = $FogOfWar
	fog.setup(level)
	# 玩家
	player = PlayerScene.instantiate()
	_world.add_child(player)
	player.global_position = level.player_start
	player.died.connect(_on_player_died)
	fog.player = player
	fog.force_update()
	# 随机 quest_target 个宝箱藏任务道具（外表无区别，杜绝定向刷）
	var bag: Array = level.chests.duplicate()
	bag.shuffle()
	for i in mini(quest_target, bag.size()):
		bag[i].has_quest = true
	level.destructible_destroyed.connect(_on_destructible_destroyed)
	# HUD
	hud = $HUD
	hud.setup(self)
	_float_font = load("res://game/fonts/NotoSansSC-Subset.otf")
	hud.message("砸开宝箱搜集金币，找到 %d 个任务道具！" % quest_target, 4.0)
	# 计时器
	_round_timer.wait_time = round_interval
	_round_timer.timeout.connect(_on_round)
	_round_timer.start()
	_extract_timer.timeout.connect(_on_extract_timeout)
	if "--screenshot" in OS.get_cmdline_user_args():
		_screenshot_mode()


func _process(delta: float) -> void:
	if over:
		return
	run_time += delta
	hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if over:
		return
	if event.is_action_pressed("use_vision"):
		_use_vision()
	elif event.is_action_pressed("buy_attack"):
		_buy("attack")
	elif event.is_action_pressed("buy_speed"):
		_buy("speed")
	elif event.is_action_pressed("buy_hp"):
		_buy("hp")


# ---------- 输入（运行期绑定，避免手改 project.godot） ----------

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("attack", [KEY_SPACE], [MOUSE_BUTTON_LEFT])
	_bind("use_vision", [KEY_Q])
	_bind("buy_attack", [KEY_1])
	_bind("buy_speed", [KEY_2])
	_bind("buy_hp", [KEY_3])
	_bind("restart", [KEY_R])


func _bind(action: StringName, keys: Array, buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)


# ---------- 局内强化与视野道具 ----------

func upgrade_cost(track: String) -> int:
	return int(round(upgrade_base_cost * pow(upgrade_cost_growth, up_levels[track])))


func _buy(track: String) -> void:
	if up_levels[track] >= upgrade_max_level:
		hud.message("该项已满级")
		return
	var c := upgrade_cost(track)
	if gold < c:
		hud.message("金币不足（需要 %d）" % c)
		return
	gold -= c
	up_levels[track] += 1
	match track:
		"attack":
			player.damage_mult = pow(1.4, up_levels["attack"])
			hud.message("攻击力提升！")
		"speed":
			player.speed_mult = pow(1.12, up_levels["speed"])
			hud.message("移动速度提升！")
		"hp":
			player.max_hp += 25
			player.heal(25)
			hud.message("生命上限提升！")


func _use_vision() -> void:
	if vision_items <= 0:
		hud.message("没有视野道具")
		return
	vision_items -= 1
	fog.vision_radius += 1
	fog.force_update()
	hud.message("视野范围 +1")


# ---------- 波次 ----------

func _on_round() -> void:
	if over:
		return
	round_num += 1
	var points: Array = level.spawn_points.duplicate()
	points.shuffle()
	var n: int = mini(2 + round_num, points.size())
	for i in n:
		_spawn_enemy(points[i])
	hud.message("第 %d 波怪物出现！" % round_num)


func _spawn_enemy(pos: Vector2) -> void:
	var e = EnemyScene.instantiate()
	_world.add_child(e)
	e.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	e.setup(round_num, enraged, player, fog)
	e.died.connect(_on_enemy_died)


func _on_enemy_died(pos: Vector2, gold_amt: int) -> void:
	kills += 1
	_spawn_pickup(Pickup.Kind.GOLD, gold_amt + randi_range(0, 3), pos)


# ---------- 破坏物掉落与拾取 ----------

func _on_destructible_destroyed(d) -> void:
	fog.force_update()  # 障碍摧毁后视野可能变化
	var pos: Vector2 = d.global_position
	if d.kind == Destructible.Kind.CHEST:
		_spawn_pickup(Pickup.Kind.GOLD, randi_range(15, 30), pos + Vector2(-10, 0))
		if d.has_quest:
			_spawn_pickup(Pickup.Kind.QUEST, 1, pos + Vector2(12, 0))
		elif randf() < 0.35:
			_spawn_pickup(Pickup.Kind.VISION, 1, pos + Vector2(12, 0))
	elif randf() < 0.3:
		_spawn_pickup(Pickup.Kind.GOLD, randi_range(4, 8), pos)


func _spawn_pickup(kind: Pickup.Kind, amount: int, pos: Vector2) -> void:
	var p = PickupScene.instantiate()
	_world.add_child(p)
	p.global_position = pos
	p.setup(kind, amount, fog)


func collect(p: Node2D) -> void:
	match p.kind:
		Pickup.Kind.GOLD:
			gold += p.amount
			gold_earned += p.amount
			spawn_float_text(p.global_position, "+%d" % p.amount, Color("#facc15"))
		Pickup.Kind.VISION:
			vision_items += 1
			hud.message("获得视野道具（按 Q 使用）")
		Pickup.Kind.QUEST:
			quest_items += 1
			spawn_float_text(p.global_position, "任务道具 %d/%d" % [quest_items, quest_target], Color("#e879f9"))
			if quest_items >= quest_target:
				_on_quest_complete()


# ---------- 任务完成 → 暴走 → 限时撤离 ----------

func _on_quest_complete() -> void:
	enraged = true
	extraction_active = true
	for e in get_tree().get_nodes_in_group("enemies"):
		e.apply_enrage()
	level.unlock_exits()
	_extract_timer.start(extract_countdown)
	hud.message("任务完成！怪物暴走，%d 秒内抵达撤离点！" % int(extract_countdown), 4.0)
	hud.set_countdown_visible(true)


func try_extract() -> void:
	if extraction_active and not over:
		_win()


func _win() -> void:
	over = true
	_extract_timer.stop()
	hud.show_result(true, "成功撤离！", _stats_text())
	get_tree().paused = true


func _lose(reason: String) -> void:
	if over:
		return
	over = true
	hud.show_result(false, reason, _stats_text())
	get_tree().paused = true


func _on_extract_timeout() -> void:
	_lose("撤离超时，被怪物淹没")


func _on_player_died() -> void:
	_lose("你被怪物击倒了")


func _stats_text() -> String:
	var t := int(run_time)
	return "用时 %02d:%02d   波次 %d   击杀 %d   金币 %d   任务 %d/%d" % [
		t / 60, t % 60, round_num, kills, gold_earned, quest_items, quest_target]


# ---------- HUD 读取用访问器 ----------

func round_time_left() -> float:
	return _round_timer.time_left


func extract_time_left() -> float:
	return _extract_timer.time_left


func extract_running() -> bool:
	return not _extract_timer.is_stopped()


func vision_radius() -> int:
	return fog.vision_radius


# ---------- 飘字与截图自检 ----------

func spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	if _float_font != null:
		l.add_theme_font_override("font", _float_font)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 60
	_effects.add_child(l)
	l.global_position = pos + Vector2(-12, -28)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)


func _screenshot_mode() -> void:
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	get_tree().quit()
