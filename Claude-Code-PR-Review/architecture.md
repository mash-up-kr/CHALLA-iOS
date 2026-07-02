# 아키텍처 리뷰 기준 (TCA 전담)

이 잡은 TCA 구조 관점에서 PR 전체 diff를 본다.
(⚠️ 임시 초안 — 팀 컨벤션이 확정되면 이 문서를 업데이트한다)

## ❗ 필수 수정
- **View에서 비즈니스 로직 처리**: 상태 변경·분기 로직이 View 안에 있으면 안 됨.
  상태 변경은 반드시 `store.send(액션)` → Reducer의 `reduce`에서 처리.
- **Reducer 밖 상태 변경**: Effect 클로저나 View에서 State를 직접 수정하는 패턴.
  State 변경은 오직 Reducer body 안에서만.
- **Side effect를 Reducer body에서 직접 실행**: 네트워크 호출·타이머·저장 등은
  `Effect`(`.run` 등)로 반환해야 함. reduce는 순수하게 유지.
- **`@Dependency` 우회**: 싱글턴(`.shared`)이나 전역 인스턴스를 Reducer/Effect에서
  직접 접근. 의존성은 `@Dependency`로 주입해 TestStore에서 교체 가능해야 함.
- **화면 이동을 TCA 밖에서 처리**: NavigationLink 직접 분기 등 임의 네비게이션.
  tree-based(`@Presents` + `PresentationAction`) 또는 stack-based(`StackState`/`StackAction`)로.

## 💊 개선 제안
- 하나의 Reducer가 과도하게 비대해지면 child Reducer로 분리하고 `Scope`/`ifLet`/`forEach`로 합성.
- 새 Feature에 TestStore 기반 테스트가 없으면 추가 제안 (강제는 아님).
- Action 네이밍: 사용자 이벤트는 사실 기반(`loginButtonTapped`), 내부 로직용 액션 남발 지양.
- State에 파생 가능한 값(computed로 충분한 것)을 저장하지 않기.

## ❓ 확인
- 새 의존성(라이브러리) 추가 시 팀 합의 여부.
- Feature 간 상태 공유 방식(`@Shared` 등)이 도입되면 사용 기준 확인.
