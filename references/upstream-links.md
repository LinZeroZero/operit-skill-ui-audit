# 未镜像的上游档（按需取用）

本技能只做**审查**，因此没有落地上游的「生成向」文件。它们仍可用，但需要联网：

| 上游文件 | 干什么用 | 什么时候才需要 |
|---|---|---|
| `01-starting-from-scratch.md` | 从零设计一个新页面的顺序 | 用户问「帮我设计一个界面」——超出本技能范围 |
| `10-tailwind-mapping.md` | 规则 → Tailwind 类的映射表 | **确认项目确实用 Tailwind** 时，用来说明改法的具体类名 |
| `11-design-tokens.md` | 色板算法、字号/间距阶的生成流程 | 用户要「建一套设计规范」时 |
| `12-component-recipes.md` | 按钮/表单/卡片等组件的标准做法 | 用户要给具体组件定样式时 |
| `16-component-libraries.md` | shadcn/MUI/Ant 的 token 契约 | 项目用了这些库，且要改动组件 |

取用方式（锁定同一提交，避免与本文档版本错位）：

```
https://raw.githubusercontent.com/edisonmbli/refactoring-ui-skill/4459662c4fbf36d54342b1546d8851273031442c/skills/refactoring-ui/references/<文件名>
```

例：

```
https://raw.githubusercontent.com/edisonmbli/refactoring-ui-skill/4459662c4fbf36d54342b1546d8851273031442c/skills/refactoring-ui/references/11-design-tokens.md
```

用法边界（很重要）：

- 取来之后 **仍然只用于审查**：可以引用它的规则号解释「为什么这里不对」，但不要照它去生成一套 token 塞进用户项目。
- 若用户明确要「顺便把这套规范落地」，那是另一个任务，需要用户确认后再做——本技能默认不越界。

## 其他上游资源

- 仓库根 `ATTRIBUTION.md`：原书版权归属与非官方声明（已镜像到本技能根目录）。
- 仓库根 `LICENSE`：MIT 全文，**未镜像**；如需分发请注意保留原仓库的许可声明，本技能已在 `ATTRIBUTION.md` 与本文件中标注来源。
- `scripts/generate_palette.py`、`scripts/check_contrast.py`、`eval/`、`templates/`：与审查定位无关，未镜像。
  `05-color.md` 里会出现这两个脚本名（上游原文），本地没有对应文件，不必去找。

## 外部规范对照（未镜像，只引用条款，不搬正文）

| 规范 | 地址 | 用它对照什么 | 注意 |
|---|---|---|---|
| GitLab 代码评审规范 | https://docs.gitlab.com/development/code_review/ | 「审之前先理解为什么改」；审批矩阵（谁有权批哪类改动） | 审批权属 GitLab 内部角色，本技能不复制 |
| GitLab 设计与 UI 规范 | https://docs.gitlab.com/development/design_and_ui/ | States 清单（error / rest / loading / focus / hover / selected / disabled，另按数据量与角色分）；Responsive 断点清单；无障碍声明为 WCAG 2.1 AA；MR 须附 before/after 截图 | 同上；截图属流程门禁，本技能不强制 |

取用日期 2026-11-23。链接可能改版，以页面实际内容为准；发现对不上就按本技能规则，不按对方页面。

用法边界：

- 只用于「我们的规则缺了哪一项」的对照，**不把 GitLab 的条款当成我们的规则号**。
- 提到无障碍时必须写清版本：GitLab 声明 **WCAG 2.1 AA**；本技能 `05-color.md` 与 `15-beyond-the-book.md` 引的是 **WCAG 2.2** 的数值项（4.5:1 / 24×24）。两个版本，不要混写成同一个。
- 不引入「Product Designer 批准」这类审批权——本技能只有诊断权，没有合并权。
  其中 `check_contrast.py` 的能力已由本技能 `scripts/audit.js` 的 `auditContrast(fg, bg)` 覆盖（同一套 WCAG 相对亮度公式，已用 `#9aa0c0` / `#0f1220` = 7.24 验证），可直接替代。