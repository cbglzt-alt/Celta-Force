---
name: godot-docs-translate
description: Locates Godot official documentation sections from the local godot-docs repo, translates them to Chinese, and saves structured markdown under .thought/godot/. Use when the user wants to learn, read, or translate Godot official docs, tutorial series (step_by_step, first_2d_game, etc.), or asks to continue Godot learning after step_by_step.
---

# Godot 官方文档翻译与学习

将本地 Godot 官方文档（RST）翻译为中文 Markdown，按目录结构存入项目 `.thought/godot/`，供学习者对照 Godot 编辑器实操。

## 必要上下文（新会话也适用）

| 项 | 值 |
|---|---|
| 游戏项目 | `chest-rush`（Godot 4.7，路径 `Celta-Force/chest-rush/`） |
| 本地官方文档 | `E:\Lyc\godot-docs`（master，与 Godot 4.x 对齐） |
| 本地 Demo | `E:\Lyc\godot-demo-projects` |
| Godot 编辑器 | `D:\Design\Godot_v4.7-stable_win64` |
| 译文输出根目录 | `Celta-Force/.thought/godot/` |
| 学习者背景 | 有 Java 等编程经验，Godot/GDScript 零基础 |
| 学习路线 | `step_by_step` → `first_2d_game` → 按 `0.recipe.md` 做 chest-rush 灰盒 |

环境说明亦见 `.thought/2.godot.md`。

## 触发后工作流

```
1. 解析用户请求 → 定位官方文档路径
2. 读取 RST 源文件（及 index.rst 目录）
3. 检查 .thought/godot/ 是否已有译文，避免重复
4. 翻译并写入 .zh.md 文件
5. 创建或更新该系列的 00.index.zh.md
6. 向用户汇报：存了哪些文件、建议阅读顺序、与 chest-rush 的关联
```

### Step 1：定位文档

用户可能说「first_2d_game 第 3 章」「step_by_step 的 instancing」「信号那一篇」等。

**解析顺序：**

1. 查 [reference.md](reference.md) 的系列映射表
2. 在 `E:\Lyc\godot-docs` 用 Glob/Grep 搜索 `.rst` 文件名或标题
3. 读该系列的 `index.rst` 确认 toctree 顺序与章节列表
4. 若用户说「整系列」或「下一部分」，对照已有 `00.index.zh.md` 中「待译」项

**常见系列路径：**

| 用户说法 | 源目录 |
|---------|--------|
| step by step / 循序渐进 | `getting_started/step_by_step/` |
| first 2d game / 第一个 2D 游戏 | `getting_started/first_2d_game/` |
| introduction / 简介 | `getting_started/introduction/` |
| first 3d game | `getting_started/first_3d_game/` |

在线对照 URL：`https://docs.godotengine.org/en/stable/<路径去掉.rst>.html`

### Step 2–4：翻译与保存

**输出目录规则**（详见 [reference.md](reference.md)）：

```
.thought/godot/
├── 0.recipe.md              # 项目开发路线（勿覆盖）
├── step_by_step/
│   ├── 00.index.zh.md       # 系列导读 + 章节索引
│   ├── 01.nodes_and_scenes.zh.md
│   └── ...
└── first_2d_game/
    ├── 00.index.zh.md
    ├── 01.project_setup.zh.md
    └── ...
```

**单篇文件头部模板：**

```markdown
# [中文标题]（[English Title]）

> 原文：`godot-docs/<相对路径>.rst`
> 官方在线版：<stable URL>

[正文…]
```

**翻译规范**（精简版，细则见 reference.md）：

- 正文中文；**代码块、节点类名、快捷键、菜单路径保持英文**（与编辑器一致）
- 菜单/按钮格式：`**Add Child Node**（添加子节点）**
- 配图不写死绝对路径时，用 `img/xxx.webp`，并注明「相对于原文目录，本地完整路径见 `E:\Lyc\godot-docs\...`」
- RST 的 `.. note::` / `.. tip::` → Markdown 引用块 `>`
- 每篇末尾加 **「本篇你要记住的概念」** 表格（3–6 行）
- 只译 **GDScript** 代码块；C#  tab 可注明「本篇仅 GDScript，C# 见原文」
- 不翻译 `:ref:` 交叉引用为链接时，用中文描述 + 原文档 ID 注释

**编号规则：**

- 系列索引：`00.index.zh.md`
- 章节：`{两位序号}.{源文件名去掉.rst}.zh.md`（序号与 index.rst toctree 一致）
- 例：`03.coding_the_player.rst` → `03.coding_the_player.zh.md`

### Step 5：更新索引

每译完一篇，更新该系列 `00.index.zh.md`：

- 章节表：英文文件名 | 中文译名 | 链接 | 状态（已译/待译）
- 若有「建议阅读顺序」或前置章节依赖，一并维护
- 与 `step_by_step` 已完成译文风格对齐（见 `.thought/godot/step_by_step/00.index.zh.md`）

### Step 6：回复用户

汇报结构：

1. **译了什么**（文件路径列表）
2. **建议怎么学**（顺序、预计耗时、要先做哪些实操）
3. **和 chest-rush 的关系**（哪些技能会用到搜打撤 MVP）
4. **下一篇建议**（根据 index 待译项）

## 批量 vs 单篇

| 请求 | 行为 |
|------|------|
| 「翻译 first_2d_game 第 2 章」 | 只译一篇 + 更新 index |
| 「翻译整个 first_2d_game」 | 按 toctree 顺序逐篇译，每篇独立文件 |
| 「继续 step_by_step」 | 读 index 找下一篇「待译」，译完并更新 |

系列超过 3 篇且用户未明确要求全部时，先译用户指定篇，并询问是否继续。

## 不要做的事

- 不要修改 `E:\Lyc\godot-docs` 源文件
- 不要覆盖 `.thought/godot/0.recipe.md`（项目路线）
- 不要提交 git（除非用户明确要求）
- 不要把 `.godot/` 缓存写进译文
- 不要凭空编造教程步骤；以 RST 原文为准

## 附加资源

- 目录映射、RST 语法对照、已完成译文清单：[reference.md](reference.md)
- 现有译文范例：`.thought/godot/step_by_step/01.nodes_and_scenes.zh.md`
