---
paths: Projects/**
---

# 모듈 문서 · 테스트 정책

모든 모듈은 코드와 함께 다음 두 가지를 유지한다.

## MODULE.md (모듈 루트, 예: Projects/Room/RoomDomain/MODULE.md)

- 새 모듈을 만들면 MODULE.md를 함께 만든다. 최소 구성:
  - 소속 레이어와 책임 (한두 문단)
  - 공개 API 목록 (외부 모듈이 쓰라고 열어둔 것)
  - 의존하는 모듈 / 이 모듈에 의존하는 모듈
  - 테스트 실행 방법
- 공개 API를 추가·변경·삭제하면 같은 PR에서 MODULE.md를 갱신한다.

## 테스트 (Tests/)

- 새 로직에는 Swift Testing(`import Testing`, `@Test`, `#expect`) 테스트를 함께 작성한다. XCTest는 신규 작성에 사용하지 않는다.
- TCA Feature는 TestStore로 리듀서 동작을 검증한다.
- 테스트 작성은 `swift-test-creator` 서브에이전트에 위임하고, 작성법은 `swift-testing` 스킬을 참고한다.

> scaffold의 Tests 타깃 자동 생성은 이슈 #8에서 진행 중이다 (`makeModule(hasTests:)` + Tests.stencil).
> MODULE.md 자동 생성은 #8 머지 후 별도 이슈로 추가한다. 그전까지는 새 모듈 생성 시 수동으로 추가한다.
