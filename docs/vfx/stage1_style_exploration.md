# VFX 任务 17：第一阶段风格探索

状态：等待用户确认风格；本阶段文件均为概念稿，不是可直接入库资产。

## 参考基线

- 目标画面：1152×648 横版 TestRoom，深色地牢背景。
- Player：64×64 源帧、场景缩放 2；碰撞半径约 15～16。
- Enemy：100 像素高源帧、场景缩放 3；碰撞半径约 16～18。
- 既有元素弹：逻辑半径 6；当前绘制核心半径 5.5、外环半径 9.5、短拖尾 14。
- Godot 运行截图暂时被工作区内既有脚本迁移和 Windows 子进程启动错误阻塞。本阶段使用 2D 编辑器视图校准 Player、Enemy、平台和 HUD 的相对比例，并直接读取投射物绘制参数。第二阶段开始前必须补做真实运行截图与前后层级检查。

## 推荐风格方向

采用“清晰像素辉光”：

- 2D 像素/低分辨率友好轮廓，主体使用 3～5 级明暗。
- 白灰核心承担可着色信息，外层只保留窄幅元素色辉光。
- 水：圆润液滴、涟漪、内聚弧线。
- 火：尖锐火舌、裂纹、向外爆发轮廓。
- 不使用写实烟雾、镜头光晕或大面积半透明雾。
- 主体边界可对齐逻辑范围；只允许稀疏余辉轻微越界。

风格基准：

- `assets/generated/vfx/concepts/style_baseline_v1.png`

## 六技能概念稿

| 技能 | 概念稿 | 表现语义 | 第二阶段建议输出 |
|---|---|---|---|
| `element_bolt` | `assets/generated/vfx/concepts/element_bolt_concept_v1.png` | 小型核心、14 像素级短拖尾、命中闪光；水火依靠形状与颜色双重区分 | 图标走简单 alpha；弹体、拖尾、命中走灰度核心/遮罩 + 着色 |
| `elemental_fury` | `assets/generated/vfx/concepts/elemental_fury_concept_v1.png` | 蓄力/提交、一次主爆发、稀疏余辉；冲击环可校准并可缩放到 2.0 倍 | 图标走简单 alpha；爆发核心与冲击环走颜色图 + 遮罩 |
| `elemental_laser` | `assets/generated/vfx/concepts/elemental_laser_concept_v1.png` | 起点聚能、可重复 Beam、穿透式目标闪光、0.5 秒脉冲 | 图标走简单 alpha；Beam 必须自制可平铺颜色图 + 灰度遮罩 |
| `element_reclaim` | `assets/generated/vfx/concepts/element_reclaim_concept_v1.png` | 多目标元素向玩家内收，成功时一次汇聚闪光；失败不播放 | 图标走简单 alpha；弧线/粒子走灰度遮罩 + 着色，汇聚闪光走黑底加法 |
| `burning` | `assets/generated/vfx/concepts/burning_concept_v1.png` | 小型固定火层标记与每秒一次短促 Tick；不表现层数消耗 | 图标走简单 alpha；火标记可用 alpha 序列，Tick 火花可用黑底加法 |
| `unending` | `assets/generated/vfx/concepts/unending_concept_v1.png` | 固定水语义的液滴与涟漪恢复；不表现层数消耗 | 图标走简单 alpha；液滴可用 alpha 序列，涟漪走颜色图 + 遮罩或黑底加法 |

## 锁定的战斗语义

- 元素弹：CURRENT_ELEMENT，固定消耗 10 能量，100% 攻击力，小型投射物，附着 1 层。
- 元素之怒：最低 20 能量，消耗全部当前能量；20 能量为 160%/1 层，100/100 为 800%/5 层/2.0 倍半径；只有一个逻辑命中窗。
- 元素激光：接受时锁定元素和攻击力；每完整 0.5 秒一次 Tick，消耗 5 能量、造成 50% 攻击力伤害并附着 1 层；穿透全部合法目标。
- 回收：锁定当前元素，冷却 5 秒，不耗能；成功时吸收范围内全部匹配层数，每层理论恢复 5 能量；无匹配或满能量不播放成功表现。
- 燃烧：固定读取目标火层，每满 1 秒触发一次，伤害为火层数 × 5% 攻击力；不消耗火层，不读取玩家 CurrentElement。
- 不息：固定普攻成功命中后读取目标水层，恢复水层数 × 1 生命；不消耗水层，不读取玩家 CurrentElement。

