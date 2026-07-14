---
paths: Projects/**/*Feature/**
---

# TCA Feature 작성 규칙

Feature 모듈은 TCA(The Composable Architecture)로 작성한다.
PR 리뷰 봇도 같은 기준으로 검사한다: `Claude-Code-PR-Review/architecture.md`

## 필수

- Reducer는 `@Reducer` 매크로 + `@ObservableState`를 사용한다.
- 상태 변경은 오직 Reducer body 안에서만 — View나 Effect 클로저에서 State를 직접 수정하지 않는다.
- View에 비즈니스 로직을 두지 않는다 — 분기·상태 변경은 `store.send(액션)`으로 Reducer에 위임한다.
- side effect(네트워크·타이머·저장 등)는 Reducer body에서 직접 실행하지 않고 `Effect`(`.run` 등)로 반환한다.
- 의존성은 `@Dependency`로 주입한다 — 싱글턴(`.shared`)·전역 인스턴스 직접 접근 금지 (TestStore에서 교체 가능해야 함).
- 화면 이동은 TCA 방식으로: tree-based(`@Presents` + `PresentationAction`) 또는 stack-based(`StackState`/`StackAction`). NavigationLink 임의 분기 금지.

## 권장

- Action 네이밍: 사용자 이벤트는 사실 기반(`loginButtonTapped`), 내부 전용 액션 남발 금지.
- State에 computed로 충분한 파생값을 저장하지 않는다.
- Reducer가 비대해지면 child Reducer로 분리하고 `Scope`/`ifLet`/`forEach`로 합성한다.
- 새 Feature에는 TestStore 기반 테스트를 함께 작성한다.

## 참고 스킬

TCA 세부 패턴이 필요하면 `composable-architecture` 스킬(references 14개)을 로드해 참고한다.
설계는 `tca-architect`, 구현은 `tca-engineer` 서브에이전트에 위임한다.
