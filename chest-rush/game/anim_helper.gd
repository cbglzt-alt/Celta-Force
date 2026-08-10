class_name AnimHelper
extends RefCounted
## 把 32px 高的水平 spritesheet 组装成多动画 SpriteFrames。
## 每个动画一张图，宽÷32 = 帧数。供 enemy/elite 共用，避免重复切帧代码。

const CELL := 32  # 默认每帧 32×32（dungeon 怪物）

## anims: { "idle": "路径.png", ... }；cell = 每帧边长（怪物 32，Soldier 100）
## 返回装配好的 AnimatedSprite2D（含全部动画，默认播 idle）。
static func build_sprite(anims: Dictionary, speed := 8.0, scale := 2.0, cell := CELL) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	for name in anims:
		var path: String = anims[name]
		var frames := _slice(path, cell)
		if frames.is_empty():
			continue
		sf.add_animation(name)
		sf.set_animation_speed(name, speed)
		# death/hurt/attack 不循环；idle/walk 循环
		sf.set_animation_loop(name, name == "idle" or name == "walk")
		for tex in frames:
			sf.add_frame(name, tex)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.scale = Vector2(scale, scale)
	if sf.has_animation("idle"):
		s.play("idle")
	return s


## 把一张水平 spritesheet 切成逐帧 Texture2D（cell×cell）
static func _slice(path: String, cell: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var img := load(path)
	if img == null:
		return out
	var src: Image = img.get_image()
	var n := int(src.get_width() / cell)
	for i in n:
		var region := Rect2i(i * cell, 0, cell, cell)
		var sub := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		sub.blit_rect(src, region, Vector2i.ZERO)
		out.append(ImageTexture.create_from_image(sub))
	return out
