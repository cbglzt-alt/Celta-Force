# AGENTS.md — Celta-Force / chest-rush

> 世界观与概念见 `.thought/0.story.md`，玩法定位见 `.thought/2.next_phase.md`，
> **顶层路线图见 `.thought/4.roadmap.md`**，过程方法论见 `.thought/godot/0.recipe.md`。
> 本文沉淀**已被实践验证的工作方式**，新会话/新协作者（人或 AI）先读这篇。

## 项目是什么

披着搜打撤外壳的**塔防**：诡异复苏的架空现代都市里，普通人看不见规则；**驭鬼者**以自身为牢笼驾驭恶鬼，穿过「门」潜入**鬼域碎片**（关卡），搜集能压制复苏的关键遗物，再从门撤离——代价是每用一次力量，体内的鬼就更清醒一分。

### 顶层结构决策（已定调，详见 4.roadmap.md）

- **章节制**：一个主题 = 一个章节（一套剧情 + 一套美术 + 该章节多关），不做单关主题。
- **瓦片式可拼接地图**：一套瓦片组合出多种地图，服务章节美术复用。
- **武器（鬼）技能化**：当前刀/矢/域是最小原型，要能顺滑进化为 story 里的鬼技能（草绳/饿死/换头等）。
- **玩法本质**：移动塔塔防——被动攻击、数值比拼、读条搜刮、穿门撤离（无贪撤博弈，已证伪）。

### 核心概念

| 概念 | 游戏落地 |
|---|---|
| **驭鬼 / 驾驭** | 玩家 = 会走位的「移动塔」；每关开局固定 3 只己方鬼 = 3 个数据驱动的被动武器，自动索敌开火，人只管走位与搜刮 |
| **鬼域** | 关卡本体：某次灵异事件残留的碎片（学校、商场、荒村……）；敌方鬼按波次涌现 |
| **门** | 进出鬼域的通道 = 撤离点 |
| **关键道具** | 组织档案里的遗物；搜齐是通关条件，带出后可跨关永久成长 |
| **复苏** | 气质锚点：过度强化 / 滞留过久抬高敌压或己方失控预警（后期系统） |
| **级别 C/B/A/S** | 关卡与 Boss 威胁标签（危害范围，不等于单体强度） |

### 核心循环与策略

**被动攻击 → 数值比拼 → 在怪物变强前搜齐关键道具 → 穿门撤离。**  
策略在**火力成长曲线 vs 怪物增强曲线**：发育节奏、强化时机、敢不敢去更远的箱子。敌方精英讲究「看得见的规则」（敲门、朝向、伤害转移等），胜过纯数值膨胀。

详细设定、五柱鬼（敲门 / 草绳 / 替身 / 饿死 / 换头）与关卡剧本见 `.thought/0.story.md`。

- 引擎：Godot 4.7（`D:\Design\Godot_v4.7-stable_win64\`），项目 `chest-rush/`
- 语言：GDScript，俯视 2D，中文 HUD
- 部署：Web 导出 → `gh-pages` 分支，试玩链接 `https://cbglzt-alt.github.io/Celta-Force/`

---

## 数值平衡工作方式（对标业内最佳实践）

这是 2026-07 一系列"拍脑袋调参"踩坑后定下的规矩。**核心：数值是数据，不是代码。**

### 三条铁律

1. **数值全部放 Resource（.tres），不放代码常量。**
   武器 = `WeaponData.tres`，怪物 = `EnemyData.tres`（见下"数值在哪"）。调数值在 Inspector 拖滑块或改 .tres 文本，**不改 .gd 逻辑**。加新武器 = 新建一个 .tres，不碰代码。

2. **先算后调，再验证。**
   改任何数值前，先在 `.thought/3.balance.md` 的平衡表里改、看曲线关系（我方 DPS 增长 vs 怪物血量增长），确认方向再改 .tres。**禁止"凭感觉改一个数再说"。**

3. **每次调参记录基线，可对比可回退。**
   平衡表保留每次调整的前后值与试玩结论，能回答"这版是不是比上版好"，而不是改了就覆盖。

### 数值在哪（单一事实来源）

