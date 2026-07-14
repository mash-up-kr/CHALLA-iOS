---
name: composable-architecture
description: Use when building features with TCA (The Composable Architecture), structuring reducers, managing state, handling effects, navigation, or testing TCA features. Covers @Reducer, Store, Effect, TestStore, reducer composition, and TCA patterns.
---

# The Composable Architecture (TCA)

TCA는 composable reducer, 중앙화된 state 관리, side effect 처리를 통해 복잡하고 testable한 feature를 구축하기 위한 architecture를 제공합니다. 핵심 원칙은 명확한 dependency와 testable한 effect를 가진 예측 가능한 state 진화입니다.

## Reference 로딩 가이드

**해당 내용이 필요할 가능성이 조금이라도 있다면 항상 reference 파일을 로드하세요.** 패턴을 놓치거나 실수를 하는 것보다 context를 확보하는 것이 낫습니다.

| Reference | 로드해야 하는 경우 |
|-----------|-----------|
| **[Reducer Structure](references/reducer-structure.md)** | 새로운 reducer를 만들거나, `@Reducer`, `State`, `Action`, `@ViewAction`을 설정할 때 |
| **[Views - Binding](references/views-binding.md)** | `@Bindable`, 양방향 binding, `store.send()`, `.onAppear`/`.task`를 사용할 때 |
| **[Views - Composition](references/views-composition.md)** | store와 함께 `ForEach`를 사용하거나, child feature로 scoping하거나, optional child를 다룰 때 |
| **[Navigation - Basics](references/navigation-basics.md)** | `NavigationStack`, path reducer 설정, push/pop, 또는 programmatic dismiss를 다룰 때 |
| **[Navigation - Advanced](references/navigation-advanced.md)** | deep linking, 재귀적 navigation, 또는 NavigationStack과 sheet를 결합할 때 |
| **[Shared State](references/shared-state.md)** | `@Shared`, `.appStorage`, `.withLock`을 사용하거나 feature 간 state를 공유할 때 |
| **[Dependencies](references/dependencies.md)** | `@DependencyClient`를 만들거나, `@Dependency`를 사용하거나, test dependency를 설정할 때 |
| **[Effects](references/effects.md)** | `.run`, `.send`, `.merge`, timer, effect cancellation, 또는 async 작업을 사용할 때 |
| **[Presentation](references/presentation.md)** | `@Presents`, `AlertState`, sheet, popover, 또는 Destination 패턴을 사용할 때 |
| **[Testing - Fundamentals](references/testing-fundamentals.md)** | test suite를 설정하거나, `makeStore` helper를 사용하거나, Equatable 요구사항을 이해할 때 |
| **[Testing - Patterns](references/testing-patterns.md)** | action, state 변경, dependency, error, presentation을 테스트할 때 |
| **[Testing - Advanced](references/testing-advanced.md)** | `TestClock`, keypath matching, `exhaustivity = .off`, 또는 시간 기반 테스트를 사용할 때 |
| **[Testing - Utilities](references/testing-utilities.md)** | test data factory, `LockIsolated`, `ConfirmationDialogState` 테스트, 또는 `@Shared` 테스트를 다룰 때 |
| **[Performance](references/performance.md)** | state 업데이트, 고빈도 action, 메모리, 또는 store scoping을 최적화할 때 |

## 흔한 실수

1. **feature를 과도하게 모듈화하는 것** — feature를 너무 많은 작은 reducer로 나누면 state 관리가 어려워지고 composition overhead가 늘어납니다. 실제로 재사용되는 경우가 아니라면 관련된 state와 action은 함께 유지하세요.

2. **effect lifetime을 잘못 관리하는 것** — state가 변경될 때 effect를 취소하지 않으면 오래된 data, 중복 요청, race condition이 발생합니다. 순차적인 effect에는 `.concatenate`를, 필요한 경우 `.cancel`을 사용하세요.

3. **navigation state를 잘못된 위치에 두는 것** — navigation state를 parent가 아닌 child reducer에 두면 불필요한 view reload와 state 불일치가 발생합니다. navigation state는 navigation 구조를 소유하는 feature에 있어야 합니다.

4. **TestStore exhaustivity 없이 테스트하는 것** — "단순한" effect나 "당연한" state 변경에 대해 TestStore assertion을 생략하면 버그를 놓치게 됩니다. exhaustivity checking을 철저히 사용하세요. 이는 회귀(regression)를 조기에 잡아냅니다.

5. **async/await와 Effect를 잘못 혼용하는 것** — 적절한 cancellation이나 error handling 없이 async/await를 `.run` effect로 변환하면 isolation 보장을 잃게 됩니다. `.run` 안에서 `yield` 문을 사용해 async 작업을 신중하게 감싸세요.
