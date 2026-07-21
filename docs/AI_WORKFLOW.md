# CHALLA AI 워크플로우 가이드

> 이 문서는 **사람이 읽는 온보딩 튜토리얼**입니다. 규칙의 원본은 `CLAUDE.md`와 `.claude/rules/`이며,
> 에이전트 구성이 바뀌면 그쪽을 먼저 고치고 이 문서를 따라 맞춥니다.

Claude Code로 개발할 때 팀 전원이 같은 방식으로 일하기 위한 안내서입니다.
저장소에 커밋된 하네스(CLAUDE.md · 에이전트 · 스킬 · rules · 권한 설정) 덕분에,
**클론만 하면 아래 워크플로우가 그대로 동작합니다.** 별도 설치·설정이 없습니다.

---

## 1. 시작하기

```bash
git clone <repo> && cd CHALLA-iOS
mise install                    # Tuist 설치 (버전 고정)
claude                          # Claude Code 세션 시작
```

첫 세션에서 확인할 것:

| 명령 | 기대 결과 |
| :-- | :-- |
| `/agents` | swift-search, tca-architect 등 **에이전트 10종**이 Project 목록에 표시 |
| `/context` | CLAUDE.md가 로드되어 있음 |

## 2. 하네스 구성 요소 (뭐가 자동으로 동작하나)

| 구성 요소 | 위치 | 언제 동작 |
| :-- | :-- | :-- |
| 프로젝트 컨텍스트 | `CLAUDE.md` | 모든 세션 시작 시 자동 로드 |
| 서브에이전트 10종 | `.claude/agents/` | Claude가 상황에 맞게 자동 위임 (직접 지명도 가능) |
| 스킬 7종 | `.claude/skills/` | 관련 작업 시 자동 로드 — **신경 쓸 필요 없음** |
| 경로 규칙 | `.claude/rules/` | 해당 경로 파일을 만질 때만 자동 로드 |
| 팀 권한 설정 | `.claude/settings.json` | tuist·xcodebuild 등은 확인 프롬프트 없이 실행됨 |

- 커밋 · 푸시 · PR 생성은 **항상 확인 프롬프트가 뜹니다** (의도된 설계 — 자동 실행 금지).

## 3. 개발 파이프라인

이슈 하나를 처리하는 표준 흐름과, 각 단계를 담당하는 에이전트:

```
이슈 확인
  │
  ├─ ① 탐색     swift-search        "관련 코드가 어디 있지?"
  ├─ ② 설계     tca-architect       구현 전 State/Action/의존성 설계   (일반 Swift면 swift-architect)
  │              swift-ui-design     시안·스크린샷 분석이 필요하면 설계 전에
  ├─ ③ 구현     tca-engineer        리듀서·액션·의존성                 (일반 Swift면 swift-engineer)
  ├─ ④ 뷰       swiftui-specialist  코어 로직 완료 후 SwiftUI 뷰
  ├─ ⑤ 리뷰     swift-code-reviewer 커밋 전 셀프 리뷰
  ├─ ⑥ 테스트   swift-test-creator  Swift Testing · TestStore
  ├─ ⑦ 문서     swift-documenter    MODULE.md · 주석 정리
  │
  └─ 커밋 → PR (Resolved: #이슈번호) → 리뷰 봇 + 팀원 리뷰 → 머지
```

원칙: **설계(②) 없이 구현(③)으로 직행하지 않는다.** 나머지 순서는 작업 성격에 따라 생략 가능하지만
(예: 문서 수정에 테스트는 불필요), 새 Feature는 ②~⑦을 모두 거치는 것을 기본으로 한다.

## 4. 실전 예시 — "방 생성 화면" 이슈를 받았다면

Claude에게 이렇게 말하면 됩니다 (에이전트 이름을 몰라도 알아서 위임하지만, 지명하면 확실합니다):

```
1. "RoomCreateFeature 관련해서 기존에 비슷한 화면 구조 있는지 찾아줘"
     → swift-search가 탐색

2. "이슈 #23 방 생성 화면 만들 건데, tca-architect로 설계부터 해줘"
     → State/Action/의존성/네비게이션 설계안이 나옴

3. "설계대로 구현해줘"
     → tca-engineer가 리듀서, swiftui-specialist가 뷰 구현

4. "커밋 전에 리뷰하고 테스트 만들어줘"
     → swift-code-reviewer → swift-test-creator 순서로 실행

5. "MODULE.md 갱신하고 커밋 준비해줘"
     → swift-documenter 정리 후, 커밋은 확인 프롬프트에서 승인
```

## 5. 개인화 (팀 설정을 건드리지 않고)

| 하고 싶은 것 | 방법 |
| :-- | :-- |
| 나만의 지시 추가 (말투, 개인 습관 등) | 루트에 `CLAUDE.local.md` 생성 (gitignore됨) |
| 나만의 권한 허용 추가 | `.claude/settings.local.json` (자동 생성·gitignore됨) |
| 내 모든 프로젝트 공통 설정 | `~/.claude/CLAUDE.md`, `~/.claude/skills/` (저장소 밖) |

## 6. 금지사항

- `.claude/settings.json`(팀 공유)에 **개인 토큰·API 키·개인 경로를 넣지 않는다** — 개인 항목은 전부 `settings.local.json`으로
- 시크릿이 커밋에 섞이면 즉시 팀에 공유하고 해당 키를 재발급한다
- 에이전트·스킬·rules를 수정할 때는 PR로 — 하네스도 코드처럼 리뷰받는다
