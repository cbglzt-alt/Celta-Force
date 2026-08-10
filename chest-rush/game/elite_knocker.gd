class_name EliteKnocker
extends CharacterBody2D
## 敲门鬼精英：游走 → 凭空出「门」→ 敲门读条（预告给走位窗）→ 区域定身+掉血。
## 可反制：读条期累计受击超阈值则打断。"看得见的规则"，对齐 0.story.md §2.1。

signal died(pos, gold)

enum State { SPAWN, CHASE, TELEGRAPH, CHANNEL, BURST, COOLDOWN }

@export var hp_mult := 14.0         # 血量 = 杂兵 hp × 14（精英要扛住被动输出，别被秒）
@export var skill_duration := 5.0   # 技能持续：定身 + 地刺，期间两段伤害
@export var player_dmg_pct_1 := 0.30  # 主角第 1 段：满血 30%
@export var player_dmg_pct_2 := 0.10  # 主角第 2 段：满血 10%
@export var enemy_dmg_pct_1 := 0.50   # 杂兵第 1 段：满血 50%
@export var enemy_dmg_pct_2 := 0.20   # 杂兵第 2 段：满血 20%
@export var telegraph_time := 1.2   # 驻足预告（走位窗）
@export var channel_time := 1.5     # 敲门读条
@export var interrupt_frac := 0.5   # 打断阈值 = 血量 × 50% 累计受击（很难打断，以走位躲避为主）
@export var skill_cooldown := 6.0   # 两次敲门间隔
@export var gold_drop := 25

var hp: float
var speed: float
var damage: float
var contact_cooldown: float
var alive := true
var enraged := false

var _state := State.SPAWN
var _state_t := 0.0
var _interrupt_accum := 0.0
var _interrupt_threshold := 0.0
var _cool_t := 0.0

var _player: Node2D
var _fog: Node2D
var _level: Node2D
var _path := PackedVector2Array()
var _path_idx := 0
var _repath := 0.0
var _touch_timer := 0.0
var _attacking := false
var _hurt_lock := 0.0
var _base_modulate := Color(1, 1, 1)

var _sprite: AnimatedSprite2D
var _door: Node2D          # 凭空浮现的门框
var _danger_rect := Rect2i()  # 危险房间正方形（格坐标）
var _danger_tiles: Array = []  # 框选脉冲标记（square_up_down）
var _spike_tiles: Array = []   # 地刺铺满（peaks）

const IFACE_DIR := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/interface/"
const SQUARE_FRAMES := ["square_up_down_1.png", "square_up_down_2.png", "square_up_down_3.png", "square_up_down_4.png"]
const PEAKS_DIR := "res://assets/dungeon-assetpuck/2D Pixel Dungeon Asset Pack/items and trap_animation/peaks/"
const PEAKS_FRAMES := ["peaks_1.png", "peaks_2.png", "peaks_3.png", "peaks_4.png"]
## peaks 源图无 alpha，用色键抠掉地砖底色，避免铺满后挡住角色
const PEAKS_BG: Array[Color] = [
	Color8(61, 37, 59), Color8(54, 32, 48), Color8(37, 19, 26),
]
const FX_Z := -1  # 危险区/地刺画在角色脚下

static var _mark_sf: SpriteFrames
static var _spike_sf: SpriteFrames

@onready var _body: Polygon2D = $Body
@onready var _fx: Node2D = $Fx
@onready var _hit_area: Area2D = $HitArea


var _hp_bar: ColorRect
var _max_hp := 0.0
var _anim := "idle"


func _play(name: String) -> void:
	if _anim == name:
		return
	if not alive and name != "death":
		return
	# 普攻挥砍中不打断（技能态可强制切到 attack）
	if _attacking and name != "attack" and name != "death" and name != "hurt":
		return
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(name):
		_anim = name
		_sprite.play(name)


func _ready() -> void:
	add_to_group("enemies")
	# 敲门鬼：vampire 全套动画（idle/walk/attack/hurt/death），精英大一号
	_sprite = AnimHelper.build_sprite(Art.anims_of("vampire"), 9.0, 2.4)
	add_child(_sprite)
	_body.visible = false
	# 精英常驻血条（Boss 级存在感）
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.size = Vector2(40, 5)
	bg.position = Vector2(-20, -34)
	bg.z_index = 15
	bg.name = "HpBarBg"
	add_child(bg)
	_hp_bar = ColorRect.new()
	_hp_bar.color = Color("#c084fc")  # 紫色，区别杂兵红
	_hp_bar.size = Vector2(40, 5)
	bg.add_child(_hp_bar)


