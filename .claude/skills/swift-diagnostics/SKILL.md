---
name: swift-diagnostics
description: NavigationStack 문제(응답 없음, 예기치 않은 pop, 크래시), build 실패(SPM resolution, "No such module", build가 멈추는 경우), 또는 메모리 문제(retain cycle, leak, deinit이 호출되지 않는 경우)를 디버깅할 때 사용합니다. iOS/macOS를 위한 체계적인 진단 워크플로우입니다.
---

# Swift 진단

iOS/macOS 개발을 위한 체계적인 디버깅 워크플로우입니다. 이 pattern들은 구조화된 진단 접근 방식을 따라 몇 시간이 아닌 몇 분 안에 근본 원인을 파악하는 데 도움이 됩니다.

## 참조 로딩 가이드

**내용이 필요할 가능성이 조금이라도 있다면 항상 참조 파일을 로드하세요.** pattern을 놓치거나 실수를 하는 것보다 context를 확보하는 것이 낫습니다.

| 참조 | 로드 시점 |
|-----------|-----------|
| **[Navigation](references/navigation.md)** | NavigationStack이 응답하지 않음, 예기치 않은 pop, 딥링크 실패 |
| **[Build Issues](references/build-issues.md)** | SPM resolution, "No such module", 의존성 충돌 |
| **[Memory](references/memory.md)** | Retain cycle, 메모리 증가, deinit이 호출되지 않음 |
| **[Build Performance](references/build-performance.md)** | 느린 build, Derived Data 문제, Xcode 행(hang) |
| **[Xcode Debugging](references/xcode-debugging.md)** | LLDB 명령어, breakpoint, view debugging |

## 핵심 워크플로우

1. **증상 카테고리 파악** - Navigation, build, memory, 또는 performance
2. **관련 참조 로드** - 각 참조에는 진단 결정 트리가 있습니다
3. **필수 선행 확인 실행** - 코드를 변경하기 전에
4. **결정 트리 따르기** - 2-5분 안에 진단에 도달
5. **수정 적용 및 검증** - 한 번에 하나씩 수정하고 각각 테스트

## 핵심 원칙

"미스터리한" 문제의 80%는 예측 가능한 pattern에서 비롯됩니다.
- Navigation: path 상태 관리 또는 destination 배치
- Build: 오래된 캐시 또는 의존성 resolution
- Memory: Timer/observer leak 또는 closure capture
- Performance: 코드 버그가 아닌 environment 문제

체계적으로 진단하세요. 절대 추측하지 마세요.

## 흔한 실수

1. **필수 선행 확인을 건너뛰기** — 진단(clean build, Simulator 재시작, Xcode 재시작)을 실행하기 전에 곧바로 코드 수정으로 뛰어들면 헛수고를 하게 됩니다. 항상 필수 확인부터 시작하세요.

2. **한 번에 여러 가지를 변경하기** — "DerivedData도 삭제하고 Simulator도 재시작하고 Xcode도 종료해보자"는 식으로 하면 실제로 어떤 수정이 효과가 있었는지 구분할 수 없습니다. 한 번에 하나의 변수만 변경하세요.

3. **원인을 안다고 가정하기** — "NavigationStack이 작동을 멈췄으니 내 reducer 문제일 것이다" — 실제로는 오래된 DerivedData가 원인이었습니다. 진단 트리는 이러한 가정을 방지합니다. 트리를 따르고, 추측하지 마세요.

4. **메모리 기본 사항을 놓치기** — `deinit`이 호출되지 않는 것은 retain cycle이지만, 초보자들은 흔히 architecture를 탓합니다. 리팩터링 전에 Instruments로 leak을 확인하세요. 직관이 아니라 데이터입니다.

5. **문제를 격리하지 않기** — 전체 앱으로 테스트하면 진단이 복잡해집니다. 문제가 되는 기능만 담은 최소한의 재현 가능한 예제를 만드세요. 격리를 통해 근본 원인이 드러납니다.
