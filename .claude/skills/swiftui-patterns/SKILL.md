---
name: swiftui-patterns
description: >-
  iOS 17+ SwiftUI patterns를 구현할 때 사용합니다: @Observable/@Bindable, MVVM architecture, NavigationStack, lazy loading, UIKit interop, accessibility (VoiceOver/Dynamic Type), 비동기 작업(.task/.refreshable), 또는 ObservableObject/@StateObject에서 마이그레이션하는 경우.
---

# SwiftUI Patterns (iOS 17+)

SwiftUI 17+는 @Observable로 ObservableObject 보일러플레이트 코드를 제거하고, @Environment로 environment 주입을 단순화하며, task 기반 async patterns를 도입합니다. 핵심 원칙은 리액티브 라이브러리 대신 Apple의 최신 API를 사용하는 것입니다.

## 개요

## 빠른 참조

| 필요 | 사용 (iOS 17+) | 사용 금지 |
|------|---------------|-----|
| Observable 모델 | `@Observable` | `ObservableObject` |
| Published 속성 | 일반 속성 | `@Published` |
| 자체 상태 | `@State` | `@StateObject` |
| 전달된 모델 (바인딩) | `@Bindable` | `@ObservedObject` |
| Environment 주입 | `environment(_:)` | `environmentObject(_:)` |
| Environment 접근 | `@Environment(Type.self)` | `@EnvironmentObject` |
| 화면 표시 시 비동기 실행 | `.task { }` | `.onAppear { Task {} }` |
| 값 변경 | `onChange(of:initial:_:)` | `onChange(of:perform:)` |

## 핵심 워크플로우

1. 모델 클래스에는 `@Observable`을 사용합니다 (@Published 불필요)
2. View가 소유하는 모델에는 `@State`를, 전달되는 모델에는 `@Bindable`을 사용합니다
3. 비동기 작업에는 `.task { }`를 사용합니다 (사라질 때 자동으로 취소됨)
4. 프로그래밍 방식 내비게이션에는 `NavigationPath`와 함께 `NavigationStack`을 사용합니다
5. 상호작용 요소에 `.accessibilityLabel()`과 `.accessibilityHint()`를 적용합니다

## 참조 로딩 가이드

**콘텐츠가 필요할 가능성이 조금이라도 있다면 항상 참조 파일을 로드하세요.** pattern을 놓치거나 실수를 하는 것보다 context를 확보하는 것이 더 낫습니다.

| 참조 | 로드 시기 |
|-----------|-----------|
| **[Observable](references/observable.md)** | 새로운 `@Observable` 모델 클래스를 생성할 때 |
| **[State 관리](references/state-management.md)** | `@State`, `@Bindable`, `@Environment` 중에서 선택할 때 |
| **[Environment](references/environment.md)** | View 계층 구조에 의존성을 주입할 때 |
| **[View Modifiers](references/view-modifiers.md)** | `onChange`, `task`, 또는 iOS 17+ modifier를 사용할 때 |
| **[마이그레이션 가이드](references/migration-guide.md)** | iOS 16 코드를 iOS 17+로 업데이트할 때 |
| **[MVVM Observable](references/mvvm-observable.md)** | view model architecture를 설정할 때 |
| **[내비게이션](references/navigation.md)** | 프로그래밍 방식 또는 딥링크 내비게이션 |
| **[성능](references/performance.md)** | 항목이 100개 이상인 List 또는 과도한 리렌더링 |
| **[UIKit Interop](references/uikit-interop.md)** | UIKit 컴포넌트(WKWebView, PHPicker)를 래핑할 때 |
| **[Accessibility](references/accessibility.md)** | VoiceOver, Dynamic Type, accessibility 액션 |
| **[Async Patterns](references/async-patterns.md)** | 로딩 상태, 새로고침, 백그라운드 task |
| **[Composition](references/composition.md)** | 재사용 가능한 view modifier 또는 복잡한 조건부 UI |

## 흔히 하는 실수

1. **전달된 모델에 `@Bindable`을 과도하게 사용** — 모든 속성마다 `@Bindable`을 생성하면 불필요하게 View가 다시 로드됩니다. `@Bindable`은 양방향 바인딩이 필요한 변경 가능한 모델 속성에만 사용하세요. 읽기 전용 계산 속성은 일반 속성을 사용해야 합니다.

2. **상태 배치 오류** — 전용 `@Observable` 모델 대신 View에 모델 상태를 두면 View 로직이 뒤엉키게 됩니다. 항상 모델과 View의 관심사를 분리하세요.

3. **NavigationPath 상태 손상** — `NavigationPath`를 잘못 변경하면 일관되지 않은 상태로 남을 수 있습니다. 경로 손상을 피하려면 적절한 상태 관리와 함께 `navigationDestination(for:destination:)`을 사용하세요.

4. **`.task` 취소 누락** — `.task`는 사라질 때 자동으로 취소를 처리하지만, 중첩된 Task는 그렇지 않습니다. 복잡한 async 흐름에서는 zombie task를 피하기 위해 명시적인 취소 추적이 필요합니다.

5. **environment invalidation 무시** — 부모에서 environment 값을 변경해도 자식 View가 자동으로 무효화되지는 않습니다. `@Environment`를 일관되게 사용하고, observation을 기반으로 리렌더링이 언제 발생하는지 이해하세요.

6. **UIKit interop 메모리 누수** — delegate cycle이 끊어지지 않으면 `UIViewRepresentable`과 `UIViewControllerRepresentable`이 누수될 수 있습니다. weak reference와 명시적인 정리가 필요합니다.