## 由 Game 在 add_child 后调用
func setup(round_num: int, is_enraged: bool, player_ref: Node2D, fog_ref: Node2D, level_ref: Node2D) -> void:
	var ed: EnemyData = Enemy.DATA
	hp = ed.hp_at(round_num) * hp_mult
	_max_hp = hp
	damage = ed.damage_at(round_num)  # 普攻与同波杂兵同伤
	contact_cooldown = ed.contact_cooldown
	speed = ed.speed_at(round_num) * 0.85  # 精英略慢，压迫感来自技能而非速度
	_interrupt_threshold = hp * interrupt_frac
	_player = player_ref
	_fog = fog_ref
	_level = level_ref
	if is_enraged:
		apply_enrage()
	_spawn_entrance()


func apply_enrage() -> void:
	if enraged:
		return
	enraged = true
	speed *= 1.5
	contact_cooldown *= Enemy.DATA.enrage_cooldown_mult
	_base_modulate = Color("#ff7b00")
	_sprite.modulate = _base_modulate


## 出场特效：黑雾涌现 + 门框浮现，1s 仪式感（此间无敌不动）
func _spawn_entrance() -> void:
	_state = State.SPAWN
	_state_t = 1.0
	# 黑雾涌现环
	var mist := Polygon2D.new()
	mist.polygon = Player.circle_poly(40.0, 32)
	mist.color = Color(0.2, 0.1, 0.3, 0.7)
	mist.z_index = -1
	_fx.add_child(mist)
	var tw := mist.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mist, "scale", Vector2(2.2, 2.2), 0.8)
	tw.tween_property(mist, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(mist.queue_free)
	_flash_text("咚……", Color("#c084fc"))


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_state_t -= delta
	_hurt_lock = maxf(_hurt_lock - delta, 0.0)
	match _state:
		State.SPAWN:
			velocity = Vector2.ZERO
			_play("idle")
			if _state_t <= 0.0:
				_state = State.CHASE
		State.CHASE:
			_chase(delta)
			if not _attacking and _hurt_lock <= 0.0:
				_play("walk" if velocity.length() > 5.0 else "idle")
			_cool_t -= delta
			_try_basic_attack(delta)
			# 靠近玩家且技能就绪 → 驻足预告（普攻中不打断挥砍）
			if not _attacking and _cool_t <= 0.0 and _player and global_position.distance_to(_player.global_position) < 220.0:
				_start_telegraph()
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			_play("attack")  # 敲门预告：抬手做敲击动作
			if _state_t <= 0.0:
				_start_channel()
		State.CHANNEL:
			velocity = Vector2.ZERO
			_play("attack")  # 读条期持续敲击
			# 读条期被打断判定在 take_damage 里累计
			if _state_t <= 0.0:
				_burst()
		State.BURST:
			velocity = Vector2.ZERO
			_play("attack")  # 技能持续期仍保持敲击压迫感
			if _state_t <= 0.0:
				_state = State.COOLDOWN
				_state_t = 0.4
				_cool_t = skill_cooldown
		State.COOLDOWN:
			velocity = Vector2.ZERO
			if not _attacking and _hurt_lock <= 0.0:
				_play("idle")
			if _state_t <= 0.0:
				_state = State.CHASE
				_cool_t = skill_cooldown
	move_and_slide()
	_update_facing()


## 朝向：近身/技能/普攻面向玩家；远距才跟 velocity，并提高翻转阈值防抖
func _update_facing() -> void:
	if _sprite == null or _player == null or not is_instance_valid(_player):
		return
	var dx := _player.global_position.x - global_position.x
	var near := global_position.distance_to(_player.global_position) < 72.0
	var skill_pose := _state == State.TELEGRAPH or _state == State.CHANNEL or _state == State.BURST
	if _attacking or near or skill_pose:
		if absf(dx) > 6.0:
			_sprite.flip_h = dx < 0.0
		return
	# 远距追击：提高阈值，避免路径点左右摆动时每帧镜像
	if absf(velocity.x) > 12.0:
		_sprite.flip_h = velocity.x < 0.0


## 追击期贴身普攻：碰触 → attack 动画 → 命中帧结算（对齐杂兵）
func _try_basic_attack(delta: float) -> void:
	_touch_timer -= delta
	if _attacking or _hurt_lock > 0.0 or _touch_timer > 0.0:
		return
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		return
	for b in _hit_area.get_overlapping_bodies():
		if b.is_in_group("player"):
			_touch_timer = contact_cooldown
			_basic_attack(b)
			break


func _basic_attack(target: Node2D) -> void:
	if not alive or _attacking:
		return
	_attacking = true
	_play("attack")
	var anim_len: float = _sprite.sprite_frames.get_frame_count("attack") / _sprite.sprite_frames.get_animation_speed("attack")
	await get_tree().create_timer(anim_len * 0.4).timeout
	if alive and is_instance_valid(target) and target.alive:
		if global_position.distance_to(target.global_position) < 55.0:
			target.take_damage(damage)
	if is_instance_valid(_sprite):
		await _sprite.animation_finished
	_attacking = false
	_anim = ""  # 强制下一帧重切 walk/idle


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		velocity = Vector2.ZERO
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.5
		if _level != null:
			_path = _level.find_path(global_position, _player.global_position)
			_path_idx = 0
	var to_player: Vector2 = _player.global_position - global_position
	var dir: Vector2
	if to_player.length() < 40.0 or _path.is_empty():
		dir = to_player.normalized()
	else:
		while _path_idx < _path.size() and global_position.distance_to(_path[_path_idx]) < 10.0:
			_path_idx += 1
		dir = (_path[_path_idx] - global_position).normalized() if _path_idx < _path.size() else to_player.normalized()
	velocity = dir * speed


## 驻足预告：门框浮现 + 危险房间（正方形）用框选脉冲标出（走位窗）
func _start_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_t = telegraph_time
	var dir := Vector2.DOWN
	if _player and is_instance_valid(_player):
		dir = (_player.global_position - global_position).normalized()
	# 门框：出现在敲门鬼面前较近处；整体门比例，框线尽量细
	_door = Node2D.new()
	_door.position = dir * 22.0
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-16, -24), Vector2(16, -24), Vector2(16, 24), Vector2(-16, 24)])
	frame.color = Color(0.5, 0.3, 0.7, 0.9)
	_door.add_child(frame)
	var inner := Polygon2D.new()
	# 内外差 2px → 细描边（左右/顶）
	inner.polygon = PackedVector2Array([Vector2(-14, -22), Vector2(14, -22), Vector2(14, 24), Vector2(-14, 24)])
	inner.color = Color(0.1, 0.05, 0.15, 1.0)
	_door.add_child(inner)
	_door.modulate.a = 0.0
	_fx.add_child(_door)
	_door.create_tween().tween_property(_door, "modulate:a", 1.0, 0.4)
	# 危险区 = 敲门鬼所在房间的正方形（取短边），square_up_down 框选脉冲标出
	_danger_rect = _level.room_square(_level.world_to_tile(global_position), 8)
	_mark_danger_zone()
	_flash_text("咚！咚！", Color("#e879f9"))


