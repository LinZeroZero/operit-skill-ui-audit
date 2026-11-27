#!/bin/sh
# build-package.sh — 把本技能打包成可安装压缩包（包内顶层目录 = SKILL.md 的 name:）
#
# 用法:
#   sh scripts/build-package.sh                     # 默认输出到技能目录的上一级
#   sh scripts/build-package.sh /root/out.tar.gz    # 指定输出文件（必须是文件名，不能是目录）
#
# 依赖 GNU tar（--exclude / --transform）。macOS 用 gtar，Android 的 toybox tar 不满足，
# 请在 proot 容器内跑。
#
# 四道断言（任一不过即退出码 1，目标路径上不留半成品）:
#   1. 包内没有 .git 条目（.git 目录与 worktree 指针文件都算）
#   2. 包内顶层目录等于技能名
#   3. 包内没有 .git / .l2s.tmp_* 这类应被排除的条目（独立于归档侧的排除写法）
#   4. 包内文件集合逐路径等于磁盘清单（不是只比个数）
# 产物先写唯一临时名 <输出目录>/.pkg-XXXXXX，四道全过才 rename 到目标文件。
set -eu

SKILL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LISTS=""
TMP_OUT=""

die() { printf 'FAIL: %s\n' "$*"; exit 1; }

cleanup() {
  [ -n "$LISTS" ] && rm -rf "$LISTS"
  # 只删自己 mktemp 出来的那个文件：并发跑同一 OUT 时不会误删另一进程的成品
  [ -n "$TMP_OUT" ] && rm -f "$TMP_OUT"
  return 0
}
# 信号与 EXIT 各挂一条；signal trap 里 exit 之后 EXIT trap 还会再跑一次 cleanup（幂等）
trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 143' TERM

[ -f "$SKILL_DIR/SKILL.md" ] || die "$SKILL_DIR 下没有 SKILL.md"
command -v tar >/dev/null 2>&1 || die "没有 tar"
tar --version 2>/dev/null | grep -q 'GNU tar' || die "需要 GNU tar（依赖 --exclude / --transform）"

# 技能名只从 frontmatter 读：仓库目录名是英文（operit-skill-ui-audit），
# 拿它当包内顶层目录，装到 Operit 里就认不出技能。
NAME=$(awk -F':[[:space:]]*' '/^name:/{print $2; exit}' "$SKILL_DIR/SKILL.md" | tr -d '\r')
NAME=$(printf '%s' "$NAME" | sed 's/[[:space:]]*$//')
[ -n "$NAME" ] || die "$SKILL_DIR/SKILL.md 里没有 name: 字段"

# 这个值会变成别人的目录名，还要进 tar --transform 与 sed 的表达式。
# 尾随空格会让「name: UI审查 」静默出一个带空格、Operit 认不出的顶层目录，而三条断言
# 因为两侧都用同一个 NAME 而全部照过 —— 所以在这里就挡掉，而不是等装到机器上才发现。
case "$NAME" in
  .*) die "name 不能以 . 开头: $NAME" ;;
esac
if printf '%s' "$NAME" | grep -Eq '[/\\|&$`"<>]'; then
  die "name 含不能用于路径或 sed/tar 表达式的字符: $NAME"
fi
# 只转义 BRE 真正的元字符：[ ] . * ^ $\
# 别把 + ? ( ) { } 也转义 —— 在 BRE 里 \+ \? 是 GNU 重复算子、\( \{ 是分组/区间算子，
# 转义它们等于把「字面量」变成「操作符」：a+b 匹配不上、a(b 直接 sed: Unmatched (。
NAME_RE=$(printf '%s' "$NAME" | sed 's/[][\\.*^$]/\\&/g')

DIR_NAME=$(basename -- "$SKILL_DIR")
# 同一条 BRE 安全规则：目录名可能带 . + ( { 等合法字符
DIR_RE=$(printf '%s' "$DIR_NAME" | sed 's/[][\\.*^$]/\\&/g')
PARENT=$(CDPATH= cd -- "$SKILL_DIR/.." && pwd)

OUT=${1:-"$PARENT/$NAME-$(date +%Y%m%d).tar.gz"}
OUT_DIR=$(CDPATH= cd -- "$(dirname -- "$OUT")" 2>/dev/null && pwd) || die "输出目录不存在: $(dirname -- "$OUT")"
OUT_ABS="$OUT_DIR/$(basename -- "$OUT")"

# 传一个已存在的目录进来时，mv 会把文件搬进该目录并保留临时名，退出码却是 0 —— 先挡住。
if [ -d "$OUT_ABS" ]; then
  die "输出路径是已存在的目录: $OUT_ABS（请给出文件名）"
