# Chest Rush · P4 视觉探索提示词组

> 用法：复制每组提示词到你的生图工具（GPT-image / Midjourney / 即梦等），图存到本目录（`.thought/art/`）。
> 目标：定"视觉承诺"，**不进引擎**。3–5 张风格探索 + 1 张构图目标图即可，别贪多。
> 全部提示词已按本项目的硬性约束调好（见下"通用后缀"会自动拼在每组后面）。

---

## 〇、硬性约束（每组都必须满足，这是本游戏的命根）

这游戏是**俯视 2D 塔防 + 战争迷雾**，屏幕上永远有几十个小单位。所以：

- **高对比度剪影**：角色一眼靠轮廓认出，不靠脸和细节。
- **深色背景上的强可读性**：角色要在近黑的迷雾背景上跳出来。
- **恐怖喜剧基调**：诡异但带点俏皮（可爱的饿死鬼、嘴贱主角），**不做纯血腥惊悚**。
- **禁止**：写实照片风、繁琐纹理、低对比灰蒙蒙、文字/水印/logo。

---

## 一、风格探索（先各来 2–3 张，挑感觉）

### S1 整体氛围 · 场景概念
```
top-down 2D game concept art, a haunted abandoned school hallway at night, dark fog closing in, eerie teal-and-purple palette with a single warm lantern glow, floating spectral silhouettes, spooky-but-playful horror-comedy mood, bold shapes, clean silhouettes, high contrast, stylized indie game look, no text, no watermark
```

### S2 风格变体 · 更卡通
```
top-down 2D game art, cartoonish ghost-hunting protagonist standing in a dark haunted school, chunky bold outlines, flat colors with soft gradients, vibrant accent colors against deep shadow, cute-but-creepy chibi ghosts floating around, horror-comedy, high readability silhouettes, stylized, no text
```

### S3 风格变体 · 更阴森
```
top-down 2D game concept, dark moody haunted school corridor, heavier fog and shadow, desaturated cold palette with a faint sickly green glow, subtle dread but still stylized not realistic, strong rim light on a lone protagonist silhouette, horror with restraint, clean shapes, no text
```

> **挑哪张**：选"一眼能看清主角、迷雾有压迫感但不脏"的那张。S1 通常是甜点区。

---

## 二、角色识别草图（定"长什么样一眼认出"）

> 每个一张，白底或透明感，重点是**轮廓**。俯视微侧（three-quarter top-down）。

### C1 主角 · 驭鬼者（移动的塔）
```
character concept art, three-quarter top-down view, a calm pragmatic ghost-tamer protagonist for a 2D tower-defense game, ordinary modern person with a subtle eerie glow, simple bold silhouette, horror-comedy, flat stylized colors, high contrast, clean readable shape, plain dark background, no text
```

### C2 草绳鬼（己方 · 控场）
```
character concept, three-quarter top-down, a spectral hanging-rope ghost for a 2D game, an eerie animated straw rope with a faint ghostly face, coiling and reaching, spooky but stylized, bold silhouette, flat colors, high contrast, plain dark background, no text
```

### C3 饿死鬼（己方 · 成长输出 · 恐怖喜剧担当）
```
character concept, three-quarter top-down, a cute-but-creepy gluttonous ghost pet for a 2D game, small round body, comically huge unsettling mouth, endearing yet wrong, horror-comedy, bold readable silhouette, flat stylized colors, plain dark background, no text
```

### C4 换头鬼 / 假模特（己方 · 变招）
```
character concept, three-quarter top-down, a headless department-store mannequin ghost holding a stolen head, uncanny but stylized, bold silhouette, flat colors, high contrast, plain dark background, no text
```

### C5 鬼奴（敌 · C 级杂兵，会大量出现）
```
character concept, three-quarter top-down, a shambling ghost-thrall minion for a 2D game, humanoid but stiff and wrong, blank eerie face, simple bold silhouette readable at small size, muted colors with one eerie accent, plain dark background, no text
```

### C6 敲门鬼（敌 · A 级精英，本关 Boss 气质）
```
character concept, three-quarter top-down, a tall gaunt door-knocking ghost in dark old-fashioned clothes, slowly raising a fist toward an old wooden door, oppressive eerie aura, horror with restraint, bold silhouette, flat stylized colors, plain dark background, no text
```

---

## 三、关键物件识别草图

### O1 宝箱（可搜集）
```
game asset concept, top-down, a stylized loot chest for a dark 2D game, slightly eerie but clearly a reward, bold readable shape, warm inviting glow against dark theme, flat colors, plain dark background, no text
```

### O2 「门」（撤离点）
```
game asset concept, top-down, a mysterious glowing door standing alone for a 2D game, eerie but clearly an exit/goal, strong silhouette, ethereal light spilling out, stylized, plain dark background, no text
```

---

## 四、构图目标图（1 张，定最终画面承诺）

> 这是最重要的一张——直接画"游戏实际看起来什么样"。

```
top-down 2D tower-defense game screenshot concept, a ghost-tamer protagonist with three small ghost companions orbiting them, standing in a dark haunted school map viewed from above, fog-of-war darkness closing in at the edges, several shambling ghost enemies approaching through corridors, a glowing loot chest and a distant glowing exit door, clean bold silhouettes, high contrast, teal-purple-dark palette with warm accent glows, horror-comedy, stylized indie game, no text, no UI
```

---

## 五、生成完告诉我

把图丢进 `.thought/art/` 后说一声，我会：
1. 逐张读图，挑出可读性/风格最好的；
2. 从选定的图里**提取色板**（主色/迷雾色/敌我区分色/警告色）；
3. 写成 `0.thought/art/visual_direction.md`（镜头角度+色板+轮廓规则+信息优先级），作为 P5 垂直切片的美术基准。
```
