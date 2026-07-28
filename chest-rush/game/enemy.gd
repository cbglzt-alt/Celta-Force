class_name Enemy
extends CharacterBody2D
## 追击型怪物：数值随轮次增强，任务完成后可暴走。

signal died(pos, gold)

@export var base_hp := 30.0
@export var base_speed := 90.0
@export var damage := 8.0
@export var contact_cooldown := 1.0
@export var gold_drop := 5
@export var hp_growth := 1.15
@export var speed_growth := 1.03
@export var speed_cap_mult := 1.6

var hp: float
var speed: float
var enraged := false

var _player: Node2D
var _fog: Node2D
var _touch_timer := 0.0
var _knockback := Vector2.ZERO
var _base_color := Color("#ef4444")

@onready var _body: Polygon2D = $Body
@onready var _hit_area: Area2D = $HitArea


func _ready() -> void:
	add_to_group("enemies")
	_body.polygon = Player.circle_poly(12.0, 14)
	_body.color = _base_color


## 由 Game 在 add_child 后调用
func setup(round_num: int, is_enraged: bool, player_ref: Node2D, fog_ref: Node2D) -> void:
	hp = base_hp * pow(hp_growth, maxi(round_num - 1, 0))
	speed = minf(base_speed * pow(speed_growth, maxi(round_num - 1, 0)), base_speed * speed_cap_mult)
	_player = player_ref
	_fog = fog_ref
	if is_enraged:
		apply_enrage()


func apply_enrage() -> void:
	if enraged:
		return
	enraged = true
	speed *= 1.8
	contact_cooldown *= 0.5
	_base_color = Color("#ff7b00")
	_body.color = _base_color


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.alive:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() > 4.0:
		velocity = to_player.normalized() * speed + _knockback
	else:
		velocity = _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	rotation = velocity.angle() if velocity.length() > 1.0 else rotation

	_touch_timer -= delta
	if _touch_timer <= 0.0:
		for b in _hit_area.get_overlapping_bodies():
			if b.is_in_group("player"):
				b.take_damage(damage)
				_touch_timer = contact_cooldown
				break


func _process(_delta: float) -> void:
	if _fog != null:
		visible = _fog.is_visible_world(global_position)


func take_damage(n: float, from_pos: Vector2) -> void:
	hp -= n
	_knockback = (global_position - from_pos).normalized() * 220.0
	_flash()
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.spawn_float_text(global_position, "%d" % int(n), Color(1, 1, 1))
	if hp <= 0.0:
		died.emit(global_position, gold_drop)
		queue_free()


func _flash() -> void:
	_body.color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_property(_body, "color", _base_color, 0.12)