fi
# 输出落在技能目录内会把自己打进包；落在技能目录本身则根本不是文件路径。
case "$OUT_ABS" in
  "$SKILL_DIR" | "$SKILL_DIR"/*)
    die "输出路径不能是技能目录本身或其内部: $OUT_ABS"
    ;;
esac

# 故意不打包的路径：版本控制目录与 FUSE 残留。归档侧（tar --exclude）与磁盘侧（grep）
# 各写一遍；断言 3/4 让这份「两遍写法」的漂移无处可藏，而不是靠它自己保持一致。
IGNORE_ERE='(^|/)(\.git|\.l2s\.tmp_[^/]*)(/|$)'

LISTS=$(mktemp -d)
(
  cd "$SKILL_DIR"
  find . \( -type f -o -type l \) -print | sed 's|^\./||' | grep -Ev "$IGNORE_ERE" | sort
) >"$LISTS/disk.list"
[ -s "$LISTS/disk.list" ] || die "$SKILL_DIR 下没有可打包的文件"

TMP_OUT=$(mktemp "$OUT_DIR/.pkg-XXXXXX") || die "无法在 $OUT_DIR 创建临时文件"
tar -czf "$TMP_OUT" \
  --exclude="$DIR_NAME/.git" --exclude="$DIR_NAME/.git/*" \
  --exclude="$DIR_NAME/.l2s.tmp_*" --exclude="*/.l2s.tmp_*" \
  --exclude="*/.git" --exclude="*/.git/*" \
  --transform="s|^$DIR_RE|$NAME|" \
  -C "$PARENT" "$DIR_NAME"

tar -tzf "$TMP_OUT" >"$LISTS/pkg.raw"

# 断言 1：包内不能有 .git（目录与 worktree 指针文件都算）
if grep -Eq '(^|/)\.git(/|$)' "$LISTS/pkg.raw"; then
  printf 'FAIL: 包内有 .git 条目，--exclude 没生效:\n'
  grep -E '(^|/)\.git(/|$)' "$LISTS/pkg.raw" | sed -n '1,20p'
  exit 1
fi

# 断言 2：顶层目录必须是技能名
TOP=$(sed -n '1p' "$LISTS/pkg.raw" | cut -d/ -f1)
if [ "$TOP" != "$NAME" ]; then
  die "包内顶层目录是 $TOP，应为 $NAME"
fi

# 断言 3：包内不许出现「应被排除的条目」。
# 这一条不复用 IGNORE_ERE 过滤后的结果 —— 归档侧要是漏写一条排除，残留会静默进包，
# 而断言 4 的两侧会同时把它过滤掉、diff 相等。所以直接在原始清单上查。
# 也不能先剔掉目录条目：空的 .l2s.tmp_dir/ 只剩目录条目，剔掉就两头都查不到。
if grep -Eq "$IGNORE_ERE" "$LISTS/pkg.raw"; then
  printf 'FAIL: 包内有应被排除的条目（归档侧 --exclude 与忽略规则不一致）:\n'
  grep -E "$IGNORE_ERE" "$LISTS/pkg.raw" | sed -n '1,20p'
  exit 1
fi

# 断言 4：包内文件集合必须逐路径等于磁盘清单。
# 只比个数会互相抵消：少一个真文件、多一个残留，计数照样对得上。
# 先剔除目录条目（结尾 /）再剥顶层名前缀，否则顶层目录会变成一行空串混进列表。
grep -v '/$' "$LISTS/pkg.raw" | sed "s|^$NAME_RE/||" | grep -v '^$' | sort >"$LISTS/pkg.list"
if ! diff -u "$LISTS/disk.list" "$LISTS/pkg.list" >"$LISTS/pkg.diff"; then
  printf 'FAIL: 包内文件集合与磁盘清单不一致（- 磁盘 / + 包内）:\n'
  sed -n '1,40p' "$LISTS/pkg.diff"
  exit 1
fi

FILES=$(grep -c . "$LISTS/pkg.list" || true)
REFS=$(grep -c '^references/' "$LISTS/pkg.list" || true)

# mktemp 建的是 0600，tar 往已有文件里写不改权限，直接 mv 出去产物就成了 0600 ——
# 共享构建机上的另一个用户会读不到。按当前 umask 还原成常规文件权限。
MODE=$(printf '%o' $((0666 & ~0$(umask))))
chmod "$MODE" "$TMP_OUT"

mv -f "$TMP_OUT" "$OUT_ABS"
TMP_OUT=""

SIZE=$(wc -c <"$OUT_ABS" | tr -d ' ')
SHA=$(sha256sum "$OUT_ABS" | cut -d' ' -f1)
printf 'OK\nOUT=%s\nSIZE=%s\nSHA256=%s\nTOP=%s\nFILES=%s\nREFS=%s\n' \
  "$OUT_ABS" "$SIZE" "$SHA" "$NAME" "$FILES" "$REFS"