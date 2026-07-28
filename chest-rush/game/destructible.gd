class_name Destructible
extends StaticBody2D
## 可摧毁物：按攻击次数计血（设计：摧毁障碍、宝箱需多次攻击）。
## OBSTACLE 障碍：存活时挡视野；CHEST 宝箱：掉金币/视野道具/任务道具。

signal destroyed(d)

enum Kind { OBSTACLE, CHEST }

var kind: Kind
var hits_left := 2
var has_quest := false
var tile := Vector2i.ZERO

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("destructibles")


func setup(k: Kind, t: Vector2i) -> void:
	kind = k
	tile = t
	if kind == Kind.OBSTACLE:
		hits_left = 2
		_body.polygon = _square_poly(13.0)
		_body.color = Color("#8b6f47")
	else:
		hits_left = 3
		_body.polygon = _square_poly(12.0)
		_body.color = Color("#c98a2d")


func hit(n: int) -> void:
	hits_left -= n
	_shake()
	if hits_left <= 0:
		destroyed.emit(self)
		queue_free()


func _shake() -> void:
	# 受击白闪 + 轻抖
	_body.modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_body, "modulate", Color(1, 1, 1), 0.15)
	var p0 := _body.position
	tw.tween_property(_body, "position", p0 + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.05)
	tw.tween_property(_body, "position", p0, 0.1)


func _square_poly(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
