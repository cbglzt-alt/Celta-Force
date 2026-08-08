class_name EnemyData
extends Resource
## 怪物数值定义与随波增长曲线。改数值在 Inspector 或 .tres 文本里，不改 enemy.gd。

@export var base_hp := 70.0
@export var base_speed := 90.0
@export var base_damage := 5.0
@export var contact_cooldown := 1.0
@export var base_gold := 4
@export var hp_growth := 1.28
@export var dmg_growth := 1.15
@export var gold_growth := 1.13
@export var speed_growth := 1.02
@export var speed_cap_mult := 1.6
@export var enrage_speed_mult := 1.8
@export var enrage_cooldown_mult := 0.5


## 第 round_num 波的实际血量（round_num 从 1 起）
func hp_at(round_num: int) -> float:
	return base_hp * pow(hp_growth, maxi(round_num - 1, 0))


func damage_at(round_num: int) -> float:
	return base_damage * pow(dmg_growth, maxi(round_num - 1, 0))


func gold_at(round_num: int) -> int:
	return int(round(base_gold * pow(gold_growth, maxi(round_num - 1, 0))))


func speed_at(round_num: int) -> float:
	var r := maxi(round_num - 1, 0)
	return minf(base_speed * pow(speed_growth, r), base_speed * speed_cap_mult)
