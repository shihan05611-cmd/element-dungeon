# Tide-Ember Sovereign Source Provenance

记录日期：2026-08-18

- 素材包：`Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A`
- 本机存放目录（只读，未修改）：`C:\Users\heliashi\Desktop\游戏资产\Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A`
- 采用子集：`Characters(100x100 split)\Blood Monster_A\Blood Monster_A\`（不含投影版本，见任务书 §4 选用建议）
- 渠道：itch，用户声明已购买并取得下载许可。
- 用户口头确认的许可条款摘要（未在素材目录内找到 README/LICENSE/URL 文件，故按用户在本次对话中的明确确认记录，供后续可追溯核实）：
  - 允许修改/重绘衍生：**是**。
  - 允许商用：**否，仅限非商用**（与 [[bdragon1727 provenance]] 现有约定一致）。
  - 允许再分发（把素材或其衍生作为独立资源包对外发布）：**否**。
  - 授权确认：用户在本任务执行前的对话中明确确认以上三项条款，并确认购买行为已完成。
- 与本任务的一致性核对：Task60 用户核心决定要求「基于外部素材包做像素级重绘，不是色相替换」——与「允许修改/重绘衍生」条款一致，未违反非商用/不可再分发限制（本仓库不对外发布、不商用）。**未触发 BLOCKED 条件。**

## 派生规则

- 本任务对 `Blood Monster_A_Idle.png` / `_Walk.png` / `_Attack01.png` / `_Hurt.png` / `_Death.png` 五个精灵表分别取一个代表帧（idle f0、walk f2、attack01 f4、hurt f0、death f2），从源 100×100 帧坐标系的固定窗口 `(38,30)-(74,60)` 裁切，按整数 `4×` 最近邻放大后贴入 `200×200` 目标画布的固定偏移 `(28,50)`，从而保证普通/熔炽/潮涌三形态与 hurt/death 共用画布、锚点与基线。
- 熔炽（火）与潮涌（水）形态在该放大结果上做像素级重绘：调色板替换（暗面/主面/高光三档）、描边分域换色，并各自新增结构像素（火形态：裂纹亮色像素簇；水形态：轮廓半透明柔化环 + 悬垂水滴像素），非单纯色相滤镜。
- 普通形态使用与源图最接近的中性配色（仅将纯黑描边替换为规范要求的深色描边，不做其他重绘）。
- 不改变、不覆盖、不删除源目录任何文件；本文件仅记录派生方法，供 Review 复核。

## 原始文件 SHA-256 清单

| 文件 | 字节 | SHA-256 |
|---|---:|---|
| `Blood Monster_A_Idle.png` | 1104 | `845D2AF726CAADA87DDF0F9B6F44F8E76798591E6DE6D6D931EE1B510FA49181` |
| `Blood Monster_A_Walk.png` | 1455 | `872780CA50651FB26C97C8B3A2C8D31ABE1CD66192229D56AA9D28D4FF793DDC` |
| `Blood Monster_A_Attack01.png` | 1940 | `339423743A56009DCAAEAEB19683838B590794054BDD9C990199A7AA98332A2B` |
| `Blood Monster_A_Attack02.png` | 1949 | `623D1E94E071CCA1850E517FFFDE213BB3DA3E83A5D55E3BDA1626A3046E2CAA` |
| `Blood Monster_A_Hurt.png` | 1501 | `BFA7E3CC20AC898708BDEE62AA8FEB2FEF62E42E1ABC2DD9E4E907EB08F508ED` |
| `Blood Monster_A_Death.png` | 1228 | `F6FEFB3B31C22AEF6A9E11AD23B0857B38B180AB3336650E2C141E85ECC0CC6E` |
| `Blood Monster_A.png`（合图，未使用，仅存档记录） | 8914 | `5BA23F4BD08B296EE55D1CF9812C9BEBCB8A906BB85ECDF4B02EFC792339C690` |

验收要求：Review 复算上述 SHA-256 与源目录当前文件一致，证明只读、未修改源素材。`Blood Monster_A_Attack02.png` 与合图 `Blood Monster_A.png` 未被实际采样使用，仅作为素材包完整性记录列出。
