# 引燃命中前缘反推

## 实测输入

- 动画：`fire_attack`，20 fps。
- 技能 startup：0.08 s；命中启动时可见关键帧为 frame 1。
- 气流帧宽：80 px，中心 x=40。
- `cat_fire_attack_airflow.png` frame 1 最前方非透明像素：x=23；左右翻转均使用同一距中心绝对值。
- `BasicAttackAirflow` 普通 authored scale：2.0。
- 普通气流视觉前缘：`V0 = (40 - 23) × 2 = 34 px`。
- 普通近战查询前缘：`Q0 = spawn 30 + query_offset 42 + rectangle_half_width 36 = 108 px`。

## 反推

```text
P  = Q0 - V0
   = 108 - 34
   = 74 px

V1 = V0 × 1.5
   = 34 × 1.5
   = 51 px

Q1 = V1 + P
   = 51 + 74
   = 125 px

melee_query_multiplier
   = Q1 / Q0
   = 125 / 108
   = 1.157407407...
```

`scripts/player.gd` 在引燃普通攻击接受前构造本次固定定义时，把上述确定常量写入 payload；每次攻击不扫描贴图。普通普攻的 `Q0`、`V0` 与 `P` 不变。

`run_task81_ignition_tests.gd` 从真实火气流贴图重测 x=23，并从真实 `transient_melee_delivery.tscn` 与玩家 spawn snapshot 重建 Q0；随后验证左右朝向的 Q1 边界内可命中、边界外不可命中，且引燃在命中前结束也不改变已接受 payload 的倍率。
