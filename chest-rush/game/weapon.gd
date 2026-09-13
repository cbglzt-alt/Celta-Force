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
var range_mult := 1.0   # 域：攻击强化时范围略放大；刀/矢保持 1

var _cool := 0.0
var _player: Node2D
var _level: Node2D
var _fog: Node2D
var _marker: AnimatedSprite2D
var _marker_anim := "idle"
var _space: PhysicsDirectSpaceState2D
var _los_query: PhysicsRayQueryParameters2D
var _aura_ring: Polygon2D  # 域常驻范围圈，升级时重算半径

## 召唤物状态
enum State { FOLLOW, APPROACH, ATTACK }
var _state := State.FOLLOW
var _idx := 0
var _attack_anim_time := 0.0  # 攻击动画锁定（防止被 walk/idle 覆盖）
const FOLLOW_SPEED := 5.0  # lerp 速度（拖尾延迟感）
## V 形阵型偏移（召唤物在玩家身后）
const FORMATIONS: Array[Vector2] = [
	Vector2(-24, 20), Vector2(0, 32), Vector2(24, 20),
]

const ProjectileScene := preload("res://game/projectile.tscn")

## 域技能灼烧：tiny-swords Fire 精灵（8 帧条带，播完即消）
static var _aura_sf: SpriteFrames


func _world() -> Node2D:
	var cs := get_tree().current_scene
	if cs != null and cs.has_node("World"):
		return cs.get_node("World")
	return get_tree().root.find_child("World", true, false)


## 攻击发出的源点（召唤物自身位置，不再是玩家位置）
func _src() -> Vector2:
	return global_position


## 由 Game 在 add_child 后调用（武器现在是世界空间实体，不是 Player 子节点）
func setup(idx: int, player_ref: Node2D, level_ref: Node2D, fog_ref: Node2D) -> void:
	_idx = idx
	data = load(LOADOUT[idx])
	_player = player_ref
	_level = level_ref
	_fog = fog_ref
	z_index = 50  # 召唤物渲染在迷雾之上（玩家始终可见自己的召唤物）
	# 召唤物可视化精灵
	if data.sprite_key != "" and Art.FRAMES.has(data.sprite_key):
		_marker = _make_ghost_sprite(data.sprite_key)
	else:
		var dot := Polygon2D.new()
		dot.polygon = Player.circle_poly(5.0, 6)
		dot.color = data.color
		# dot can't play animations; use as fallback only
	_marker = _marker if _marker != null else AnimatedSprite2D.new()
	add_child(_marker)
	_space = get_world_2d().direct_space_state
	_los_query = PhysicsRayQueryParameters2D.new()
	_los_query.collision_mask = 4
	_los_query.collide_with_areas = false
	if data.pattern == WeaponData.Pattern.AURA:
		_aura_ring = Polygon2D.new()
		_aura_ring.polygon = _ring_poly(_eff_range(), 48)
		_aura_ring.color = Color(0.753, 0.518, 0.988, 0.14)
		_aura_ring.z_index = -1
		add_child(_aura_ring)


## 当前有效射程（域随攻击等级放大）
func _eff_range() -> float:
	return data.attack_range * range_mult


## 攻击强化后刷新域范围圈
func apply_range_mult(mult: float) -> void:
	range_mult = mult
	if _aura_ring != null and data != null:
		_aura_ring.polygon = _ring_poly(_eff_range(), 48)


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


## 鬼 sprite：所有召唤物配 idle + walk，有 attack 的加上
func _make_ghost_sprite(sprite_key: String) -> AnimatedSprite2D:
	var anims := Art.anims_of(sprite_key)
	var sprite_anims := {"idle": anims["idle"]}
	if anims.has("walk"):
		sprite_anims["walk"] = anims["walk"]
	if anims.has("attack"):
		sprite_anims["attack"] = anims["attack"]
	return AnimHelper.build_sprite(sprite_anims, 9.0, 0.22, Art.UNIT_CELL)


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
	var from: Vector2 = global_position
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
	if data == null or _player == null or not is_instance_valid(_player):
		return
	_cool -= delta
	_attack_anim_time -= delta
	# 召唤物状态机：跟随 → 接敌 → 攻击
	var target := _nearest_enemy(_eff_range() * 1.5)
	if target == null:
		_state = State.FOLLOW
	elif global_position.distance_to(target.global_position) <= _eff_range():
		_state = State.ATTACK
	else:
		_state = State.APPROACH

	# 移动逻辑
	match _state:
		State.FOLLOW:
			_move_to(_player.global_position + FORMATIONS[_idx], delta)
			_play_anim("walk" if global_position.distance_to(_player.global_position + FORMATIONS[_idx]) > 5.0 else "idle")
		State.APPROACH:
			if target != null:
				_move_to(target.global_position, delta)
				_play_anim("walk")
		State.ATTACK:
			if target != null and _cool <= 0.0:
				_cool = data.cooldown
				_play_anim("attack")
				_fire_at(target)
			elif _cool > 0.0:
				# 攻击冷却中，微调到攻击范围边缘
				_play_anim("idle")

	# AURA 范围圈跟随武器位置
	if _aura_ring != null:
		_aura_ring.global_position = global_position


## 召唤物移动：lerp 向目标位置（有拖尾延迟感）
func _move_to(target_pos: Vector2, delta: float) -> void:
	var speed := FOLLOW_SPEED * delta
	global_position = global_position.lerp(target_pos, minf(speed, 1.0))
	# 朝向翻转
	if _marker != null:
		var dx := target_pos.x - global_position.x
		if absf(dx) > 2.0:
			_marker.flip_h = dx < 0.0


