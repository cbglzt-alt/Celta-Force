# Godot 文档翻译参考

## 本地路径

```
E:\Lyc\godot-docs\                    # 官方文档源码（RST）
E:\Lyc\godot-demo-projects\           # 官方 Demo（对照 first_2d_game 成品）
E:\Lyc\Celta-Force\chest-rush\        # 用户的 Godot 项目
E:\Lyc\Celta-Force\.thought\godot\    # 译文输出根目录
```

## getting_started 系列映射

### step_by_step（6 篇）

源目录：`getting_started/step_by_step/`

| 序号 | 源文件 | 建议中文标题 | 译文路径 | 状态 |
|------|--------|-------------|----------|------|
| — | index.rst | 导读 | `step_by_step/00.index.zh.md` | 已译 |
| 01 | nodes_and_scenes.rst | 节点与场景 | `step_by_step/01.nodes_and_scenes.zh.md` | 已译 |
| 02 | instancing.rst | 实例化场景 | `step_by_step/02.instancing.zh.md` | 待译 |
| 03 | scripting_languages.rst | 脚本语言概览 | `step_by_step/03.scripting_languages.zh.md` | 待译 |
| 04 | scripting_first_script.rst | 创建你的第一个脚本 | `step_by_step/04.scripting_first_script.zh.md` | 已译* |
| 05 | scripting_player_input.rst | 玩家输入 | `step_by_step/05.scripting_player_input.zh.md` | 待译 |
| 06 | signals.rst | 使用信号 | `step_by_step/06.signals.zh.md` | 已译* |

\* **编号不一致**：早期译文用 `02.scripting_first_script`、`03.signals`（跳过了 instancing 等序号）。新译文应改为上表编号；若用户未要求整理，新篇按正确序号追加，index 中注明旧文件别名。

### first_2d_game（7 篇）

源目录：`getting_started/first_2d_game/`

| 序号 | 源文件 | 建议中文标题 | 译文路径 |
|------|--------|-------------|----------|
| — | index.rst | 导读 | `first_2d_game/00.index.zh.md` |
| 01 | 01.project_setup.rst | 项目设置 | `first_2d_game/01.project_setup.zh.md` |
| 02 | 02.player_scene.rst | 玩家场景 | `first_2d_game/02.player_scene.zh.md` |
| 03 | 03.coding_the_player.rst | 编写玩家代码 | `first_2d_game/03.coding_the_player.zh.md` |
| 04 | 04.creating_the_enemy.rst | 创建敌人 | `first_2d_game/04.creating_the_enemy.zh.md` |
| 05 | 05.the_main_game_scene.rst | 主游戏场景 | `first_2d_game/05.the_main_game_scene.zh.md` |
| 06 | 06.heads_up_display.rst | 游戏 HUD | `first_2d_game/06.heads_up_display.zh.md` |
| 07 | 07.finishing-up.rst | 收尾 | `first_2d_game/07.finishing-up.zh.md` |

配图目录：`getting_started/first_2d_game/img/`

**前置**：step_by_step 基础；需下载素材  
`https://github.com/godotengine/godot-docs-project-starters/releases/download/latest-4.x/dodge_the_creeps_2d_assets.zip`

**成品 Demo**：`godot-demo-projects/2d/dodge_the_creeps/`

### introduction（简介，可选）

源目录：`getting_started/introduction/`

按需创建 `introduction/00.index.zh.md` 及分篇译文。

## 输出目录命名规则

```
.thought/godot/{系列名}/
├── 00.index.zh.md              # 系列总览、章节表、学习建议
├── {NN}.{源文件名}.zh.md       # 单篇译文，NN 与 toctree 顺序一致
└── （无 img 副本；配图引用源文档路径）
```

系列名 = 源目录最后一级，如 `step_by_step`、`first_2d_game`。

## RST → Markdown 对照

| RST | Markdown |
|-----|----------|
| `===` / `---` 标题 | `#` / `##` / `###` |
| `` :ref:`doc_xxx` `` | 中文描述 + 可选在线链接 |
| `.. note::` | `> **注意**` |
| `.. tip::` | `> **提示**` |
| `.. seealso::` | `> **参见**` |
| `.. code-block::` / `.. tabs::` |  fenced code block，语言 `gdscript` |
| `.. image:: img/x.webp` | `配图：\`img/x.webp\`` |
| `:kbd:`F6`` | **F6** |
| `:button:`Run`` | **Run** |
| `:ui:`Scene`` | **Scene（场景）** |
| `:menu:`Scene > New Scene`` | **Scene → New Scene** |
| 外部 URL | 保留原链接 |

## 翻译风格

- 语气：教学向、第二人称「你」
- 术语一致：

| 英文 | 中文 |
|------|------|
| Node | 节点 |
| Scene | 场景 |
| Signal | 信号 |
| Inspector | Inspector（检查器） |
| Viewport | 视口 |
| Main scene | 主场景 |
| Instantiate | 实例化 |
| delta | delta（帧间隔，不译） |

- 代码注释可译；标识符不译
- 章节过长（>400 行 RST）仍保持单文件，用 `---` 分节

## 学习路线上下文（写入 index 时用）

```text
step_by_step（基础）
  ↓
first_2d_game（完整小游戏 Dodge the Creeps）
  ↓
0.recipe.md Phase 2（chest-rush 搜打撤灰盒 MVP）
```

**first_2d_game 与 chest-rush 技能映射：**

| 教程内容 | chest-rush 用途 |
|---------|----------------|
| TileMap / 场景结构 | 固定关卡地图 |
| 玩家移动 + 碰撞 | 俯视角移动 |
| 敌人生成 Timer | 轮次刷怪 |
| Area2D / 信号 | 拾取、碰撞、Game Over |
| HUD / UI | 分数、倒计时、撤离 UI |
| 正交相机 / 窗口设置 | 手机多分辨率视野 |

## 检索技巧

在 `E:\Lyc\godot-docs` 中：

```bash
# 按文件名
Glob: **/first_2d_game/*.rst

# 按标题关键词
Grep: pattern="Your first 2D game" path=godot-docs/getting_started
```

用户给的在线 URL 可反推 RST 路径：  
`/en/stable/getting_started/first_2d_game/03.coding_the_player.html`  
→ `getting_started/first_2d_game/03.coding_the_player.rst`

## 00.index.zh.md 模板

```markdown
# Godot 入门：[系列中文名]（中文导读）

> 原文：`E:\Lyc\godot-docs\<系列路径>\`
> 官方在线版：https://docs.godotengine.org/en/stable/<系列路径>/index.html

## 这套教程是干什么的

[2–4 句概述]

## 完整目录

| 序号 | 英文文件名 | 中文译名 | 本仓库译文 |
|------|-----------|----------|------------|
| 01 | xxx.rst | … | [链接](./01.xxx.zh.md) 或 待译 |

## 建议阅读顺序

[针对 Java 背景、已有译文进度]

## 配图说明

本地配图：`E:\Lyc\godot-docs\<系列路径>\img\`
```

## 已完成译文清单（维护用）

执行翻译前读取 `.thought/godot/**/` 下现有 `*.zh.md`，避免重复劳动。

当前已有：

- `step_by_step/00.index.zh.md`
- `step_by_step/01.nodes_and_scenes.zh.md`
- `step_by_step/02.scripting_first_script.zh.md`（建议日后重命名为 `04.*`）
- `step_by_step/03.signals.zh.md`（建议日后重命名为 `06.*`）
