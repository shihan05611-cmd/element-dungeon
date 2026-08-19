# 全库引用扫描 / .import / Git 写操作 / 源素材完整性核对

## 1. 全库引用扫描（对本任务新增资产文件名）

命令：
```
grep -rlE "boss_plain_|boss_ember_|boss_tide_|boss_hurt_v1|boss_death_v1|sentry_tide_bolt|bolt_impact_v1|telegraph_alert_|tide_ember_sovereign" \
  --include="*.tscn" --include="*.tres" --include="*.gd" --include="project.godot" .
```
结果：无匹配（grep 退出码 1 = 未找到）。**全库引用数 = 0**，符合“本任务只交付美术资产、不做工程接线”的约束。

## 2. `.import` 产出核查

命令：
```
find assets/world/enemies/tide_ember_sovereign assets/world/projectiles assets/world/ui_world/telegraph -iname "*.import"
```
结果：`0`。本任务未触发 Godot 导入、未生成任何 `.import` sidecar。

## 3. Git 写操作核查

本次会话未执行 `git add / commit / push / reset / restore / checkout / clean / stash` 中的任何一条。**Git 写操作 = 0。**

`git status` 显示的既有改动（约 410 行 porcelain 输出）在会话开始前已存在于工作区（见对话开头 `gitStatus` 快照，含 task58 遗留的 `docs/agent_tasks/*`、`assets/art_preview/*` 与已删除的 `.import` sidecar），均非本任务产生，本任务未修改、未暂存、未提交这些既有改动。

## 4. 源素材完整性（SHA-256 未变）

任务执行结束时重新计算 `Blood Monster_A_*.png` 全部 7 个文件的 SHA-256，与 `LICENSE_PROVENANCE.md` 记录的初始清单逐条比对，**全部一致**，证明源素材目录全程只读、未被修改。

## 5. 输出范围核对（allowlist）

本任务实际写入的文件均位于任务书 §6 allowlist 声明的三个目录（`assets/world/enemies/tide_ember_sovereign/`、`assets/world/projectiles/`、`assets/world/ui_world/telegraph/`）及 `docs/agent_tasks/evidence/task60/`、`docs/agent_tasks/pending/60_boss_projectile_and_telegraph_art.md` 本身，未触碰 allowlist 之外的任何路径；未修改宝箱、传送门、潮汐哨兵立绘、现有 96 个 VFX import、`assets/art_preview/**` 冻结母版，未恢复 `run_reward_chest/**` 或 `run_route_portal/**`，未接触 `global_instakill` 相关文件与 `tmp/**`。
