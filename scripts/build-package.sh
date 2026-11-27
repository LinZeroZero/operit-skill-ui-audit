#!/bin/sh
# build-package.sh — 把本技能打包成可安装压缩包（包内顶层目录 = SKILL.md 的 name:）
#
# 用法:
#   sh scripts/build-package.sh                     # 默认输出到技能目录的上一级
#   sh scripts/build-package.sh /root/out.tar.gz    # 指定输出文件
#
# 三道断言（任一不过即退出码 1，且目标路径上不留半成品）:
#   1. 包内没有 .git 条目（.git 目录与 worktree 指针文件都算）
#   2. 包内顶层目录等于技能名
#   3. 包内文件集合 == 磁盘清单（逐路径 diff，不是只比个数）
# 产物先写 <out>.tmp，三道全过才 rename 到 <out>；失败或中断都会清掉临时产物。
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LISTS=""
TMP_OUT=""

cleanup() {
  [ -n "$LISTS" ] && rm -rf "$LISTS"
  [ -n "$TMP_OUT" ] && rm -f "$TMP_OUT"
  return 0
}
trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT HUP TERM

[ -f "$SKILL_DIR/SKILL.md" ] || { printf 'FAIL: %s 下没有 SKILL.md\n' "$SKILL_DIR"; exit 1; }
command -v tar >/dev/null 2>&1 || { printf 'FAIL: 没有 tar\n'; exit 1; }
tar --version 2>/dev/null | grep -q 'GNU tar' || {
  printf 'FAIL: 需要 GNU tar（依赖 --exclude / --transform）\n'
  exit 1
}

# 技能名只从 frontmatter 读：仓库目录名是英文（operit-skill-ui-audit），
# 拿它当包内顶层目录，装到 Operit 里就认不出技能。
NAME=$(awk -F':[[:space:]]*' '/^name:/{print $2; exit}' "$SKILL_DIR/SKILL.md" | tr -d '\r')
[ -n "$NAME" ] || { printf 'FAIL: %s/SKILL.md 里没有 name: 字段\n' "$SKILL_DIR"; exit 1; }

DIR_NAME=$(basename -- "$SKILL_DIR")
PARENT=$(CDPATH= cd -- "$SKILL_DIR/.." && pwd)
OUT=${1:-"$PARENT/$NAME-$(date +%Y%m%d).tar.gz"}
OUT_DIR=$(CDPATH= cd -- "$(dirname -- "$OUT")" 2>/dev/null && pwd) || {
  printf 'FAIL: 输出目录不存在: %s\n' "$(dirname -- "$OUT")"
  exit 1
}
OUT_ABS="$OUT_DIR/$(basename -- "$OUT")"

# 输出落在技能目录内会把自己打进包；落在技能目录本身则根本不是文件路径。
case "$OUT_ABS" in
  "$SKILL_DIR" | "$SKILL_DIR"/*)
    printf 'FAIL: 输出路径不能是技能目录本身或其内部（%s）\n' "$OUT_ABS"
    exit 1
    ;;
esac

# 故意不打包的路径：版本控制目录与 FUSE 残留。归档侧（tar --exclude）与磁盘侧（grep）
# 各写一遍同一套规则 —— 两遍写法若漂移，下面的集合 diff 会直接点出来。
IGNORE_ERE='(^|/)(\.git|\.l2s\.tmp_[^/]*)(/|$)'

LISTS=$(mktemp -d)
(
  cd "$SKILL_DIR"
  find . \( -type f -o -type l \) -print | sed 's|^\./||' | grep -Ev "$IGNORE_ERE" | sort
) >"$LISTS/disk.list"
[ -s "$LISTS/disk.list" ] || { printf 'FAIL: %s 下没有可打包的文件\n' "$SKILL_DIR"; exit 1; }

TMP_OUT="$OUT_ABS.tmp"
tar -czf "$TMP_OUT" \
  --exclude="$DIR_NAME/.git" --exclude="$DIR_NAME/.git/*" \
  --exclude="$DIR_NAME/.l2s.tmp_*" --exclude="*/.l2s.tmp_*" \
  --exclude="*/.git" --exclude="*/.git/*" \
  --transform="s|^$DIR_NAME|$NAME|" \
  -C "$PARENT" "$DIR_NAME"

# 断言 1：包内不能有 .git（目录与 worktree 指针文件都算）
if tar -tzf "$TMP_OUT" | grep -Eq '(^|/)\.git(/|$)'; then
  printf 'FAIL: 包内有 .git 条目，--exclude 没生效\n'
  exit 1
fi

# 断言 2：顶层目录必须是技能名
TOP=$(tar -tzf "$TMP_OUT" | sed -n '1p' | cut -d/ -f1)
if [ "$TOP" != "$NAME" ]; then
  printf 'FAIL: 包内顶层目录是 %s，应为 %s\n' "$TOP" "$NAME"
  exit 1
fi

# 断言 3：包内文件集合必须逐路径等于磁盘清单。
# 只比个数会互相抵消：少一个真文件、多一个残留，计数照样对得上。
# 先剔除目录条目（结尾 /）再剥顶层名前缀，否则顶层目录会变成一行空串混进列表。
tar -tzf "$TMP_OUT" | grep -v '/$' | sed "s|^$NAME/||" | grep -v '^$' | grep -Ev "$IGNORE_ERE" | sort >"$LISTS/pkg.list"
if ! diff -u "$LISTS/disk.list" "$LISTS/pkg.list" >"$LISTS/pkg.diff"; then
  printf 'FAIL: 包内文件集合与磁盘清单不一致（- 磁盘 / + 包内）:\n'
  sed -n '1,40p' "$LISTS/pkg.diff"
  exit 1
fi

FILES=$(grep -c . "$LISTS/pkg.list" || true)
REFS=$(grep -c '^references/' "$LISTS/pkg.list" || true)
SIZE=$(wc -c <"$TMP_OUT" | tr -d ' ')
SHA=$(sha256sum "$TMP_OUT" | cut -d' ' -f1)

mv -f "$TMP_OUT" "$OUT_ABS"
TMP_OUT=""

printf 'OK\nOUT=%s\nSIZE=%s\nSHA256=%s\nTOP=%s\nFILES=%s\nREFS=%s\n' \
  "$OUT_ABS" "$SIZE" "$SHA" "$NAME" "$FILES" "$REFS"