## 用框选脉冲瓦片标出危险房间边界（square_up_down 动画）
func _mark_danger_zone() -> void:
	_clear_danger_marks()
	var ts: int = _level.TILE
	# 沿正方形边界每格放一个框选脉冲标记
	for x in range(_danger_rect.position.x, _danger_rect.end.x):
		for y in [_danger_rect.position.y, _danger_rect.end.y - 1]:
			_add_mark(Vector2i(x, y), ts)
	for y in range(_danger_rect.position.y, _danger_rect.end.y):
		for x in [_danger_rect.position.x, _danger_rect.end.x - 1]:
			_add_mark(Vector2i(x, y), ts)


## 危险区特效挂世界层：不随敲门鬼迷雾 visible=false 一起消失（离房后技能仍可见）
func _fx_host() -> Node2D:
	if _level != null and is_instance_valid(_level):
		var host := _level.get_parent() as Node2D
		if host:
			return host
	return _fx


func _add_mark(t: Vector2i, ts: int) -> void:
	if not _level.in_bounds(t) or _level.blocks_vision(t):
		return
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _mark_frames()
	s.scale = Vector2(ts / 16.0, ts / 16.0)
	s.z_index = FX_Z
	s.z_as_relative = false
	s.play("pulse")
	_fx_host().add_child(s)
	s.global_position = _level.tile_to_world(t)
	_danger_tiles.append(s)


