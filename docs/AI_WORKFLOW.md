# CHALLA AI 워크플로우 가이드

> 이 문서는 **사람이 읽는 온보딩 튜토리얼**입니다. 규칙의 원본은 `CLAUDE.md`와 `.claude/rules/`이며,
> 에이전트 구성이 바뀌면 그쪽을 먼저 고치고 이 문서를 따라 맞춥니다.

Claude Code로 개발할 때 팀 전원이 같은 방식으로 일하기 위한 안내서입니다.
저장소에 커밋된 하네스(CLAUDE.md · 에이전트 · 스킬 · rules · 권한 설정) 덕분에,
**클론하면 아래 워크플로우가 거의 그대로 동작합니다.**
단 하나, Zeplin MCP만 개인 토큰이 필요해 1회 세팅이 필요합니다 (1-2절).

---

## 1. 시작하기

### 1-1. 클론과 빌드 환경

```bash
git clone <repo> && cd CHALLA-iOS
./Scripts/bootstrap.sh          # 도구 설치 · 서명 설정 · git 훅 · 워크스페이스 생성 (재실행 안전)
claude                          # Claude Code 세션 시작
```

`Configs/Shared.xcconfig`(gitignore)는 bootstrap이 template에서 만들어주고, **팀 ID만 직접 입력**하면 됩니다.
git worktree를 새로 팔 때도 bootstrap을 한 번 실행하세요 — gitignore 대상이라 따라오지 않아
`tuist generate`가 `Fatal linting issues found`로 실패합니다.

### 1-2. Zeplin MCP 세팅 (1회, 각자)

시안 조회·UI 검증을 쓰려면 **본인 Zeplin 토큰이 필요합니다.** 저장소에는 토큰이 들어있지 않습니다
(개인 계정 단위 비밀값이라 커밋하지 않습니다).

1. Zeplin 웹 → 프로필 → **Developer → Personal access tokens** → 토큰 생성
   - 생성 직후 한 번만 보이므로 바로 복사
2. 셸에 환경변수 등록 후 터미널 재시작

   ```bash
   echo 'export ZEPLIN_ACCESS_TOKEN=여기에_붙여넣기' >> ~/.zshrc
   source ~/.zshrc
   ```
3. `claude` 실행 → `/mcp` → **zeplin이 connected** 인지 확인

MCP 서버 자체는 설치할 게 없습니다. `.mcp.json`이 `npx -y @zeplin/mcp-server@latest`로 실행하므로
세션 시작 시 자동으로 받아서 띄웁니다 (첫 실행만 몇 초 걸립니다).

> 이 세팅을 건너뛰어도 나머지 개발은 전부 정상 동작합니다. 시안 조회만 실패합니다.

**시안의 원본은 Figma지만 개발이 참조하는 창구는 Zeplin입니다.** Figma에서 Zeplin으로 export한 뒤
조회합니다. Figma를 직접 조회하지 않는 이유는 5절에 있습니다.

### 1-3. 첫 세션 점검

| 명령 | 기대 결과 |
| :-- | :-- |
| `/agents` | swift-search, tca-architect 등 **에이전트 10종**이 Project 목록에 표시 |
| `/context` | CLAUDE.md가 로드되어 있음 |
| `/mcp` | **zeplin — connected** |

`/mcp`에서 zeplin이 failed로 뜬다면 → 5절 문제 해결.

## 2. 하네스 구성 요소 (뭐가 자동으로 동작하나)

| 구성 요소 | 위치 | 언제 동작 |
| :-- | :-- | :-- |
| 프로젝트 컨텍스트 | `CLAUDE.md` | 모든 세션 시작 시 자동 로드 |
| 서브에이전트 10종 | `.claude/agents/` | Claude가 상황에 맞게 자동 위임 (직접 지명도 가능) |
| 스킬 8종 | `.claude/skills/` | 관련 작업 시 자동 로드 — **신경 쓸 필요 없음** |
| 경로 규칙 | `.claude/rules/` | 해당 경로 파일을 만질 때만 자동 로드 |
| 팀 권한 설정 | `.claude/settings.json` | tuist·xcodebuild 등은 확인 프롬프트 없이 실행됨 |
| Zeplin MCP | `.mcp.json` | 세션 시작 시 자동 실행 — **개인 토큰 세팅 필요 (1-2절)** |

- 커밋 · 푸시 · PR 생성은 **항상 확인 프롬프트가 뜹니다** (의도된 설계 — 자동 실행 금지).

## 3. 개발 파이프라인

이슈 하나를 처리하는 표준 흐름과, 각 단계를 담당하는 에이전트:

```
이슈 확인
  │
  ├─ ① 탐색     swift-search        "관련 코드가 어디 있지?"
  ├─ ② 설계     tca-architect       구현 전 State/Action/의존성 설계   (일반 Swift면 swift-architect)
  │              swift-ui-design     Zeplin 시안을 MCP로 조회해 스펙 추출 (설계 전에)
  ├─ ③ 구현     tca-engineer        리듀서·액션·의존성                 (일반 Swift면 swift-engineer)
  ├─ ④ 뷰       swiftui-specialist  코어 로직 완료 후 SwiftUI 뷰
  ├─ ④.5 UI검증 zeplin-ui-verification 시뮬레이터 화면 vs 시안 스펙 대조 (요청 없이 자동)
  ├─ ⑤ 리뷰     swift-code-reviewer 커밋 전 셀프 리뷰
  ├─ ⑥ 테스트   swift-test-creator  Swift Testing · TestStore
  ├─ ⑦ 문서     swift-documenter    MODULE.md · 주석 정리
  │
  └─ 커밋 → PR (Resolved: #이슈번호) → 리뷰 봇 + 팀원 리뷰 → 머지
```

