# 提示词：allowlist → 任务类型 + token 估算

## 你的任务

为元素地牢项目的调度 graph 实现一个**成本估算模块**。输入是任务的 allowlist，输出是任务类型标签和 token 消耗估算，供 graph 做批次装箱决策。

## 背景

项目正在把中枢 Agent 的调度职责程序化。原先中枢要人工判断"这个任务属于什么类型、大概多重、能不能和别的任务打包进同一个会话"，现在要由程序算。目标是把中枢的输出压缩到最小：

**中枢只提供**（其余全部由你的模块推导）：

1. `allowlist`：glob 列表，每行一个裸 glob，不带注释、不带条件
2. `change_kind`：每个 allowlist 项一个枚举值，取值 `add-field | local-logic | control-flow | migrate-consumers | asset-produce`
3. 三个布尔：`needs_godot` / `needs_screenshot` / `needs_cold_root`

**你要输出**：

- `domain`：任务的主域标签（多域任务返回域集合 + 主域）
- `est_tokens`：估算区间 `{low, high}`，不是点估计
- 装箱所需的派生字段（见下）

## 第一部分：类型计算

从 glob 推导 `(domain, ext)` 二元组。

### 域映射表（按路径前缀，必须走二级路径）

| 前缀 | domain |
|---|---|
| `assets/**` | art-asset |
| `combat/**` | gameplay |
| `growth/**` | gameplay |
| `scripts/run/**` | gameplay |
| `scripts/ui/**` | ui |
| `scripts/vfx/**` | vfx |
| `scenes/vfx/**` | vfx |
| `resources/vfx/**` | vfx |
| `scenes/**`（其余） | scene |
| `resources/**`（其余） | data |
| `**/tests/**` | test（优先级高于上述所有） |
| `docs/**` | doc |
| `addons/**` | vendor |

注意 `scripts/` 是混合桶（`scripts/run` / `scripts/ui` / `scripts/vfx` / `scripts/tools` 分属不同域），不能按顶级目录映射。

### 扩展名维度

`ext` 独立于 domain，因为它对成本的预测力更强：

- `.gd`：人写代码，行数与阅读成本正相关
- `.tscn` / `.tres`：机器生成，文件可能很大但改动通常极小 —— 读取成本高、写入成本低，两者必须分开计
- `.png` + `.import`：不进 token 读取成本，走 asset 专用模型
- `.md`：任务书/文档，读取成本按实际行数，写入成本低

### 多域任务

一个 allowlist 常跨多个域（例如代码 + evidence 目录 + 任务书自身）。装箱判据里的"同类型"应按**主域**判定，主域 = 排除 `doc` 和 `test` 后 token 占比最大的域。`doc`/`test` 项计入成本但不参与域冲突判定。

## 第二部分：token 估算思路

### 核心结构

```
est = read_cost + write_cost + iterate_cost
```

三项的性质完全不同，不要用统一系数糊在一起。

**read_cost（通常是大头）**

展开 glob 拿到实际文件，`wc -l` 得到真实行数——这是你相对已知的量，别让上游估。但注意：**allowlist 文件行数是下界，不是实际读取量**。执行者还要读任务书、读依赖文件、读被调用方的签名。需要一个 fanout 系数放大，且 fanout 与 `change_kind` 强相关：

- `add-field`：几乎不需要读上下文，fanout ≈ 1.2
- `local-logic`：要读同文件周边和直接依赖，fanout ≈ 2
- `control-flow`：要读整条调用链，fanout ≈ 3~4
- `migrate-consumers`：要读所有消费者（数量未知，这是方差最大的一档），fanout ≈ 5+，且建议对这一档直接给很宽的区间

**write_cost**

由 `change_kind` 决定，**与文件大小基本无关**——给一个 `@export` 加字段，文件 200 行还是 2000 行，写出来的 diff 一样大。所以这项是查表常数，不要乘行数。

**iterate_cost**

跑测试、看失败、改、再跑的循环。这是方差最大的一块，主要由三个布尔驱动，基本是常数项加成而非比例项：

- `needs_godot`：编辑器/运行时日志会灌进上下文，加成显著
- `needs_screenshot`：每张图有固定 token 成本，且视觉验收常需多轮
- `needs_cold_root`：冷副本搭建 + 独立跑一遍，加成最大

### asset-produce 走独立模型

`domain == art-asset` 且 `change_kind == asset-produce` 时，上面的模型不适用。图片生产的成本由**产出图数量**驱动（glob 展开后的目标文件数），加上参考图读取的固定成本。代码模型的行数逻辑在这里没有意义。

### 关键：误差应当不对称

估算是给装箱用的，两个方向的代价不对等：

- **低估**：会话中途触发上下文压缩，批次后段的子项在最差状态下执行，质量下滑且难以察觉
- **高估**：装载率低一点，多开一个会话

所以系数应当**保守偏高**，装箱决策用区间的 `high` 端而不是均值。宁可装不满，不要装爆。

### 校准

项目有 56 份已归档任务（`docs/agent_tasks/completed/`），是现成的样本集，可以反推 fanout 和常数项。

但先确认一件事：**历史任务的实际 token 消耗有没有被记录下来**。如果没有，不要试图从任务书内容反推真实消耗——那只是换个方式猜。更现实的路径是：先用粗系数上线，让 graph 在每次派发结束后记录 `(输入特征, 实际消耗)`，滚动回归校准。冷启动阶段把区间给宽，随样本积累收窄。

## 第三部分：需要你判断的开放点

以下我没有定论，按你的实现权衡后给出结论和理由：

1. `.tscn` 的读取成本是否值得单独建模——它可能占 read_cost 很大比例但几乎不产生 write_cost，是否需要一个独立的"只读大文件"通道
2. 区间宽度怎么定：固定倍率（如 `high = 2 × low`）还是随 `change_kind` 的方差档位变化
3. `migrate-consumers` 的消费者数量能否从代码里静态求出（grep 符号引用），如果能，这一档的方差可以大幅收窄——评估可行性
4. 多域任务的 `est_tokens` 是否可以简单相加，还是存在跨域切换的额外开销

## 输出要求

先给设计（数据结构、映射表、公式、系数初值及其依据），再给实现。系数初值必须写明是猜的还是有依据的，不要把拍脑袋的数字写得像标定过。