func _clear_danger_marks() -> void:
	for m in _danger_tiles:
		if is_instance_valid(m):
			m.queue_free()
	_danger_tiles.clear()


## 敲门读条：危险房间内地刺开始冒出（peaks 动画，压迫感递增）
func _start_channel() -> void:
	_state = State.CHANNEL
	_state_t = channel_time
	_interrupt_accum = 0.0
	_spawn_spikes()


## 在危险房间正方形内铺满地刺（从地里冒出的动画）
func _spawn_spikes() -> void:
	_clear_spikes()
	var ts: int = _level.TILE
	var host := _fx_host()
	var sf := _spike_frames()
	for x in range(_danger_rect.position.x, _danger_rect.end.x):
		for y in range(_danger_rect.position.y, _danger_rect.end.y):
			var t := Vector2i(x, y)
			if not _level.in_bounds(t) or _level.blocks_vision(t):
				continue
			var s := AnimatedSprite2D.new()
			s.sprite_frames = sf
			s.scale = Vector2(ts / 16.0, ts / 16.0)
			s.z_index = FX_Z
			s.z_as_relative = false
			s.play("spike")
			host.add_child(s)
			s.global_position = _level.tile_to_world(t)
			_spike_tiles.append(s)
	if "--probe-knocker" in OS.get_cmdline_user_args():
		print("PROBE knocker._spawn_spikes n=%d host=%s self.visible=%s" % [
			_spike_tiles.size(), host.name if host else "null", visible])


func _mark_frames() -> SpriteFrames:
	if _mark_sf != null:
		return _mark_sf
	var sf := SpriteFrames.new()
	sf.add_animation("pulse")
	sf.set_animation_speed("pulse", 6.0)
	sf.set_animation_loop("pulse", true)
	for f in SQUARE_FRAMES:
		var tex: Texture2D = load(IFACE_DIR + f)
		if tex:
			sf.add_frame("pulse", tex)
	_mark_sf = sf
	return sf


func _spike_frames() -> SpriteFrames:
	if _spike_sf != null:
		return _spike_sf
	var sf := SpriteFrames.new()
	sf.add_animation("spike")
	sf.set_animation_speed("spike", 7.0)
	sf.set_animation_loop("spike", true)
	for f in PEAKS_FRAMES:
		sf.add_frame("spike", _keyed_peaks_tex(PEAKS_DIR + f))
	_spike_sf = sf
	return sf


## 抠掉 peaks 实心底色，只留刺尖像素
func _keyed_peaks_tex(path: String) -> Texture2D:
	var src: Texture2D = load(path)
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return src
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			for bg in PEAKS_BG:
				if absf(c.r - bg.r) < 0.02 and absf(c.g - bg.g) < 0.02 and absf(c.b - bg.b) < 0.02:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					break
	return ImageTexture.create_from_image(img)


func _clear_spikes() -> void:
	for m in _spike_tiles:
		if is_instance_valid(m):
			m.queue_free()
	_spike_tiles.clear()


## 爆发：技能持续 skill_duration，定身 + 两段固定比例伤害（满血百分比，不够则死）
func _burst() -> void:
	_state = State.BURST
	_state_t = skill_duration
	_clear_danger_marks()
	_flash_text("开门！", Color("#f87171"))
	if _door:
		_door.create_tween().tween_property(_door, "modulate:a", 0.0, 0.4)
		_door.create_tween().tween_callback(_door.queue_free).set_delay(0.4)
		_door = null

	var rect := Rect2(
		Vector2(_danger_rect.position) * _level.TILE,
		Vector2(_danger_rect.size) * _level.TILE)
	var caught_player := false
	var caught_enemies: Array = []

	if _player and is_instance_valid(_player) and _player.alive and rect.has_point(_player.global_position):
		caught_player = true
		_player.apply_stun(skill_duration)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		if not (e is Enemy) or not rect.has_point(e.global_position):
			continue
		caught_enemies.append(e)
		if not e._dying:
			e.apply_stun(skill_duration)

	# 第 1 段伤害（立刻）
	_skill_tick(caught_player, caught_enemies, player_dmg_pct_1, enemy_dmg_pct_1, 1)
	var half := skill_duration * 0.5
	await get_tree().create_timer(half).timeout
	if not is_instance_valid(self) or not alive:
		return
	# 第 2 段伤害（持续中点）
	_skill_tick(caught_player, caught_enemies, player_dmg_pct_2, enemy_dmg_pct_2, 2)
	await get_tree().create_timer(half).timeout
	if is_instance_valid(self):
		_clear_spikes()