| 类别 | 文件 | 关键字段 |
|---|---|---|
| 武器（鬼） | `chest-rush/game/data/*.tres`（blade/arrow/domain） | damage / cooldown / attack_range / pattern / color |
| 怪物 | `chest-rush/game/data/enemy.tres` | base_hp / hp_growth / dmg_growth / gold_growth / speed |
| 对局节奏 | `game.gd` 顶部 `@export` | quest_target / round_interval / 强化费用曲线 |
| 破坏物 | `destructible.gd` 顶部 `@export` | 宝箱/障碍血量（chest_hp=150 / obstacle_hp=90） |

> 对局节奏与破坏物血量目前是 `@export`/常量，量小、改动少，暂不强行抽 Resource——**等有第二个关卡要复用时再抽**，避免过度设计。

### 平衡模型（心算基准）

塔防的本质是两条曲线的赛跑。目标区间：
- **我方 DPS 增长** 应**始终略落后**怪物血量增长——玩家需持续投入强化维持均势，后期被推向撤离。
- 参考值：怪物血量 `hp_growth≈1.28`/波；攻击强化每级 ×1.35 但费用 1.8 递增 → 有效 DPS 增长约 1.1–1.2/级，天然落后。
- 详表与每次调整记录见 `.thought/3.balance.md`。

### 自测开关

`godot --headless --path chest-rush --quit-after N -- --balance`：
跑一局（玩家站桩）自动输出每波：怪物血量/伤害/数量、玩家 DPS 上限、存活状况。**调参后先跑这个看方向对不对，再人肉试玩。**

---

## 开发流程规矩（recipe 落地）

- **以可玩版本为事实**：每次改动必须能跑起来验证，不积累"理论完成但没玩过"的代码。
- **一次只改一个可验证的变量**（血泪教训：一次三处加压，出问题无法归因，只能整体回退）。
- **同一模块反复调整超过 5 次，先停下来反思**：是否走偏、是否不符合业内最佳实践；对照资料/先例核对方向后再继续改，禁止在错误路径上继续微调。
- **"一定要做但当前阶段不做"的事，必须记进 `.thought/4.roadmap.md` 第三节（防遗忘清单）**：写清"为什么重要 + 什么时候做"，不许只在脑子里。roadmap 是顶层路径（不是 todo），随演进持续补充更新；进入新阶段先回读它，把该阶段的暂缓项捞出来排期。
- **验证三板斧**：① `godot --headless --editor --quit` 刷新类缓存查语法；② `--headless --quit-after N` 查运行时错误；③ 需要看画面时用 CDP 截图（脚本 `build/cdp_shot.mjs`）。

## Godot 工程备忘（踩过的坑）

- **新增/重命名全局 `class_name` 后**，必须先跑 `--headless --editor --quit` 刷新类缓存，否则直接运行报 "Identifier not declared"。
- **`--quit-after N` 是帧数不是秒数**（60fps 下 N 帧 ≈ N/60 秒）。
- **物理 flush 内不能创建/销毁碰撞体**（弹体命中→敌死→掉落在物理回调里 new Area2D 会报 "flushing queries"）。解法：`call_deferred` / `set_deferred` 延迟到物理步外。
- **改 `.gd` 后 web/无头偶尔跑旧缓存**，行为对不上时先 `--editor --quit` 刷新再测。
- **LOS（视线）判定**：射线起点用玩家位置；"命中点距目标 < 半格"判为打到目标自身（可见），否则途中第一个遮挡即挡住。勿用"线段进度 t≥0.99"，薄墙会失效。
- **变量类型推断**：字典/混合类型数组取值后 `:=` 推断会失败，显式标注类型（`var n: Vector2i = ...`）。

## 部署 Web 版

```bash
# 导出（export_presets.cfg 已配好 Web 预设，单线程兼容 Pages）
godot --headless --path chest-rush --export-release "Web" "E:\Lyc\Celta-Force\build\web\index.html"
# 部署
cd build/web && touch .nojekyll && git add -A && git commit -m "Deploy" && git push -f git@lyc.github.com:cbglzt-alt/Celta-Force.git gh-pages
```
中文用随包子集字体 `game/fonts/NotoSansSC-Subset.otf`（OFL 许可），新增文案字符需重新子集化（脚本见 `.thought` 或重做 `pyftsubset`）。
