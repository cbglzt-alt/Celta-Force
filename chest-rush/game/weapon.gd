class_name Weapon
extends Node2D
## 被动攻击装备（"鬼"）：由 WeaponData(.tres) 驱动，自动索敌、自动开火。
## 三种 pattern：SLASH 近战弧 / BOLT 直线弹 / AURA 范围灼烧。

## 本关固定 3 只鬼（指向 .tres，下一阶段将随关卡数据固化）
const LOADOUT: Array[String] = [
	"res://game/data/blade.tres",
	"res://game/data/arrow.tres",
	"res://game/data/domain.tres",
]

var data: WeaponData
var damage_mult := 1.0  # 全局伤害倍率（attack 强化乘入）

var _cool := 0.0
var _player: Node2D
var _marker: Node2D
var _marker_anim := "idle"
var _space: PhysicsDirectSpaceState2D
var _los_query: PhysicsRayQueryParameters2D

const ProjectileScene := preload("res://game/projectile.tscn")


func _world() -> Node2D:
	var cs := get_tree().current_scene
	if cs != null and cs.has_node("World"):
		return cs.get_node("World")
	return get_tree().root.find_child("World", true, false)


## 攻击发出的源点（玩家位置）
func _src() -> Vector2:
	return _player.global_position if _player != null else global_position


## 由 Player 在 add_child 后调用
func setup(idx: int, player_ref: Node2D) -> void:
	data = load(LOADOUT[idx])
	_player = player_ref
	# 鬼的可视化：有 sprite_key 用 dungeon 像素 sprite（含 attack 动画，近战挥刀用）
	if data.sprite_key != "" and Art.FRAMES.has(data.sprite_key):
		_marker = _make_ghost_sprite(data.sprite_key)
	else:
		var dot := Polygon2D.new()
		dot.polygon = Player.circle_poly(5.0, 6)
		dot.color = data.color
		_marker = dot
	add_child(_marker)
	_space = get_world_2d().direct_space_state
	# 视线检测：只撞墙体与障碍/宝箱（层 4），忽略敌人(2)/玩家(1)
	_los_query = PhysicsRayQueryParameters2D.new()
	_los_query.collision_mask = 4
	_los_query.collide_with_areas = false
	if data.pattern == WeaponData.Pattern.AURA:
		var ring := Polygon2D.new()
		ring.polygon = _ring_poly(data.attack_range, 48)
		ring.color = Color(data.color, 0.08)
		ring.z_index = -1
		add_child(ring)


func _make_sprite(paths: Array[String]) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 6.0)
	sf.set_animation_loop("idle", true)
	for p in paths:
		var tex := load(p)
		if tex:
			sf.add_frame("idle", tex)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.scale = Vector2(1.4, 1.4)  # 鬼是挂件，比主角小一号
	s.play("idle")
	return s


## 鬼 sprite：近战刀鬼（skeleton）带 attack 挥刀动画；其余用 4 帧 idle
func _make_ghost_sprite(sprite_key: String) -> AnimatedSprite2D:
	if sprite_key == "enemy":
		# 刀鬼 skeleton：装配 idle + attack（挥刀）
		return AnimHelper.build_sprite({
			"idle": Art.ANIM_DIR + "enemies-skeleton1_idle.png",
			"attack": Art.ANIM_DIR + "enemies-skeleton1_attack.png",
		}, 9.0, 1.4, 32)
	# 矢（vampire）/域（skull）等：只 4 帧 idle
	return _make_sprite(Art.frames_of(sprite_key))


## 近战攻击时：刀鬼播挥刀动画（朝目标翻转），播完回 idle
func _play_attack_anim(target: Node2D) -> void:
	if not (_marker is AnimatedSprite2D):
		return
	var s := _marker as AnimatedSprite2D
	if not (s.sprite_frames and s.sprite_frames.has_animation("attack")):
		return
	# 朝目标翻转
	s.flip_h = target.global_position.x < _src().x
	_marker_anim = "attack"
	s.play("attack")
	await s.animation_finished
	_marker_anim = "idle"
	if is_instance_valid(s):
		s.play("idle")


## 两点间是否被"途中"的墙/障碍/宝箱阻挡（攻击不可穿墙）。
## 语义：命中点若"已进入目标格"（打到目标自己）→ 可见；否则途中是真遮挡。
## 用"命中点到目标距离 < 半格"判定打到目标，对薄墙不失效。
## 射线起点用玩家位置（武器挂在玩家身上，攻击自玩家发出）。
func _blocked(target_pos: Vector2) -> bool:
	var from: Vector2 = _player.global_position if _player != null else global_position
	var to := target_pos
	var cur := from
	var exclude: Array = []
	for _i in 8:
		_los_query.collision_mask = 4
		_los_query.exclude = exclude
		_los_query.from = cur
		_los_query.to = to
		var hit := _space.intersect_ray(_los_query)
		if hit.is_empty():
			return false  # 一路畅通
		# 命中点已够到目标（进入其碰撞体范围）→ 打的是目标自己，可见
		if hit.position.distance_to(to) < 16.0:
			return false
		# 途中撞到真遮挡 → 挡住
		return true
	return true


