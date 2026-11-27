#!/bin/sh
# build-package.sh — 把本技能打包成可安装压缩包（顶层目录 = 中文技能名）
#
# 用法:
#   sh scripts/build-package.sh                 # 输出到当前目录
#   sh scripts/build-package.sh /root/out.tar.gz # 指定输出文件
#
# 三条断言（任一不过即退出 1）:
#   1. 包内不能有 .git 条目（FUSE 的 .git 里有 .l2s.tmp_* 符号链接，会把包撑大一倍）
#   2. 包内 references/ 的文件数必须等于磁盘上的文件数（漏包只在别人机器上暴露）
#   3. 包内顶层目录必须是中文技能名（Operit 靠目录名认技能）
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ -f "$SKILL_DIR/SKILL.md" ] || { printf 'FAIL: %s 下没有 SKILL.md\n' "$SKILL_DIR"; exit 1; }
command -v tar >/dev/null 2>&1 || { printf 'FAIL: 没有 tar\n'; exit 1; }

# 技能名只从 SKILL.md 的 frontmatter 读，不能从目录名推：
# 仓库名是英文（operit-skill-ui-audit），拿它当包内顶层目录，装到 Operit 里就认不出技能。
NAME=$(awk -F':[[:space:]]*' '/^name:/{print $2; exit}' "$SKILL_DIR/SKILL.md" | tr -d '\r')
if [ -z "$NAME" ]; then
  printf 'FAIL: %s/SKILL.md 里没有 name: 字段\n' "$SKILL_DIR"
  exit 1
fi

OUT=${1:-"$PWD/$NAME-$(date +%Y%m%d).tar.gz"}
OUT_DIR=$(CDPATH= cd -- "$(dirname -- "$OUT")" 2>/dev/null && pwd) || {
  printf 'FAIL: 输出目录不存在: %s\n' "$(dirname -- "$OUT")"
  exit 1
}
OUT_ABS="$OUT_DIR/$(basename -- "$OUT")"
case "$OUT_ABS" in
  "$SKILL_DIR"/*)
    printf 'FAIL: 输出文件不能落在技能目录内（%s），否则会把自己打进包里\n' "$OUT_ABS"
    exit 1
    ;;
esac

REFS_DISK=$(find "$SKILL_DIR/references" -type f 2>/dev/null | wc -l | tr -d ' ')

# 目录名不保证等于技能名（克隆下来是英文仓库名），所以先按技能名摊到临时目录再归档：
# 直接 `tar -C <父目录> <目录名>` 出来的顶层是目录名，改名成技能名就会 Cannot stat。
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
mkdir -p "$STAGE/$NAME"
tar -cf - -C "$SKILL_DIR" --exclude='./.git' --exclude='.git' . | tar -xf - -C "$STAGE/$NAME"
tar -czf "$OUT" -C "$STAGE" "$NAME"

GIT_ENTRIES=$(tar -tzf "$OUT" | grep -c '\.git/' || true)
if [ "$GIT_ENTRIES" -ne 0 ]; then
  printf 'FAIL: 包内有 %s 个 .git 条目，--exclude 没生效\n' "$GIT_ENTRIES"
  exit 1
fi

REFS_PKG=$(tar -tzf "$OUT" | grep 'references/' | grep -vc '/$' || true)
if [ "$REFS_PKG" -ne "$REFS_DISK" ]; then
  printf 'MISSING: references 磁盘 %s 个 / 包内 %s 个，有文件没进包\n' "$REFS_DISK" "$REFS_PKG"
  exit 1
fi

TOP=$(tar -tzf "$OUT" | sed -n '1p' | cut -d/ -f1)
if [ "$TOP" != "$NAME" ]; then
  printf 'FAIL: 包内顶层目录是 %s，应为 %s\n' "$TOP" "$NAME"
  exit 1
fi

printf 'OK\nOUT=%s\nSIZE=%s\nTOP=%s\nFILES=%s\nREFS=%s\n' \
  "$OUT" "$(wc -c <"$OUT" | tr -d ' ')" "$NAME" \
  "$(tar -tzf "$OUT" | grep -vc '/$' || true)" "$REFS_PKG"