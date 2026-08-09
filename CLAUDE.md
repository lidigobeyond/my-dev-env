# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 저장소 성격

macOS 개발 환경을 새 머신에서 재현하기 위한 dotfiles / 부트스트랩 저장소다. 애플리케이션 코드가 아니므로 빌드·테스트·린트 명령이 없다. 변경 검증은 실제 실행(또는 스크립트 정독)으로만 가능하며, 대부분의 스크립트가 `sudo`·전역 설치·`~/.zshrc` 수정 등 되돌리기 어려운 부작용을 가지므로 사용자가 명시적으로 요청하지 않는 한 실행하지 말 것.

## 실행

```bash
# 전체 부트스트랩 (반드시 저장소 루트에서 — 스크립트가 ./Brewfile, ./node/install.sh 등 상대 경로를 사용)
./install.sh

# 패키지만 재설치/동기화
brew bundle --file=./Brewfile
```

## 구조와 실행 흐름

`install.sh`가 유일한 진입점이며 다음 순서로 동작한다:

1. Homebrew 설치 → `brew bundle`로 `Brewfile` 적용
2. `/Applications/*.app`에 대해 `xattr -dr com.apple.quarantine` 실행 (Gatekeeper 격리 해제)
3. `node/install.sh` — nvm 로딩 구문을 `~/.zshrc`에 추가하고 Node 14/16/20 설치, 전역 typescript 설치
4. git 전역 설정 (`init.defaultBranch=main`, `core.ignorecase=false`)
5. `zsh/install.sh` — `~/.zsh_aliases` 심볼릭 링크 생성 후 `~/.zshrc`에 source 구문 추가
6. `claude/install.sh` — `~/.claude` 개인 설정 심볼릭 링크 + 플러그인 복원

`claude/`는 Claude Code 전역 설정을 기기 간 동기화하기 위한 디렉터리다. `CLAUDE.md`, `settings.json`, `commands/`, `skills/`, `agents/`, `hooks/`, `statusline.sh`를 `~/.claude/` 아래로 링크하며, 링크된 파일을 편집하면 곧바로 저장소에 반영된다. `settings.local.json`은 기기별 권한 allowlist라 의도적으로 제외한다. `claude/install.sh`는 멱등하고, 내용이 다른 파일을 만나면 덮어쓰지 않고 중단한다. `./claude/install.sh --check`로 아무것도 바꾸지 않고 상태만 점검할 수 있다.

링크 후에는 `settings.json`의 `extraKnownMarketplaces`와 `enabledPlugins`를 읽어 마켓플레이스 등록과 플러그인 설치를 복원한다. 목록을 스크립트에 하드코딩하지 않으므로 플러그인을 추가/제거해도 스크립트는 손댈 필요가 없다. 이미 설치된 항목은 건너뛰므로 평소 실행에서는 네트워크를 타지 않는다.

플러그인 복원에서 주의할 점:

- **`settings.json`만으로는 부족하다.** 마켓플레이스 clone과 플러그인 코드는 `~/.claude/plugins/` 캐시에 있고 저장소에 담기지 않는다. 선언만 있고 캐시가 비면 `marketplace list`가 비어 있고 `install`도 `marketplace update`도 실패한다. 그래서 `marketplace add`부터 다시 해야 한다.
- **기본 제공 마켓플레이스 `claude-plugins-official`은 로그인해야 등록된다.** 새 기기에서는 `claude`로 로그인한 뒤 `./claude/install.sh`를 다시 실행해야 공식 플러그인이 설치된다. 미등록 상태면 해당 플러그인을 건너뛰고 이유를 출력한다.
- **`claude-plugins-official`을 직접 `marketplace add` 하지 말 것.** `extraKnownMarketplaces`에 불필요한 항목이 생기고 링크를 타고 저장소까지 역류한다. 스크립트도 이 이름은 등록 대상에서 제외한다.

`claude/statusline.sh`는 [kcchien/claude-code-statusline](https://github.com/kcchien/claude-code-statusline)에서 가져온 vendored 파일이다(MIT). 서브모듈이 아니라 복사본이며, 출처와 커밋 해시는 파일 상단 주석에 있다. **직접 수정하지 말 것** — 업데이트는 upstream의 raw `statusline.sh`로 덮어쓰고 주석 블록을 다시 얹은 뒤 해시를 갱신하는 방식이다. `settings.json`의 `statusLine.command`가 `~/.claude/statusline.sh`(링크)를 가리키므로 저장소 경로가 기기마다 달라도 깨지지 않는다. 실행에 `jq`가 필요해 Brewfile에 넣어 뒀고, 없으면 스크립트가 조용히 `─ │ jq not found`로 떨어진다.

`alfred/Alfred.alfredpreferences`는 Alfred 설정 번들을 통째로 커밋한 것이다. 개별 파일을 손대지 말고 Alfred가 쓴 결과를 그대로 커밋한다 (커밋 메시지 관례: `feat: sync alfred configuration`).

## 변경 시 주의점

- **Brewfile ↔ install.sh 연동**: cask를 추가/삭제하면 `install.sh`의 quarantine 해제 목록도 함께 갱신해야 한다. 둘은 자동 연결되지 않으며, 현재도 제거된 cask(webstorm, datagrip)의 quarantine 라인이 남아 있고 `/Applications/Chrome.app`처럼 실제 앱 이름(`Google Chrome.app`)과 어긋난 항목이 있다. **cask 이름이 아니라 `/Applications` 아래 실제 앱 이름**을 써야 한다.
- **mas 항목**은 App Store 앱 ID가 필요하다: `mas 'Name', id: 123456789`.
- **`~/.zshrc` 추가는 멱등하지 않다**: `node/install.sh`와 `zsh/install.sh`는 `>>`로 append만 하므로 재실행하면 블록이 중복된다. 이 부분을 수정할 때는 기존 블록 존재 여부를 먼저 검사하도록 만들 것.
- **`zsh/install.sh`의 심볼릭 링크 경로가 깨져 있다**: `ln -s ./zsh_aliases ~/.zsh_aliases`는 (a) 파일명이 실제로는 `.zsh_aliases`이고 (b) 상대 경로라 링크가 유효하지 않다. 저장소 절대 경로를 쓰도록 고쳐야 정상 동작한다.

## 커밋 메시지

Conventional Commits 접두사(`feat:`, `fix:`) + 한국어 설명. 예: `feat: shottr, openlens, multipass 추가`
