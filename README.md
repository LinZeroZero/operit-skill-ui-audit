# UI审查（Operit AI 技能）

审查界面（网页 / WebUI / 截图）的视觉问题：按 **层级 → 间距 → 排版 → 色彩 → 深度 → 图像 → 收尾** 七步扫查，
每条 finding 必须挂 `§规则号`、严重度与实测数值。**只诊断，不改代码。**

一句话判别标准：**说不出规则号的就不算 finding，只是品味。**

## 安装

把本仓库内容放到 Operit 的技能目录下，目录名用中文 `UI审查`：

```sh
git clone https://github.com/<owner>/operit-skill-ui-audit.git \
  /sdcard/Download/Operit/skills/UI审查
```

或用 tar 包（顶层目录即技能名）：

```sh
tar -czf ui-audit.tar.gz --exclude='.git' -C /sdcard/Download/Operit/skills UI审查
```

装好后 Operit 侧看到的是 `skills/UI审查/SKILL.md`。

## 关键约定

- **先量再判**：不许目测对比度、不许猜字号。取数逻辑统一放在 `scripts/audit.js`，
  三种环境（`browser` 包 / CSS 静态解析 / 用户控制台）共享同一份实现，结果标注取数方式（渲染 / 静态 / 控制台）。
- **判不了就进存疑列**：渐变、图片背景、继承与 CSS 变量、被遮挡文字、描边提升可读性等，
  一律进 `incomplete[]`，不猜一个数字顶上。
- **顺序不许打乱**：层级没理顺，什么算「间距问题」就会跟着变；收尾（第 7 步）必须等前 6 步处理完。
- **已有设计系统永远优先**：项目里有颜色阶、间距阶、字号阶，就用项目的词，别另立一套。
- **严重度**：P0 影响可用性（对比度不达 4.5:1、只靠颜色传意、布局崩了…）、P1 影响一致性、P2 打磨。
  P0 一律越界上报。

## 目录

```
SKILL.md                         技能说明（方法层，中文）
references/00-coverage-matrix.md 151 条规则的索引与状态
references/02..08-*.md           层级 / 间距 / 排版 / 色彩 / 深度 / 图像 / 收尾
references/13-audit-rubric.md    finding 字段、严重度、逐 lens 检查表 —— 扫查前先读
references/14-antipatterns.md    症状 → 规则 反查表
references/15-beyond-the-book.md 书外扩展（暗色、焦点态、动效、z-index、语义 token）
references/upstream-links.md     未镜像的生成类文档（按需外链）
references/android/ksu-webui.md  KernelSU 类 WebUI 专项清单
scripts/audit.js                 取数函数（对比度 / 字号 / 间距 / 行长 / tap target）
ATTRIBUTION.md                   原书版权归属与免责声明
SOURCE.txt                       上游镜像来源与更新方法
```

## 来源与许可

- 自写部分（`SKILL.md`、`references/android/`、`scripts/audit.js`）：MIT，见 `LICENSE`。
- `references/02..15-*.md` 镜像自 **[edisonmbli/refactoring-ui-skill](https://github.com/edisonmbli/refactoring-ui-skill)**
  （MIT，提交 `4459662`），保留英文原文以便溯源与 diff。
- 规则本身出自 **《Refactoring UI》**（Adam Wathan & Steve Schoger）。本项目与作者、Tailwind Labs 无关，
  也不替代原书 —— 想真正学会「看」，请买书：<https://www.refactoringui.com>。

## 边界（明确不做）

不改代码、不生成界面、不装 Tailwind、不迁移样式方案、不评价文案内容；
缩放 / 键盘可达 / 读屏语义 / 视觉回归不在范围内。
