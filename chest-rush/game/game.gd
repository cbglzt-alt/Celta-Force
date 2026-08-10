extends Node2D
## 对局编排：输入绑定、轮次刷怪、任务状态、暴走、撤离倒计时、胜负与重开。

const PlayerScene := preload("res://game/player.tscn")
const EnemyScene := preload("res://game/enemy.tscn")
const PickupScene := preload("res://game/pickup.tscn")
const KnockerScene := preload("res://game/elite_knocker.tscn")

@export var quest_target := 3
@export var round_interval := 22.0
@export var extract_countdown := 75.0
@export var upgrade_base_cost := 30
@export var upgrade_cost_growth := 1.8
@export var upgrade_max_level := 5
@export var spawn_radius := 220.0

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

var _balance := false
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
	if "--balance" in OS.get_cmdline_user_args():
		_balance_mode()
	if "--probe-knocker" in OS.get_cmdline_user_args():
		_probe_knocker_mode()


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
			# 抬上限：全体鬼伤害 +35%（乘算）
			player.set_damage_mult(pow(1.35, up_levels["attack"]))
			hud.message("全体鬼攻击提升！")
		"speed":
			# 抬上限：移速 +15%
			player.speed_mult = pow(1.15, up_levels["speed"])
			hud.message("移动速度提升！")
		"hp":
			# 抬上限并一次补满
			player.max_hp += 40
			player.heal(player.max_hp)
			hud.message("生命上限提升并补满！")


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
	# 数量：前期平缓、后期（7 波起）变陡 —— 先爽后紧
	var count := 3 + round_num + maxi(0, round_num - 6)
	for i in count:
		_spawn_enemy(_random_spawn_pos())
	# 精英敲门鬼：第 3 波起每 3 波尝试刷 1 只；场上已有存活敲门鬼则不再刷
	if round_num >= 3 and round_num % 3 == 0 and not _has_alive_knocker():
		_spawn_knocker(_random_spawn_pos())
	_scale_obstacles()
	hud.message("第 %d 波「鬼」涌现（%d 只）！" % [round_num, count])
	if _balance:
		var ed: EnemyData = Enemy.DATA
		print("BALANCE wave=%d count=%d hp=%d dmg=%.1f gold=%d playerHP=%d/%d dmgMult=%.2f" % [
			round_num, count, int(ed.hp_at(round_num)), ed.damage_at(round_num),
			ed.gold_at(round_num), int(player.hp), int(player.max_hp), player.damage_mult])


## 玩家周围一圈随机位置涌现，避开墙体
func _random_spawn_pos() -> Vector2:
	var center: Vector2 = player.global_position
	for _try in 12:
		var ang := randf() * TAU
		var pos := center + Vector2(cos(ang), sin(ang)) * spawn_radius
		if not level.blocks_vision(level.world_to_tile(pos)):
			return pos
	# 兜底：正右方
	return center + Vector2(spawn_radius, 0)


## 障碍血量随波次小涨，保住"清障成本"。宝箱改用贴近读条，不走血量（见 destructible）。
func _scale_obstacles() -> void:
	var r := maxi(round_num - 1, 0)
	var obst_target: float = 90.0 * pow(1.1, r)
	for o in level.obstacles.values():
		if is_instance_valid(o):
			o.hp = maxf(o.hp, obst_target)


func _spawn_enemy(pos: Vector2) -> void:
	var e = EnemyScene.instantiate()
	_world.add_child(e)
	e.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	e.setup(round_num, enraged, player, fog, level)
	e.died.connect(_on_enemy_died)


func _spawn_knocker(pos: Vector2) -> void:
	if _has_alive_knocker():
		return  # 一次只允许一只
	var k = KnockerScene.instantiate()
	_world.add_child(k)
	k.global_position = pos
	k.setup(round_num, enraged, player, fog, level)
	k.died.connect(_on_enemy_died)
	# 等出场飘字冒头后再弹全屏警告，避免被同帧波次横幅盖住注意力
	_alert_knocker_spawn()


func _alert_knocker_spawn() -> void:
	await get_tree().create_timer(0.35).timeout
	if over:
		return
	hud.alert_big("敲门鬼来了，请小心！", 3.2)


func _has_alive_knocker() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is EliteKnocker and is_instance_valid(e) and e.alive:
			return true
	return false


func _on_enemy_died(pos: Vector2, gold_amt: int) -> void:
	kills += 1
	# 物理 flush 内（弹体命中→敌死→掉落）不能新建碰撞体，延迟到物理步外
	call_deferred("_spawn_pickup", Pickup.Kind.GOLD, gold_amt, pos)


# ---------- 破坏物掉落与拾取 ----------

func _on_destructible_destroyed(d) -> void:
	fog.force_update()  # 障碍摧毁后视野可能变化
	call_deferred("_drop_from_destructible", d.global_position, d.kind, d.has_quest)


func _drop_from_destructible(pos: Vector2, kind: int, has_quest: bool) -> void:
	if kind == Destructible.Kind.CHEST:
		_spawn_pickup(Pickup.Kind.GOLD, randi_range(15, 30), pos + Vector2(-10, 0))
		if has_quest:
			_spawn_pickup(Pickup.Kind.QUEST, 1, pos + Vector2(12, 0))
		elif randf() < 0.18:
			_spawn_pickup(Pickup.Kind.VISION, 1, pos + Vector2(12, 0))
	else:
		# 障碍必掉少量金币（比宝箱少很多）
		_spawn_pickup(Pickup.Kind.GOLD, randi_range(2, 5), pos)


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

const MAX_FLOAT_TEXTS := 40  # 同屏飘字上限，防后期怪多时掉帧

func spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	if _effects.get_child_count() >= MAX_FLOAT_TEXTS:
		return  # 超过上限丢弃，保帧率
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
	# 轻微横向散开，避免同点数字叠在一起
	l.global_position = pos + Vector2(randf_range(-16, 4), -28)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(l.queue_free)


func _screenshot_mode() -> void:
	await get_tree().create_timer(6.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshot.png")
	get_tree().quit()


## 平衡自测：站桩被打，打印每波数值 + 最终存活波数
func _balance_mode() -> void:
	_balance = true
	print("BALANCE start: quest=%d interval=%.0fs cost_growth=%.2f" % [
		quest_target, round_interval, upgrade_cost_growth])
	player.died.connect(func(): print("BALANCE player died at wave=%d time=%.0fs" % [round_num, run_time]))


## 敲门鬼探针：离房后地刺 / 杂兵定身伤害 / 击杀掉金 / 同时仅一只
## 用法：godot --headless --path chest-rush --quit-after 900 -- --probe-knocker
func _probe_knocker_mode() -> void:
	print("PROBE knocker start")
	_round_timer.stop()
	player.set_damage_mult(0.0)
	for w in player.weapons:
		w.set_physics_process(false)

	await get_tree().create_timer(0.2).timeout
	round_num = 3
	var room_pos: Vector2 = player.global_position
	var k = KnockerScene.instantiate()
	_world.add_child(k)
	k.global_position = room_pos + Vector2(48, 0)
	k.setup(round_num, false, player, fog, level)
	k.died.connect(_on_enemy_died)

	# 第二只应被拒绝
	_spawn_knocker(room_pos + Vector2(80, 0))
	var knocker_n := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is EliteKnocker and n.alive:
			knocker_n += 1
	print("PROBE knocker_count=%d (expect 1)" % knocker_n)

	var e = EnemyScene.instantiate()
	_world.add_child(e)
	e.global_position = room_pos + Vector2(-48, 0)
	e.setup(round_num, false, player, fog, level)
	e.set_physics_process(false)
	e.died.connect(_on_enemy_died)
	# 压到残血，确保爆发能击杀并掉金
	e.hp = 1.0
	var gold_before := get_tree().get_nodes_in_group("pickups").size()

	await get_tree().create_timer(1.1).timeout
	k._start_telegraph()
	var mid: Vector2i = k._danger_rect.position + k._danger_rect.size / 2
	e.global_position = level.tile_to_world(mid)
	print("PROBE telegraph danger=%s enemy_in_room=%s" % [
		k._danger_rect,
		Rect2(Vector2(k._danger_rect.position) * level.TILE, Vector2(k._danger_rect.size) * level.TILE).has_point(e.global_position)])

	var leave_pos: Vector2 = room_pos
	if level.exits.size() > 0:
		leave_pos = level.tile_to_world(level.exits[0].tile)
	else:
		leave_pos = room_pos + Vector2(600, 400)
	player.global_position = leave_pos
	fog.force_update()
	await get_tree().process_frame
	print("PROBE left_room knocker.visible=%s fog_visible=%s" % [
		k.visible, fog.is_visible_world(k.global_position)])

	await get_tree().create_timer(k.telegraph_time + 0.1).timeout
	var spike_n: int = k._spike_tiles.size()
	var spike_under_knocker := false
	if spike_n > 0 and is_instance_valid(k._spike_tiles[0]):
		var pnode: Node = k._spike_tiles[0].get_parent()
		spike_under_knocker = (pnode == k) or (pnode != null and pnode.get_parent() == k)
	print("PROBE channel spikes=%d under_knocker=%s" % [spike_n, spike_under_knocker])

	await get_tree().create_timer(k.channel_time + 0.25).timeout
	# deferred 掉落下一帧才进树；第 1 段伤害在爆发瞬间
	await get_tree().process_frame
	var gold_after := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.kind == Pickup.Kind.GOLD:
			gold_after += 1
	var killed_ok: bool = not is_instance_valid(e) or e._dying or e.hp <= 0.0
	print("PROBE burst killed=%s pickups_gold %d->%d skill_dur=%.1f" % [
		killed_ok, gold_before, gold_after, k.skill_duration])

	# 满血杂兵：两段 50%+20%，应剩 30%
	var e2 = EnemyScene.instantiate()
	_world.add_child(e2)
	e2.setup(round_num, false, player, fog, level)
	e2.set_physics_process(false)
	e2.global_position = level.tile_to_world(mid)
	var full: float = e2.max_hp
	k._skill_tick(false, [e2], 0.0, k.enemy_dmg_pct_1, 1)
	k._skill_tick(false, [e2], 0.0, k.enemy_dmg_pct_2, 2)
	var expect_hp: float = full * (1.0 - k.enemy_dmg_pct_1 - k.enemy_dmg_pct_2)
	var pct_ok: bool = is_instance_valid(e2) and not e2._dying and abs(e2.hp - expect_hp) < 1.0
	print("PROBE pct_dmg hp=%.1f expect≈%.1f ok=%s" % [e2.hp if is_instance_valid(e2) else -1.0, expect_hp, pct_ok])

	var pass_fx: bool = spike_n > 0 and not spike_under_knocker
	var pass_kill_gold: bool = killed_ok and gold_after > gold_before
	var pass_one: bool = knocker_n == 1
	if pass_fx and pass_kill_gold and pass_one and pct_ok:
		print("PROBE RESULT PASS")
	else:
		print("PROBE RESULT FAIL fx=%s kill_gold=%s one=%s pct=%s" % [pass_fx, pass_kill_gold, pass_one, pct_ok])
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()
