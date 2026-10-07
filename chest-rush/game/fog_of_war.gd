class_name FogOfWar
extends Node2D
## 迷雾已关闭：始终全图可见，不绘制遮罩。
## 保留接口以兼容 enemy/pickup/weapon 的 setup 签名。

var level: Node2D
var player: Node2D
var vision_radius := 99  # 保留字段；不再参与遮挡


func setup(level_map: Node2D) -> void:
	level = level_map
	visible = false  # 不参与渲染
	set_process(false)


func is_visible_world(_p: Vector2) -> bool:
	return true


func force_update() -> void:
	pass


func _draw() -> void:
	pass
