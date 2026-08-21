# Agent 任务目录

现行中枢规则见 `CENTRAL_REVIEW_RULES.md`，Review 规则见 `REVIEW_AGENT_RULES.md`。

- `pending/`：尚未结束的任务。
- `completed/`：Review 已 `PASS` 的任务。
- `evidence/`：仅在任务确实需要长期保存证据时使用，不是默认要求。

新任务书只需：

```markdown
# <任务名>

目标：<期望结果>
范围：<允许改什么>
完成：<怎样算完成>
```

必要时补一两条关键依赖或禁止项即可，不要求其他固定格式。执行者完成并验证后交给 Review；Review `PASS` 即最终接受，可直接标为 `DONE` 并归档。中枢不做二次验收或最终 accept。

历史任务文档保留原样供追溯，不代表新任务仍须沿用其格式、等级或证据规模。
