#!/bin/bash
#
# ~/.claude 의 개인 설정을 이 저장소로 심볼릭 링크한다.
#
#   ./claude/install.sh          링크 생성 후 settings.json 에 선언된 플러그인을 복원한다.
#                                ~/.claude 쪽에 실물이 있으면 저장소로 옮긴 뒤 링크한다.
#   ./claude/install.sh --check  상태만 점검하고 아무것도 바꾸지 않는다.
#
# 몇 번을 실행해도 결과가 같으며, 내용이 다른 파일을 조용히 덮어쓰는 경로는 없다.
# settings.local.json 은 기기별 권한 목록이라 의도적으로 제외한다.

set -uo pipefail

REPO_CLAUDE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_CLAUDE="$HOME/.claude"

TARGETS=(CLAUDE.md settings.json commands skills agents hooks)

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

mkdir -p "$HOME_CLAUDE"

failed=0

# claude CLI 출력에서 색상 코드를 걷어내고 마지막 줄만 남긴다.
last_line() {
  printf '%s\n' "$1" | sed $'s/\033\\[[0-9;]*m//g' | grep -v '^[[:space:]]*$' | tail -1
}

# settings.json 에 선언된 마켓플레이스와 플러그인을 복원한다.
#
# settings.json 은 "무엇을 켤지"만 담는다. 마켓플레이스 clone 과 플러그인 코드는
# ~/.claude/plugins 캐시에 있고 이 저장소에 담기지 않으므로, 새 기기에서는
# marketplace add -> plugin install 을 다시 해줘야 한다.
# 이미 설치된 항목은 건너뛰므로 평소 실행에서는 네트워크를 타지 않는다.
restore_plugins() {
  local settings="$REPO_CLAUDE/settings.json"
  [ -f "$settings" ] || return 0

  for cmd in claude python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[skip]     플러그인 복원 ($cmd 명령을 찾을 수 없다)"
      return 0
    fi
  done

  local actions
  if ! actions="$(python3 - "$settings" <<'PY'
import json, os, sys

home = os.path.join(os.path.expanduser("~"), ".claude")

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

settings = load(sys.argv[1])
known = load(os.path.join(home, "plugins", "known_marketplaces.json"))
installed = load(os.path.join(home, "plugins", "installed_plugins.json")).get("plugins", {})

# 공식 마켓플레이스는 기본 제공이다. 직접 add 하면 extraKnownMarketplaces 에
# 불필요한 항목이 생기고 링크를 타고 저장소까지 역류한다.
for name, entry in settings.get("extraKnownMarketplaces", {}).items():
    if name in known or name == "claude-plugins-official":
        continue
    src = entry.get("source", {})
    spec = src.get("repo") if src.get("source") == "github" else src.get("url")
    print("%s\t%s\t%s" % ("marketplace" if spec else "unsupported", name, spec or src.get("source")))

declared = settings.get("extraKnownMarketplaces", {})
for plugin, enabled in settings.get("enabledPlugins", {}).items():
    if not enabled or plugin in installed:
        continue
    # 이번 실행에서 등록할 마켓플레이스는 아직 known 에 없으므로 선언 쪽도 같이 본다.
    marketplace = plugin.rsplit("@", 1)[-1]
    if marketplace in known or marketplace in declared:
        print("plugin\t%s\t" % plugin)
    else:
        print("no-marketplace\t%s\t%s" % (plugin, marketplace))
PY
  )"; then
    echo "[error]    settings.json 파싱 실패"
    failed=1
    return 0
  fi

  if [ -z "$actions" ]; then
    echo "[ok]       플러그인 (복원할 항목 없음)"
    return 0
  fi

  local out
  # 마켓플레이스가 먼저 나오고 플러그인이 뒤따른다. 순서가 곧 실행 순서다.
  while IFS=$'\t' read -r kind name spec; do
    [ -z "$kind" ] && continue
    case "$kind" in
      unsupported)
        echo "[skip]     마켓플레이스 $name (지원하지 않는 source 형식: $spec)"
        ;;
      # 기본 제공 마켓플레이스(claude-plugins-official)는 로그인해야 등록된다.
      no-marketplace)
        echo "[skip]     플러그인 $name (마켓플레이스 $spec 미등록. claude 로그인 후 다시 실행할 것)"
        failed=1
        ;;
      marketplace)
        if [ "$CHECK_ONLY" = 1 ]; then
          echo "[missing]  마켓플레이스 $name"
          failed=1
        elif out="$(claude plugin marketplace add "$spec" 2>&1)"; then
          echo "[added]    마켓플레이스 $name"
        else
          echo "[error]    마켓플레이스 $name 등록 실패: $(last_line "$out")"
          failed=1
        fi
        ;;
      plugin)
        if [ "$CHECK_ONLY" = 1 ]; then
          echo "[missing]  플러그인 $name"
          failed=1
        elif out="$(claude plugin install "$name" 2>&1)"; then
          echo "[added]    플러그인 $name"
        else
          echo "[error]    플러그인 $name 설치 실패: $(last_line "$out")"
          failed=1
        fi
        ;;
    esac
  done <<< "$actions"
}

# 저장소 쪽과 홈 쪽 내용이 같은지 비교한다.
same() {
  if [ -d "$1" ]; then
    diff -r "$1" "$2" >/dev/null 2>&1
  else
    cmp -s "$1" "$2"
  fi
}

for name in "${TARGETS[@]}"; do
  src="$REPO_CLAUDE/$name"
  dst="$HOME_CLAUDE/$name"

  # 이미 링크인 경우
  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      echo "[ok]       $name"
    else
      echo "[conflict] $name -> $current (이 저장소가 아닌 곳을 가리킨다)"
      failed=1
    fi
    continue
  fi

  # 홈 쪽에 실물이 있는 경우
  if [ -e "$dst" ]; then
    if [ ! -e "$src" ]; then
      if [ "$CHECK_ONLY" = 1 ]; then
        echo "[unlinked] $name (실물이 ~/.claude 에 있다. 저장소로 옮겨야 한다)"
        failed=1
        continue
      fi
      if mv "$dst" "$src" && ln -s "$src" "$dst"; then
        echo "[adopted]  $name (~/.claude -> 저장소로 이동 후 링크)"
      else
        echo "[error]    $name 이동에 실패했다"
        failed=1
      fi
      continue
    fi

    if same "$src" "$dst"; then
      if [ "$CHECK_ONLY" = 1 ]; then
        echo "[unlinked] $name (내용은 같다. 링크로 교체 가능)"
        failed=1
        continue
      fi
      rm -rf "$dst" && ln -s "$src" "$dst" && echo "[linked]   $name"
      continue
    fi

    # 내용이 다르면 판단을 사람에게 넘긴다.
    # Claude Code 가 링크를 실물 파일로 교체했을 때도 여기로 걸린다.
    echo "[conflict] $name 내용이 다르다. 직접 확인하고 정리할 것:"
    echo "             저장소: $src"
    echo "             홈    : $dst"
    failed=1
    continue
  fi

  # 홈 쪽에 아무것도 없는 경우
  if [ ! -e "$src" ]; then
    echo "[skip]     $name (저장소에도 홈에도 없다)"
    continue
  fi
  if [ "$CHECK_ONLY" = 1 ]; then
    echo "[unlinked] $name"
    failed=1
    continue
  fi
  ln -s "$src" "$dst" && echo "[linked]   $name"
done

restore_plugins

exit $failed