任务 15 尚未验收，因此元素之怒基础逻辑半径、激光 Beam 长宽、回收查询半径、生成点和结束时序尚未冻结。概念稿不声明这些尺寸；第二阶段必须等待任务 15 提供只读 VFX 基准。

## Imagegen 模式与提示词记录

实际模式：内置 `image_gen`。未使用 CLI、API key 或原生透明模型。概念图使用深色审查底，不进行 alpha 去背。

### 风格基准

```text
Use case: stylized-concept
Asset type: 2D game VFX style baseline sheet for a 1152x648 side-scrolling dungeon game
Input images: actual Godot TestRoom screenshot, used only for scale, contrast, pixel density, and cat-versus-enemy readability
Primary request: six representative motifs in a clean 3-by-2 grid: projectile/hit, burst/ring, beam/pulse, inward reclaim, fire tick, water heal ripple
Style: crisp low-resolution-friendly 2D VFX, 3-to-5 value steps, controlled glow, neutral tintable cores
Constraints: no text, UI, characters, watermark, realistic smoke, photorealism, or collision guides
```

### 元素弹

```text
Tintable compact elemental projectile concept: icon silhouette, neutral core, short trail, water/fire shape studies, concise hit flash. Match a 12-pixel-diameter logical projectile and roughly 14-pixel trail. Water is rounded; fire is pointed. No text, UI, characters, watermark, smoke, lightning symbol, oversized bloom, or long trail.
```

### 元素之怒

```text
All-energy circular burst concept: icon, tight charge/commit core, one decisive explosion with a calibratable shock-ring boundary, sparse fading particles, scalable from base radius to double radius. No continuous field, repeated hit pulses, text, UI, characters, watermark, realistic smoke, debris cloud, or oversized overflow.
```

### 元素激光

```text
Sustained piercing horizontal elemental beam concept: icon, repeatable beam segment with tintable core and edge noise, origin charge flare, target-crossing pulse every 0.5 seconds while continuing through multiple targets. Include grayscale mask logic and color examples. No text, UI, characters, watermark, lightning zigzag, opaque fog, lens flare, first-target stop, or wide bloom.
```

### 回收

```text
Successful element reclaim concept: icon, target extraction marks, curved particles traveling inward from multiple points, restrained convergence flash. Water uses rounded droplets; fire uses pointed fragments. No failure effect, text, UI, characters, watermark, energy bar, healing cross, smoke, outward blast, or lingering field.
```

### 燃烧

```text
Fixed-fire passive concept: icon, very small persistent fire-layer marker, brief once-per-second damage tick; the marker remains and is not consumed. No text, UI, characters, watermark, extra attachment orb, consumed layers, smoke plume, ground fire, or oversized bloom.
```

首版错误加入敌人剪影，已废弃。修订只移除剪影并保留火层/Tick 结构。

### 不息

```text
Fixed-water passive concept: icon, small persistent rounded-droplet water marker, brief life-recovery keyframe with one rising droplet and concentric ripple; marker remains and is not consumed. No text, UI, characters, watermark, medical cross, heart, consumed layer, CurrentElement implication, flames, large wave, or oversized bloom.
```

## 进入第二阶段前的确认项

1. 用户确认采用“清晰像素辉光”方向，或指出需要更硬像素、更柔和/可爱、或更强冲击的调整。
2. 任务 15 提供并通过 Review：元素之怒基础半径、Beam 长宽、回收半径、生成点、结束时序。
3. TestRoom 可运行后补齐 100%/缩放窗口、深色背景、角色前后层级截图。
4. 确认外部 Free VFX 包的项目用途与授权版本；详见 `docs/vfx/free_asset_screening.md`。