원칙: **설계(②) 없이 구현(③)으로 직행하지 않는다.** 나머지 순서는 작업 성격에 따라 생략 가능하지만
(예: 문서 수정에 테스트는 불필요), 새 Feature는 ②~⑦을 모두 거치는 것을 기본으로 한다.

**시안을 주고 개발을 요청하면 ② → ④ → ④.5가 한 번에 진행됩니다.** 검증을 따로 요청하지 않아도
구현 후 시안 대조 표까지 나옵니다 — 시안 기반 UI 작업은 검증까지가 완료 조건입니다.

## 4. 실전 예시 — "방 생성 화면" 이슈를 받았다면

시안이 있으면 **한 번에 요청하면 됩니다.** 스펙 추출 → 구현 → 시안 대조가 이어서 진행됩니다.

```
"이슈 #23 방 생성 화면 만들어줘. 시안은 Zeplin '방 생성' 화면"

  → swift-ui-design    Zeplin MCP로 조회 → 레이아웃·토큰 매핑 표
  → tca-architect      State/Action/의존성 설계
  → tca-engineer       리듀서 구현
  → swiftui-specialist 뷰 구현
  → zeplin-ui-verification  시뮬레이터 실행 → PASS/DIFF 표 (요청 없이 자동)
```

DIFF가 나오면 고치기 전에 보고합니다. 시안이 틀린 경우도 있어서, 무엇을 고칠지는 확인 후 결정합니다.

단계별로 쪼개서 지시하고 싶다면 이렇게도 됩니다 (에이전트 이름을 몰라도 알아서 위임합니다).

```
1. "RoomCreateFeature 관련해서 기존에 비슷한 화면 구조 있는지 찾아줘"     → swift-search
2. "Zeplin '방 생성' 화면 스펙 뽑아줘"                                  → swift-ui-design
3. "설계부터 해줘"                                                      → tca-architect
4. "설계대로 구현해줘"                                                  → tca-engineer → swiftui-specialist
5. "리뷰하고 테스트 만들어줘"                                            → swift-code-reviewer → swift-test-creator
6. "MODULE.md 갱신하고 커밋 준비해줘"                                    → swift-documenter
```

같은 이름의 화면이 여럿이면(예: "상세"가 다수) Zeplin 링크를 주는 게 확실합니다.

## 5. 문제 해결

### `/mcp`에서 zeplin이 failed로 뜬다

| 확인 | 방법 |
| :-- | :-- |
| 환경변수가 셸에 있는가 | `echo ${ZEPLIN_ACCESS_TOKEN:+설정됨}` — 비어 있으면 1-2절 재실행 후 **터미널 재시작** |
| Claude Code가 그 변수를 봤는가 | 환경변수를 추가한 뒤 켜둔 세션은 예전 환경을 씁니다. `claude` 재실행 |
| 토큰이 유효한가 | 아래 명령이 200을 반환하는지 확인 |

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $ZEPLIN_ACCESS_TOKEN" https://api.zeplin.dev/v1/projects
# 200 정상 / 401 invalid_token
```

`.zshrc`에 `export` 없이 붙여넣거나 `= "값"`처럼 등호 뒤에 공백이 들어가면 셸이 값을 읽지 못합니다.

### Zeplin 사용량 제한

API 호출은 분당 200회(사용자 단위, 플랜별 차등 없음)라 평소 작업에서 걸리지 않습니다.
실질적인 상한은 **무료 플랜의 용량**입니다 — 프로젝트 1개 / 화면 100개 / **컴포넌트 100개** / 버전 기록 30일.
컴포넌트 슬롯은 아이콘이 빠르게 차지하므로, export 전에 남은 개수를 확인하세요.

### 왜 Figma를 직접 조회하지 않는가

Figma REST 파일 조회는 무료(Starter) 팀에서 **월 6회**로 제한돼 실사용이 불가능합니다.
편집 권한이나 팀 멤버 여부로는 해결되지 않고, 개발자가 개인적으로 유료 시트를 사도 무효입니다 —
Figma 구독은 팀 단위라 무료 팀 파일에는 적용되지 않습니다.

그래서 **Figma → Zeplin export 후 Zeplin을 조회**합니다.
Zeplin은 무료 플랜에도 API가 포함되고 분당 200회입니다.

디자인팀이 Figma Professional로 전환하면 재검토할 수 있습니다.
검증 과정과 실측 데이터는 이슈 #15에 있습니다.

## 6. 개인화 (팀 설정을 건드리지 않고)

| 하고 싶은 것 | 방법 |
| :-- | :-- |
| 나만의 지시 추가 (말투, 개인 습관 등) | 루트에 `CLAUDE.local.md` 생성 (gitignore됨) |
| 나만의 권한 허용 추가 | `.claude/settings.local.json` (자동 생성·gitignore됨) |
| 내 모든 프로젝트 공통 설정 | `~/.claude/CLAUDE.md`, `~/.claude/skills/` (저장소 밖) |

## 7. 금지사항

- `.claude/settings.json`(팀 공유)과 `.mcp.json`에 **개인 토큰·API 키·개인 경로를 넣지 않는다** — 개인 항목은 전부 `settings.local.json`으로, 토큰은 환경변수로
- 시크릿이 커밋에 섞이면 즉시 팀에 공유하고 해당 키를 재발급한다
- 에이전트·스킬·rules를 수정할 때는 PR로 — 하네스도 코드처럼 리뷰받는다