## 召唤物动画播放
func _play_anim(anim_name: String) -> void:
	if _marker == null or not (_marker is AnimatedSprite2D):
		return
	# 攻击动画锁定期间不覆盖
	if _attack_anim_time > 0.0 and anim_name != "attack":
		return
	var s := _marker as AnimatedSprite2D
	if s.sprite_frames == null or not s.sprite_frames.has_animation(anim_name):
		if anim_name != "idle" and s.sprite_frames and s.sprite_frames.has_animation("idle"):
			anim_name = "idle"
		else:
			return
	if _marker_anim == anim_name:
		return
	_marker_anim = anim_name
	s.play(anim_name)


## 发射攻击（按 pattern 分派）
func _fire_at(target: Node2D) -> void:
	_attack_anim_time = 0.4  # 锁定攻击动画 0.4s
	match data.pattern:
		WeaponData.Pattern.SLASH:
			var destruct: Node2D = _nearest_destructible(_eff_range())
			_fire_slash(target if target != null else destruct)
		WeaponData.Pattern.BOLT:
			if target != null:
				_fire_bolt(target)
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
	var r := _eff_range()
	# 可见扇形弧光特效（半透明彩色扇区，快速淡出）
	_spawn_slash_fx(src, dir, r, data.color)
	# 前方扇区内无遮挡的敌人
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = e.global_position - src
		if to.length() <= r and abs(to.angle_to(dir)) < 0.9 and not _blocked(e.global_position):
			e.take_damage(_dmg(), src, data.color)
	# 前方扇区内的障碍（血量制；宝箱免疫攻击、贴近读条，跳过）
	for d in get_tree().get_nodes_in_group("destructibles"):
		if d.kind == Destructible.Kind.CHEST:
			continue
		var to: Vector2 = d.global_position - src
		if to.length() <= r and abs(to.angle_to(dir)) < 0.9 and not _blocked(d.global_position):
			d.take_damage(_dmg(), src, data.color)


## 扇形挥砍特效：半透明彩色扇区，闪现后快速淡出
func _spawn_slash_fx(src: Vector2, dir: Vector2, r: float, color: Color) -> void:
	var world := _world()
	if world == null:
		return
	var arc := Polygon2D.new()
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 8
	var half := 0.9
	for i in steps + 1:
		var a := dir.angle() - half + 2.0 * half * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * r)
	arc.polygon = pts
	arc.color = Color(color.r, color.g, color.b, 0.35)
	arc.z_index = 5
	world.add_child(arc)
	arc.global_position = src
	var tw := arc.create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, 0.18)
	tw.tween_callback(arc.queue_free)


func _fire_bolt(target: Node2D) -> void:
	var src := _src()
	var dir: Vector2 = (target.global_position - src).normalized()
	# 射程截短到最近遮挡物，弹不朝墙外乱飞
	var max_r := _eff_range()
	var eff_range: float = max_r
	_los_query.collision_mask = 4
	_los_query.exclude = []
	_los_query.from = src
	_los_query.to = src + dir * max_r
	var wall := _space.intersect_ray(_los_query)
	if not wall.is_empty():
		eff_range = src.distance_to(wall.position)
	var p = ProjectileScene.instantiate()
	_world().add_child(p)
	p.global_position = src
	p.setup(_dmg(), dir, eff_range, data.color)


func _fire_aura() -> void:
	var src := _src()
	var r := _eff_range()
	_spawn_aura_flames(src)
	for e in get_tree().get_nodes_in_group("enemies"):
		if src.distance_to(e.global_position) <= r and not _blocked(e.global_position):
			e.take_damage(_dmg(), src, data.color)
	# 破坏物免疫范围伤害（只有近战刀能开箱/清障）


## 域灼烧特效：范围内铺 flamethrower_1；z_index=-1 画在怪物脚下，不遮挡
func _spawn_aura_flames(origin: Vector2) -> void:
	var world := _world()
	if world == null:
		return
	var sf := _aura_frames()
	# 4 帧 / 10fps ≈ 0.4s，略加缓冲后强制回收（避免末帧灰点残留）
	var life := 0.45
	var spots: Array[Vector2] = [Vector2.ZERO]
	var outer := _eff_range() * 0.62
	for i in 8:
		var a := TAU * float(i) / 8.0
		spots.append(Vector2(cos(a), sin(a)) * outer)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		spots.append(Vector2(cos(a), sin(a)) * (outer * 0.42))
	for off in spots:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = sf
		s.scale = Vector2(0.3, 0.3)  # tiny-swords fire 192px → ~58px，醒目
		s.z_index = -1
		s.z_as_relative = false
		world.add_child(s)
		# 略下移，火焰落在脚底而非盖住身躯
		s.global_position = origin + off + Vector2(0, 10)
		s.play("burn")
		# AnimatedSprite2D.animation_finished 无参；末帧易留灰白点，淡出后回收
		var tw := s.create_tween()
		tw.tween_interval(life * 0.55)
		tw.tween_property(s, "modulate:a", 0.0, life * 0.45)
		tw.tween_callback(s.queue_free)


func _aura_frames() -> SpriteFrames:
	if _aura_sf != null:
		return _aura_sf
	var sf := SpriteFrames.new()
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 12.0)
	sf.set_animation_loop("burn", false)
	# tiny-swords Fire_01：8 帧 × 192px 条带
	for i in Art.FIRE_FRAMES:
		var tex: Texture2D = Art.slice_strip(Art.FIRE_SPRITE, Art.FIRE_CELL, i)
		if tex:
			sf.add_frame("burn", tex)
	_aura_sf = sf
	return sf


func _ring_poly(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