func _skill_tick(caught_player: bool, caught_enemies: Array, player_pct: float, enemy_pct: float, tick: int) -> void:
	var hit_n := 0
	if caught_player and _player and is_instance_valid(_player) and _player.alive:
		var dmg: float = _player.max_hp * player_pct
		_player.take_damage(dmg)
		hit_n += 1
	for e in caught_enemies:
		if not is_instance_valid(e) or e._dying:
			continue
		var hp_before: float = e.hp
		var dmg: float = e.max_hp * enemy_pct
		e.take_damage(dmg, global_position, Color("#c084fc"))
		hit_n += 1
		if "--probe-knocker" in OS.get_cmdline_user_args() and hp_before > 0.0 and (e._dying or e.hp <= 0.0):
			print("PROBE knocker.kill tick=%d hp_before=%.1f gold_drop=%d" % [tick, hp_before, e.gold_drop])
	if "--probe-knocker" in OS.get_cmdline_user_args():
		print("PROBE knocker.tick=%d hits=%d player=%s pct_p=%.0f pct_e=%.0f" % [
			tick, hit_n, caught_player, player_pct * 100.0, enemy_pct * 100.0])


## 被打断：门碎裂、回游走
func _interrupt() -> void:
	_attacking = false
	_play("hurt")  # 被打断后仰
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("hurt"):
		_hurt_lock = _sprite.sprite_frames.get_frame_count("hurt") / _sprite.sprite_frames.get_animation_speed("hurt")
	_state = State.COOLDOWN
	_state_t = 1.0
	_cool_t = skill_cooldown
	_clear_danger_marks()
	_clear_spikes()
	if _door:
		# 门碎裂下沉
		var tw := _door.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_door, "modulate:a", 0.0, 0.3)
		tw.tween_property(_door, "scale:y", 0.2, 0.3)
		tw.chain().tween_callback(_door.queue_free)
		_door = null
	_flash_text("打断！", Color("#4ade80"))


func _process(_delta: float) -> void:
	if _fog != null:
		visible = _fog.is_visible_world(global_position)


func take_damage(n: float, from_pos: Vector2, color := Color(1, 1, 1)) -> void:
	if not alive or _state == State.SPAWN:
		return  # 出场无敌
	hp -= n
	_flash()
	if _hp_bar and _max_hp > 0.0:
		_hp_bar.size.x = 40.0 * clampf(hp / _max_hp, 0.0, 1.0)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "-%d" % int(n), color)
	# 读条期累计受击，超阈值打断
	if _state == State.CHANNEL:
		_interrupt_accum += n
		if _interrupt_accum >= _interrupt_threshold:
			_interrupt()
	if hp <= 0.0:
		_die()
	elif not _attacking and _state == State.CHASE:
		_play("hurt")
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("hurt"):
			_hurt_lock = _sprite.sprite_frames.get_frame_count("hurt") / _sprite.sprite_frames.get_animation_speed("hurt")


## 死亡：播 death 动画，播完再销毁（保留门框/危险区清理）
func _die() -> void:
	alive = false
	_attacking = false
	set_physics_process(false)
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	# 清理技能特效
	_clear_danger_marks()
	_clear_spikes()
	if _door:
		_door.queue_free()
		_door = null
	var bg := get_node_or_null("HpBarBg")
	if bg:
		bg.visible = false
	died.emit(global_position, gold_drop)
	_play("death")
	await _sprite.animation_finished
	call_deferred("queue_free")


func _flash() -> void:
	_sprite.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", _base_modulate, 0.12)


func _flash_text(txt: String, color: Color) -> void:
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position + Vector2(0, -20), txt, color)