func _physics_process(delta: float) -> void:
	if data == null:
		return
	# 槽位环绕玩家标记（3 只鬼的位置提示）
	var idx: int = get_index()
	var ang := Time.get_ticks_msec() / 1000.0 * 1.6 + idx * TAU / 3.0
	_marker.position = Vector2(cos(ang), sin(ang)) * 24.0

	_cool -= delta
	if _cool > 0.0:
		return
	var target := _nearest_enemy(data.attack_range)
	# 破坏物（宝箱/障碍）只有近战可打，免疫远程与范围
	var destruct: Node2D = _nearest_destructible(data.attack_range) if data.pattern == WeaponData.Pattern.SLASH else null
	if target == null and destruct == null:
		return
	_cool = data.cooldown
	match data.pattern:
		WeaponData.Pattern.SLASH:
			# 优先打敌人，无敌人则挥向障碍/宝箱（清障开箱 = 走位决策）
			_fire_slash(target if target != null else destruct)
		WeaponData.Pattern.BOLT:
			if target != null:
				_fire_bolt(target)
			else:
				_cool = 0.0  # 弹打不到障碍（会撞墙），不进入冷却
		WeaponData.Pattern.AURA:
			_fire_aura()


## 射程内无遮挡的最近敌人
func _nearest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = _src().distance_to(e.global_position)
		if d < best_d and not _blocked(e.global_position):
			best_d = d
			best = e
	return best


## 射程内无遮挡的最近可打障碍（宝箱免疫攻击，只能贴近读条，故排除）
func _nearest_destructible(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range
	for d in get_tree().get_nodes_in_group("destructibles"):
		if d.kind == Destructible.Kind.CHEST:
			continue
		var dist: float = _src().distance_to(d.global_position)
		if dist < best_d and not _blocked(d.global_position):
			best_d = dist
			best = d
	return best


func _dmg() -> float:
	return data.damage * damage_mult


func _fire_slash(target: Node2D) -> void:
	var src := _src()
	var dir: Vector2 = (target.global_position - src).normalized()
	# 挥刀动画：刀鬼（skeleton）播 attack，替代扇形弧光
	_play_attack_anim(target)
	# 前方扇区内无遮挡的敌人
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = e.global_position - src
		if to.length() <= data.attack_range and abs(to.angle_to(dir)) < 0.9 and not _blocked(e.global_position):
			e.take_damage(_dmg(), src, data.color)
	# 前方扇区内的障碍（血量制；宝箱免疫攻击、贴近读条，跳过）
	for d in get_tree().get_nodes_in_group("destructibles"):
		if d.kind == Destructible.Kind.CHEST:
			continue
		var to: Vector2 = d.global_position - src
		if to.length() <= data.attack_range and abs(to.angle_to(dir)) < 0.9 and not _blocked(d.global_position):
			d.take_damage(_dmg(), src, data.color)


func _fire_bolt(target: Node2D) -> void:
	var src := _src()
	var dir: Vector2 = (target.global_position - src).normalized()
	# 射程截短到最近遮挡物，弹不朝墙外乱飞
	var eff_range: float = data.attack_range
	_los_query.collision_mask = 4
	_los_query.exclude = []
	_los_query.from = src
	_los_query.to = src + dir * data.attack_range
	var wall := _space.intersect_ray(_los_query)
	if not wall.is_empty():
		eff_range = src.distance_to(wall.position)
	var p = ProjectileScene.instantiate()
	_world().add_child(p)
	p.global_position = src
	p.setup(_dmg(), dir, eff_range, data.color)


func _fire_aura() -> void:
	var ring := Polygon2D.new()
	ring.polygon = _ring_poly(data.attack_range, 40)
	ring.color = Color(data.color, 0.35)
	ring.z_index = -1
	_world().add_child(ring)
	ring.global_position = _src()
	var tw := ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)
	var src := _src()
	for e in get_tree().get_nodes_in_group("enemies"):
		if src.distance_to(e.global_position) <= data.attack_range and not _blocked(e.global_position):
			e.take_damage(_dmg(), src, data.color)
	# 破坏物免疫范围伤害（只有近战刀能开箱/清障）


func _ring_poly(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
