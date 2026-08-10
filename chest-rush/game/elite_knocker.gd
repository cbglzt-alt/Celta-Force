class_name EliteKnocker
extends CharacterBody2D
## 敲门鬼精英：游走 → 凭空出「门」→ 敲门读条（预告给走位窗）→ 区域定身+掉血。
## 可反制：读条期累计受击超阈值则打断。"看得见的规则"，对齐 0.story.md §2.1。

signal died(pos, gold)

enum State { SPAWN, CHASE, TELEGRAPH, CHANNEL, BURST, COOLDOWN }

@export var hp_mult := 14.0         # 血量 = 杂兵 hp × 14（精英要扛住被动输出，别被秒）
@export var burst_dmg_mult := 4.0   # 爆发伤害 = 当前波接触伤害 × 4（定身+高伤才有压迫感）
@export var stun_duration := 2.0    # 定身秒数
@export var telegraph_time := 1.2   # 驻足预告（走位窗）
@export var channel_time := 1.5     # 敲门读条
@export var burst_radius := 150.0   # 爆发半径
@export var interrupt_frac := 0.5   # 打断阈值 = 血量 × 50% 累计受击（很难打断，以走位躲避为主）
@export var skill_cooldown := 6.0   # 两次敲门间隔
@export var gold_drop := 25

var hp: float
var speed: float
var burst_damage: float
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
var _base_modulate := Color(1, 1, 1)

var _sprite: AnimatedSprite2D
var _door: Node2D          # 凭空浮现的门框
var _danger_ring: Polygon2D  # 危险半径圈

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
	burst_damage = ed.damage_at(round_num) * burst_dmg_mult
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
	match _state:
		State.SPAWN:
			velocity = Vector2.ZERO
			_play("idle")
			if _state_t <= 0.0:
				_state = State.CHASE
		State.CHASE:
			_chase(delta)
			_play("walk" if velocity.length() > 5.0 else "idle")
			_cool_t -= delta
			# 靠近玩家且技能就绪 → 驻足预告
			if _cool_t <= 0.0 and _player and global_position.distance_to(_player.global_position) < 220.0:
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
		State.BURST, State.COOLDOWN:
			velocity = Vector2.ZERO
			_play("idle")
			if _state_t <= 0.0:
				_state = State.CHASE
				_cool_t = skill_cooldown
	move_and_slide()
	if _sprite and abs(velocity.x) > 1.0:
		_sprite.flip_h = velocity.x < 0.0


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


## 驻足预告：面前凭空浮现门框 + 危险圈淡入（走位窗）
func _start_telegraph() -> void:
	_state = State.TELEGRAPH
	_state_t = telegraph_time
	var dir := Vector2.DOWN
	if _player and is_instance_valid(_player):
		dir = (_player.global_position - global_position).normalized()
	# 门框（发光门框 = 用撤退门同款的方形框 + 竖柱，简化为发光门形）
	_door = Node2D.new()
	_door.position = dir * 50.0
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([Vector2(-16, -24), Vector2(16, -24), Vector2(16, 24), Vector2(-16, 24)])
	frame.color = Color(0.5, 0.3, 0.7, 0.9)
	_door.add_child(frame)
	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([Vector2(-10, -18), Vector2(10, -18), Vector2(10, 24), Vector2(-10, 24)])
	inner.color = Color(0.1, 0.05, 0.15, 1.0)
	_door.add_child(inner)
	_door.modulate.a = 0.0
	_fx.add_child(_door)
	var tw := _door.create_tween()
	tw.tween_property(_door, "modulate:a", 1.0, 0.4)
	# 危险半径圈淡入
	_danger_ring = Polygon2D.new()
	_danger_ring.polygon = Player.circle_poly(burst_radius, 40)
	_danger_ring.color = Color(1.0, 0.2, 0.2, 0.12)
	_danger_ring.z_index = -2
	_danger_ring.modulate.a = 0.0
	_fx.add_child(_danger_ring)
	_danger_ring.create_tween().tween_property(_danger_ring, "modulate:a", 1.0, telegraph_time)
	_flash_text("咚！咚！", Color("#e879f9"))


## 敲门读条：门框亮起、危险圈脉冲
func _start_channel() -> void:
	_state = State.CHANNEL
	_state_t = channel_time
	_interrupt_accum = 0.0
	if _danger_ring:
		var tw := _danger_ring.create_tween().set_loops(int(channel_time / 0.3))
		tw.tween_property(_danger_ring, "modulate:a", 0.4, 0.15)
		tw.tween_property(_danger_ring, "modulate:a", 1.0, 0.15)


## 爆发：危险圈内所有目标定身+掉血
func _burst() -> void:
	_state = State.COOLDOWN
	_state_t = 1.0
	# 圈闪白
	if _danger_ring:
		_danger_ring.color = Color(1.0, 0.9, 0.9, 0.5)
		_danger_ring.create_tween().tween_property(_danger_ring, "modulate:a", 0.0, 0.4)
	# 命中判定
	var center := global_position
	if _player and is_instance_valid(_player) and _player.alive:
		if center.distance_to(_player.global_position) <= burst_radius:
			_player.take_damage(burst_damage)
			_player.apply_stun(stun_duration)
	# 低级敌鬼（杂兵）也被定身（story：低于其等级都定）
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is Enemy and center.distance_to(e.global_position) <= burst_radius:
			e.take_damage(burst_damage * 0.5, center, Color("#c084fc"))
	_flash_text("开门！", Color("#f87171"))
	# 清理门框
	if _door:
		_door.create_tween().tween_property(_door, "modulate:a", 0.0, 0.4)
		_door.create_tween().tween_callback(_door.queue_free).set_delay(0.4)
		_door = null


## 被打断：门碎裂、回游走
func _interrupt() -> void:
	_play("hurt")  # 被打断后仰
	_state = State.COOLDOWN
	_state_t = 1.0
	_cool_t = skill_cooldown
	if _danger_ring:
		_danger_ring.create_tween().tween_property(_danger_ring, "modulate:a", 0.0, 0.2)
		_danger_ring = null
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


## 死亡：播 death 动画，播完再销毁（保留门框/危险圈清理）
func _die() -> void:
	alive = false
	set_physics_process(false)
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	# 清理技能特效
	if _danger_ring:
		_danger_ring.queue_free()
		_danger_ring = null
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
