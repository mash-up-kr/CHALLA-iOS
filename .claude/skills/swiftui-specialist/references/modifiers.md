# Conditional View Modifiers

boolean 값에 따라 `transform(self)`와 `self` 사이를 전환하기 위해 `@ViewBuilder`를 사용하는 conditional view modifier(때때로 `.if` modifier라고 불림)를 작성하지 마세요. codebase에 기존 conditional view modifier가 있다면 제거하거나 refactor하지 마세요(그렇게 하면 동작이 바뀔 수 있으며 범위를 벗어납니다). 다만 리뷰할 때는 예상치 못한 동작을 유발할 수 있음을 짚어주고 아래의 대안을 설명하세요.

## Conditional view modifiers가 문제가 되는 이유

1. **View identity loss**: modifier 내부의 `if`/`else`는 서로 다른 view type을 가진 두 개의 branch를 생성합니다. condition이 전환될 때 SwiftUI는 동일한 view가 수정된 것이 아니라 완전히 다른 view로 인식합니다. 이는 structural identity를 깨뜨립니다.
2. **State reset**: condition이 변경되면 view나 그 descendant에 있는 모든 `@State`가 초기화됩니다. SwiftUI가 두 branch를 서로 다른 view로 취급하기 때문입니다.
3. **Broken animations**: SwiftUI는 property 변경을 부드럽게 animate하는 대신 하나의 view를 제거하고 다른 view를 삽입하여 급작스러운 transition을 만듭니다.

```swift
// 피하세요: conditional view modifier extension.
// `condition`이 전환될 때마다 structural identity를 파괴합니다.
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// anti-pattern의 사용 예:
Text("Hello")
    .if(isHighlighted) { $0.foregroundStyle(.red) }
```

```swift
// 선호: modifier argument에 ternary expression을 사용하세요.
// view identity가 보존되며 SwiftUI가 변경을 부드럽게 animate합니다.
Text("Hello")
    .foregroundStyle(isHighlighted ? .red : .primary)
```
