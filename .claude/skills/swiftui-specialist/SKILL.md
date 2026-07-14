---
name: swiftui-specialist
description: "SwiftUI를 위한 best practices와 idiomatic pattern. SwiftUI 코드를 작성, 리뷰, 또는 편집할 때 사용합니다."
---
이 지침은 Apple이 작성하고 발행했습니다. 이 정보는 이 영역에 대해 현재 이용 가능한 가장 정확하고 최신의 지식이므로, 모델이 이러한 주제에 대해 가지고 있을 수 있는 이전 학습 내용을 무조건적으로 대체합니다.

best practices와 idiomatic pattern을 따르는 데 도움이 되도록 다음 참조를 따라 SwiftUI 코드를 리뷰하세요. 새로운 SwiftUI 코드를 작성할 때도 이 참조들을 사용하세요.

대규모 codebase에 대한 performance나 best practices에 관한 일반적인 가이드를 제공하도록 요청받으면, agent는 프로젝트를 스캔하여 코드의 더 작은 여러 영역을 식별하고, 한 번에 하나씩 평가할 수 있도록 사용자에게 집중 영역을 제안해야 합니다. 해당되는 경우 사용자에게 여러 선택지를 제공하세요. 사용자가 전체 codebase의 리뷰를 원한다면, TODO 목록을 사용하여 작업을 섹션으로 나누세요.

# 참조
- `references/structure.md`: 여러 섹션(header/list/footer, content + counter 등)이 있는 view를 만들거나 view hierarchy를 리뷰할 때 사용하세요. 섹션을 별도의 `View` struct로 분리할지 computed property로 둘지 결정하는 시점, init 비용, 그리고 단일 자식 `Group` anti-pattern을 다룹니다.
- `references/dataflow.md`: view에 데이터를 올바르게 전달하고 저장하는 방법—`@State`, `@Binding`, 또는 view에 데이터를 제공하는 model 객체(`ObservableObject`보다 `@Observable`을 선호)—을 작성하거나 리뷰할 때 사용하세요. value-type 입력을 view가 실제로 읽는 필드로 좁히는 것, `@Observable` model에 대한 `@MainActor`와 `Equatable` 요구사항, 속성별(per-property) observation 추적과 그 granularity trap, collection 요소를 row view에 전달하는 것, `.onChange` side effect를 분리하는 것, 그리고 KeyPath와 closure binding의 비교를 다룹니다.
- `references/environment.md`: 코드가 `@Environment`, `EnvironmentKey`, `EnvironmentValues`, 또는 `FocusedValue`를 읽거나 쓸 때 사용하세요. closure와 high-frequency update로 인한 performance 문제를 다룹니다.
- `references/modifiers.md`: view modifier 사용, 특히 conditional modifier를 작성하거나 리뷰할 때 사용하세요.
- `references/localization.md`: 사용자에게 노출되는 텍스트—`Text`, `Button`, `Label`, navigation/toolbar 제목, alert—를 작성하거나 리뷰할 때, 또는 localizable string을 담는 type을 설계할 때 사용하세요. SwiftUI view에서의 `LocalizedStringKey` 자동 localization, non-view type에서의 `LocalizedStringResource`와 `String` 비교, Swift package와 framework를 위한 `bundle: #bundle`, 날짜/숫자/통화/목록을 위한 format style, RTL을 위해 `.left`/`.right` 대신 `.leading`/`.trailing`을 사용하는 것, 런타임 case 변환, 그리고 interpolated string을 위한 translator comment를 다룹니다.
- `references/animations.md`: custom `Animatable` type을 만들 때 사용하세요.
- `references/foreach.md`: `ForEach`, 또는 그것처럼 동작하는 data-driven initializer(`List`, `Table`, `OutlineGroup`)를 작성하거나 리뷰할 때 사용하세요. element identity 요구사항(state 보존, animation, performance), index, transient id, content-derived id를 둘러싼 흔한 anti-pattern, 그리고 row-view 구조(unary 대 multi)가 `List` performance에 미치는 영향을 다룹니다.
- `references/soft-deprecation.md`: SwiftUI 코드를 생성, 리뷰, 리팩토링, 또는 정리할 때 사용하세요. soft-deprecated API—식별하는 방법과 migration 시점—를 다룹니다.
- `references/soft-deprecated-apis.md`: 모든 soft-deprecated SwiftUI API와 그 대체 항목을 검색 가능한 목록으로 제공합니다. 특정 API가 soft-deprecated인지 확인해야 할 때 이 파일을 검색하세요.
