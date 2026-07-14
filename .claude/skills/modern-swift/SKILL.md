---
name: modern-swift
description: async/await 코드를 작성하거나, strict concurrency를 활성화하거나, Sendable 오류를 수정하거나, completion handler로부터 마이그레이션하거나, actor로 공유 상태를 관리하거나, 동시성을 위해 Task/TaskGroup을 사용할 때 사용합니다.
---

# 모던 Swift (6.2+)

Swift 6.2는 async/await, actor, 그리고 Sendable 제약을 통해 컴파일 타임에 strict concurrency 검사를 도입하여, 런타임이 아닌 컴파일 타임에 data race를 방지합니다. 이것이 안전한 동시성 Swift의 기반입니다.

## 개요

모던 Swift는 이전의 동시성 pattern(completion handler, DispatchQueue, lock)을 컴파일러가 강제하는 안전성으로 대체합니다. 핵심 원칙: strict concurrency가 활성화된 상태로 컴파일된다면, data race가 있을 수 없습니다.

## 빠른 참조

| 필요 사항 | 사용 | 사용하지 말 것 |
|------|-----|-----|
| 비동기 작업 | `async/await` | Completion handler |
| 메인 스레드 작업 | `@MainActor` | `DispatchQueue.main` |
| 공유 가변 상태 | `actor` | Lock, serial queue |
| 병렬 작업 | `TaskGroup` | `DispatchGroup` |
| 스레드 안전성 | `Sendable` | 어디에나 `@unchecked` |

## 핵심 워크플로우

비동기 Swift 코드를 작성할 때:
1. `async`로 비동기 함수를 표시하고 `await`로 호출합니다
2. view model과 UI를 업데이트하는 코드에 `@MainActor`를 적용합니다
3. 공유 가변 상태에는 lock 대신 `actor`를 사용합니다
4. 루프에서 `Task.isCancelled`를 확인하거나 `Task.checkCancellation()`을 호출합니다
5. 컴파일 타임 안전성을 위해 Package.swift에서 strict concurrency를 활성화합니다

## 참조 로딩 가이드

**콘텐츠가 필요할 가능성이 조금이라도 있다면 항상 참조 파일을 로드하세요.** pattern을 놓치거나 실수를 하는 것보다 컨텍스트를 확보하는 것이 낫습니다.

| 참조 | 로드 시점 |
|-----------|-----------|
| **[Concurrency 핵심 개념](references/concurrency-essentials.md)** | 비동기 코드를 작성하거나, completion handler를 변환하거나, `await`를 사용할 때 |
| **[Swift 6 Concurrency](references/swift6-concurrency.md)** | `@concurrent`, `nonisolated(unsafe)`, 또는 actor pattern을 사용할 때 |
| **[Task Groups](references/task-groups.md)** | 여러 비동기 작업을 병렬로 실행할 때 |
| **[Task Cancellation](references/task-cancellation.md)** | 장시간 실행되거나 취소 가능한 작업을 구현할 때 |
| **[Strict Concurrency](references/strict-concurrency.md)** | Swift 6 strict mode를 활성화하거나 Sendable 오류를 수정할 때 |
| **[Macros](references/macros.md)** | `@Observable`과 같은 Swift macro를 사용하거나 이해할 때 |
| **[Modern 속성](references/modern-attributes.md)** | 레거시 코드를 마이그레이션하거나 `@preconcurrency`, `@backDeployed`를 사용할 때 |
| **[마이그레이션 Pattern](references/migration-patterns.md)** | delegate pattern이나 UIKit view를 모던화할 때 |

## 일반적인 실수

1. **`@unchecked Sendable`을 임시 해결책으로 사용** — 컴파일러 오류를 잠재우기 위해 `@unchecked Sendable`을 사용하는 것은 안전성을 포기한다는 의미입니다. `@unchecked` 적용 후에도 오류가 계속된다면, 코드에 잠재적인 data race가 있는 것입니다. 근본적인 문제를 대신 해결하세요.

2. **호출 지점에서 `await`를 빠뜨림** — 비동기 함수를 호출할 때 `await`를 잊는 것은 컴파일 오류이지만, `Task.checkCancellation()`을 호출하지 않고 루프에서 `Task.isCancelled`만 확인하면 취소가 조용히 무시됩니다.

3. **`weak` 없이 비동기 블록에서 `self`를 캡처** — 장시간 실행되는 비동기 task에서 `self`에 대한 강한 참조를 유지하면 deinit이 방지됩니다. 클로저에서는 항상 `[weak self]`를 사용하거나, lifecycle을 자동으로 관리하는 `.task`를 사용하세요.

4. **task 취소를 확인하지 않음** — 장시간 실행되는 작업은 정기적으로 `Task.isCancelled`를 확인하거나 `Task.checkCancellation()`을 호출해야 하며, 그렇지 않으면 취소 신호가 무시됩니다.

5. **UI 코드와 테스트 스위트에서 `@MainActor`를 빠뜨림** — `@Published` 속성을 업데이트하는 메인 테스트 struct와 view model에는 `@MainActor`가 필요합니다. 이를 빠뜨리면 스레드 간 변경이 조용히 허용됩니다. `@MainActor`를 다음에 적용하세요: view model, view struct, 메인 테스트 struct, 그리고 UI를 다루는 모든 type.

6. **actor 재진입(re-entrancy)의 놀라운 동작** — actor 메서드 내부의 `await`는 일시적으로 lock을 해제할 수 있습니다. 다른 task가 actor 상태를 수정할 수 있습니다. `await` 지점 사이에 상태가 변경될 수 있다고 가정하고 actor 메서드를 설계하세요.
