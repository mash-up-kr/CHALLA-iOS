# Environment 성능

## environment 비교의 동작 방식

environment 값이 전파될 때, SwiftUI는 이전 값과 새 값을 비교하여 각 reader가 재평가(re-evaluate)되어야 하는지를 판단합니다. 이 비교에 관한 네 가지 사실이 이 문서의 나머지 내용을 좌우합니다:

- **struct는 필드 단위로 비교됩니다.** `Equatable`을 준수하지 않는 struct라도 모든 필드가 동일해 보이면 같다고 비교됩니다 — `Equatable`은 빠른 경로(fast path)일 뿐 필수 조건이 아닙니다.
- **class 참조는 identity로 비교됩니다.** 같은 instance를 가리키는 두 참조는 같다고 판단되지만, 새로 할당된 instance로 재할당하면 다르다고 판단됩니다.
- **함수 값(closure)은 신뢰성 있게 비교할 수 없습니다.** SwiftUI는 다시 읽을 때마다 값이 변경된 것으로 취급하며, subtree 안의 모든 reader가 무효화됩니다.
- **environment에 대한 모든 쓰기는 전체 subtree로 전파됩니다.** 어떤 key가 변경되면 reader들은 자신의 key를 다시 읽습니다. *default*로 폴백하는 reader는 매 패스마다 그 default가 다시 평가되므로 — 불안정한 default는 관련 없는 env 쓰기가 있을 때마다 무효화됩니다.

동일한 모델이 `EnvironmentValues` / `@Environment`와 `FocusedValues` / `@FocusedValue`에 모두 적용됩니다. 아래 섹션의 규칙은 둘 다에 적용됩니다.

## Environment 안의 closure

이 섹션은 여러분이 직접 정의하는 **custom** environment 및 focus-value key에 관한 내용입니다. framework에서 제공하는 action 타입 — `OpenURLAction`, `DismissAction`, `RefreshAction` 등 — 은 closure를 감싸서 framework에서 제공하는 key(`\.openURL`, `\.dismiss`, `\.refresh` 등)와 짝을 이루도록 설계되어 있습니다. 이런 key에 closure를 전달하는 것은 의도된 API이며 아래에서 설명하는 anti-pattern이 **아닙니다**. 이들을 defunctionalize하거나, custom struct나 protocol로 대체하거나, 대응하는 framework key를 피하도록 제안하지 마세요. environment에 closure가 있는 지점을 지적하기 전에, 해당 key가 framework에서 제공하는 것인지 먼저 확인하세요. 만약 그렇다면 이 규칙은 건너뛰어도 됩니다.

여러분이 직접 만든 custom environment key에는 절대 closure나 함수 값을 저장하지 마세요. `FocusedValueKey`에도 동일하게 적용됩니다. closure는 신뢰성 있게 비교할 수 없기 때문에, 해당 environment key를 읽는 뷰는 아무것도 바뀌지 않았어도 무효화될 수 있습니다. 비교 heuristic은 컴파일러 최적화 수준에 따라 다르며, signature와 capture에 따라서도 달라집니다. 이 규칙은 예외 없이 적용됩니다 — 특정 closure가 지금 당장은 우연히 동일하게 비교된다고 해도(capture가 없는 no-op이 흔히 그렇습니다), 이후 작성자가 capture를 추가하는 것을 막을 방법이 없고, framework도 이를 보장할 방법을 제공하지 않습니다. environment나 focus value에 closure를 넣는 방식을 억지로 동작하게 만들려고 하지 마세요. closure를 struct의 저장 property로 감싸는 것도 받아들일 수 있는 해결책이 아닙니다 — 여전히 struct 안에 closure가 있으므로 비교는 여전히 실패합니다. 올바른 해결책은 closure 자체를 완전히 없애는 것입니다: closure가 capture했을 데이터를 struct나 model의 property로 저장하고, 동작은 일반 method나 `callAsFunction`으로 노출하세요.

수정의 형태는 호출 지점에서 closure가 어떻게 구성되었는지에 따라 달라집니다.

동일한 FIX 패턴이 `FocusedValueKey`에도 적용됩니다: 아래 예시에서 `EnvironmentValues` / `@Environment`를 `FocusedValues` / `@FocusedValue`로 바꿔서 생각하면 됩니다.

아래 예시의 `@Observable` class에 붙은 `@MainActor`는 방어적인 기본 선택이며 유지해도 안전합니다. 해당 class가 (일반적인 경우처럼) view body에서만 읽고 변경된다면, 정확성을 잃지 않고 이 annotation을 생략할 수 있습니다.

### 수정이 아님: closure를 struct로 감싸기

closure를 property로 저장하는 struct는 closure를 직접 `@Entry`에 넣는 것과 동일한 문제를 가지고 있습니다 — struct 안의 closure는 여전히 비교를 무력화하고, body가 평가될 때마다 새로 할당된 closure를 가진 새 struct가 생성됩니다. SwiftUI는 매 쓰기마다 environment 값이 변경된 것으로 취급하고, 이를 읽는 모든 뷰가 무효화됩니다.

```swift
// AVOID: closure를 저장하는 struct는 실질적인 수정이 아닙니다.
// closure property는 여전히 비교할 수 없으므로, FormContainer의 body가
// 평가될 때마다 FormFields가 무효화됩니다.

struct SubmitAction {
    var perform: (String) -> Void
}

extension EnvironmentValues {
    @Entry var submitAction = SubmitAction(perform: { _ in })
}

struct FormContainer: View {
    var body: some View {
        FormFields()
            .environment(\.submitAction,
                SubmitAction(perform: { print("Submit: \($0)") }))
    }
}
```

대신 아래의 FIX 형태 중 하나를 사용하세요: closure가 capture했을 데이터를 저장 property로 저장하고, 동작을 일반 method나 `callAsFunction`으로 노출하세요 (closure property 없이).

### 수정이 아님: closure를 View의 저장 property로 끌어올리기

closure를 `View` struct의 `private let action: () -> Void = { ... }`로 끌어올리는 것도 수정이 되지 않습니다. SwiftUI는 `View` struct를 자유롭게 재인스턴스화(re-instantiate)하므로, struct가 생성될 때마다 `let` initializer가 다시 실행되어 매번 새로운 closure를 만들어냅니다. 포인터가 우연히 안정적이더라도, closure 비교 heuristic은 일부 최적화 수준에서 여전히 이를 다르다고 취급합니다. 이는 struct로 감싸는 것과 동일한 함정이며 — 결론도 동일하고 수정 방법도 동일합니다.

### 예제: capture가 없는 closure

```swift
// AVOID: Storing a closure in the environment.
// Closures can't be compared and all views that read this key will be invalidated even when the closure hasn't changed.

extension EnvironmentValues {
    @Entry var submitAction: (String) -> Void = { _ in }
}

struct FormContainer: View {
    var body: some View {
        FormFields()
            .environment(\.submitAction) { draft in
                print("Submit: \(draft)")
            }
    }
}

struct FormFields: View {
    // 이 뷰는 항상 무효화됩니다: SwiftUI는 submitAction 안의 closure를
    // 비교할 수 없으므로 매번 값이 변경되었다고 간주합니다.
    @Environment(\.submitAction) private var submit

    var body: some View {
        Button("Submit") { submit("hello") }
    }
}
```

### 수정: capture가 없는 closure

**옵션 A: `callAsFunction`을 가진 struct로 defunctionalize하기:**

```swift
// PREFER: callAsFunction을 가진 struct는 호출 지점의 편의성을 유지합니다.
// SwiftUI는 struct의 저장 property를 비교하여 불필요한
// 무효화를 건너뛸 수 있습니다
struct SubmitAction {
    func callAsFunction(_ draft: String) {
        print("Submit: \(draft)")
    }
}

extension EnvironmentValues {
    @Entry var submitAction = SubmitAction()
}

struct FormContainer: View {
    var body: some View {
        FormFields()
            .environment(\.submitAction, SubmitAction())
    }
}

struct FormFields: View {
    @Environment(\.submitAction) private var submit

    var body: some View {
        // callAsFunction 덕분에 closure 호출처럼 보입니다.
        Button("Submit") { submit("hello") }
    }
}
```

**옵션 B: @Observable model 사용하기:**

```swift
// PREFER: action을 보관하기 위해 @Observable model을 사용합니다.
// model 참조는 identity로 비교되므로 environment 값이
// 안정적이며 의존하는 뷰들이 잘못 무효화되지 않습니다.
@MainActor
@Observable
final class FormHandler {
    func submit(_ draft: String) {
        print("Submit: \(draft)")
    }
}

struct FormContainer: View {
    @State private var handler = FormHandler()

    var body: some View {
        FormFields()
            .environment(handler)
    }
}

struct FormFields: View {
    @Environment(FormHandler.self) private var handler

    var body: some View {
        Button("Submit") { handler.submit("hello") }
    }
}
```

**A와 B 중 선택하기:** action이 stateless하고 자체적으로 완결되어 있다면 옵션 A를 선호하세요. handler가 공유된 model의 다른 state와 협력해야 하거나, 관련된 기능을 위해 동일한 model을 재사용하고 싶다면 옵션 B를 선호하세요.

### 예제: capture가 있는 closure

```swift
// AVOID: Storing a closure in the environment.
// Closures can't be compared and all views that read this key will be invalidated even when the closure hasn't changed.

extension EnvironmentValues {
    @Entry var submitAction: () -> Void = {}
}

struct FormContainer: View {
    @State private var draft = "hello"

    var body: some View {
        FormFields()
            .environment(\.submitAction) {
                print("Submit: \(draft)")
            }
    }
}

struct FormFields: View {
    // 이 뷰는 항상 무효화됩니다: SwiftUI는 submitAction 안의 closure를
    // 비교할 수 없으므로 매번 값이 변경되었다고 간주합니다.
    @Environment(\.submitAction) private var submit

    var body: some View {
        Button("Submit") { submit() }
    }
}
```

### 수정: capture가 있는 closure

**옵션 A: `callAsFunction`을 가진 struct로 defunctionalize하고, capture를 struct의 property로 저장하기:**

```swift
// PREFER: callAsFunction을 가진 struct는 호출 지점의 편의성을 유지합니다.
// 이전에 capture했던 @State를 struct의 property로 저장합니다.

struct SubmitAction {
    var draft: String
    
    func callAsFunction() {
        print("Submit: \(draft)")
    }
}

extension EnvironmentValues {
    // `submitAction`이 여기서 optional인 이유는 draft 값이 설정되지 않으면
    // action이 유효하지 않기 때문입니다. 이 문제를 수정할 때 optionality는
    // 항상 context에 따라 고려되어야 합니다. 이 예제가 entry가 모든 경우에
    // *반드시* optional이어야 한다는 것을 의미하지는 않습니다.
    @Entry var submitAction: SubmitAction?
}

struct FormContainer: View {
    @State private var draft = "hello"

    var body: some View {
        FormFields()
            .environment(\.submitAction, SubmitAction(draft: draft))
    }
}

struct FormFields: View {
    @Environment(\.submitAction) private var submit

    var body: some View {
        // callAsFunction 덕분에 closure 호출처럼 보입니다.
        Button("Submit") { submit?() }
    }
}
```

**옵션 B: @Observable model을 사용하고, capture를 observable property로 model 안으로 옮기기:**

```swift
// PREFER: action을 보관하기 위해 @Observable model을 사용합니다.
// 이전에 뷰에서 capture했던 @State를 model로 옮깁니다.

@MainActor
@Observable
final class FormHandler {
    var draft: String = "hello"

    func submit() {
        print("Submit: \(draft)")
    }
}

struct FormContainer: View {
    @State private var handler = FormHandler()

    var body: some View {
        FormFields()
            .environment(handler)
    }
}

struct FormFields: View {
    @Environment(FormHandler.self) private var handler

    var body: some View {
        Button("Submit") { handler.submit() }
    }
}
```

**A와 B 중 선택하기:** capture된 state가 작고 뷰 로컬(view-local)이며 다른 뷰와 공유되지 않는다면 옵션 A를 선호하세요. state가 본래 뷰 바깥에 속하는 경우 — 여러 reader나 writer가 있거나, 외부에서 변경(mutation)되거나, subtree 전체에서 `@Observable`의 property 단위 tracking을 원하는 경우 — 옵션 B를 선호하세요.

### 예제: 범용 Handler를 사용하는 고급 사례

이 경우, closure인 `appearanceHandler`는 주입되는 뷰에 따라 완전히 다릅니다.

```swift
class MetricsTracker {
    func trackForm(name: String) { /* ... */ }
    func trackCart(itemCount: Int) { /* ... */ }
}

extension EnvironmentValues {
    @Entry var appearanceHandler: () -> Void = {}
}

struct MainView: View {
    @State private var tracker = MetricsTracker()
    @State private var formName = "Form1"
    @State private var cartItemCount = 0
    
    var body: some View {
        VStack {
            FormFields(name: formName)
                .environment(\.appearanceHandler) {
                    tracker.trackForm(name: formName)
                }
            ShoppingCart(itemCount: cartItemCount)
                .environment(\.appearanceHandler) {
                    tracker.trackCart(itemCount: cartItemCount)
                }
        }
    }
}

struct FormFields: View {
    // 이 뷰는 항상 무효화됩니다: SwiftUI는 appearanceHandler 안의 closure를
    // 비교할 수 없으므로 매번 값이 변경되었다고 간주합니다.
    @Environment(\.appearanceHandler) private var appearanceHandler
    
    let name: String
    
    var body: some View {
        Text(name)
        FormContent()
            .onAppear {
                appearanceHandler()
            }
    }
}

struct ShoppingCart: View {
    let itemCount: Int
    @Environment(\.appearanceHandler) private var appearanceHandler
    
    var body: some View {
        Text("Item Count: \(itemCount)")
        ItemList()
            .onAppear {
                appearanceHandler()
            }
    }
}
```

### 수정: 범용 Handler를 사용하는 고급 사례

**옵션 A: 공유 protocol을 준수하는 개별 struct로 defunctionalize하기**
 
context에 따라 완전히 다른 구현을 가질 수 있는 closure를 저장하는 경우에는, closure를 protocol을 준수하는 handler로 일반화하고, capture를 캡슐화하는 구체적인(concrete) 준수 구현을 선언하세요.

@Entry의 타입은 protocol이어야 하며, protocol을 준수하는 concrete 타입들이 각 뷰의 environment에 주입됩니다.

옵션 A 안에서는 호출 지점의 가독성에 따라 `callAsFunction`과 이름이 있는 method 중 하나를 선택하세요. 기존 closure 호출 지점을 대체하면서 `handler(x)`의 편의성을 유지하고 싶다면 `callAsFunction`을 사용하세요. protocol이 특정하고 이름 붙일 수 있는 동작을 나타낸다면 이름이 있는 method(예: `handleURL(_:)`, `onAppear()`, `submit(_:)`)를 사용하세요 — 주변 context만으로 동작이 명확하지 않을 때는 `handler.handleURL(url)`이 `handler(url)`보다 더 읽기 좋습니다.

```swift
class MetricsTracker {
    func trackForm(name: String) { /* ... */ }
    func trackCart(itemCount: Int) { /* ... */ }
}

protocol AppearanceHandler {
    func callAsFunction()
}

extension EnvironmentValues {
    @Entry var appearanceHandler: AppearanceHandler?
}

struct FormAppearanceHandler: AppearanceHandler {
    let tracker: MetricsTracker
    let name: String
    
    func callAsFunction() {
        tracker.trackForm(name: name)
    }
}

struct CartAppearanceHandler: AppearanceHandler {
    let tracker: MetricsTracker
    let itemCount: Int
    
    func callAsFunction() {
        tracker.trackCart(itemCount: itemCount)
    }
}

struct MainView: View {
    @State private var tracker = MetricsTracker()
    @State private var formName = "Form1"
    @State private var cartItemCount = 0
    
    var body: some View {
        VStack {
            FormFields(name: formName)
                .environment(\.appearanceHandler,
                    FormAppearanceHandler(tracker: tracker, name: formName))
            ShoppingCart(itemCount: cartItemCount)
                .environment(\.appearanceHandler,
                    CartAppearanceHandler(tracker: tracker, itemCount: cartItemCount))
        }
    }
}

struct FormFields: View {
    @Environment(\.appearanceHandler) private var appearanceHandler
    
    let name: String
    
    var body: some View {
        Text(name)
        FormContent()
            .onAppear {
                appearanceHandler?()
            }
    }
}

struct ShoppingCart: View {
    let itemCount: Int
    @Environment(\.appearanceHandler) private var appearanceHandler
    
    var body: some View {
        Text("Item Count: \(itemCount)")
        ItemList()
            .onAppear {
                appearanceHandler?()
            }
    }
}
```

**옵션 B: 관련된 state와 로직을 하나의 공유 class로 통합하기**
 
많은 경우, 데이터를 모델링하는 방식을 다시 생각해보면 지나치게 복잡하고 open-ended한 closure 기반 구현이 필요 없어질 수 있습니다. 관련된 property들을 하나의 통합된 source of truth로 묶으면, SwiftUI가 뷰를 비교하는 방식과 더 잘 맞도록 불필요하게 generic하게 만드는 것을 피하기 쉬워집니다.

```swift
class MetricsTracker {
    func trackForm(name: String) { /* ... */ }
    func trackCart(itemCount: Int) { /* ... */ }
}

@MainActor
@Observable
final class Model {
    private let tracker = MetricsTracker()
    
    var formName: String = "Form1"
    var cartItemCount: Int = 0
    
    func trackFormAppearance() {
        tracker.trackForm(name: formName)
    }
    
    func trackCartAppearance() {
        tracker.trackCart(itemCount: cartItemCount)
    }
}

struct MainView: View {
    @State private var model = Model()
    
    var body: some View {
        VStack {
            FormFields()
            ShoppingCart()
        }
        .environment(model)
    }
}

struct FormFields: View {
    @Environment(Model.self) private var model
    
    var body: some View {
        Text(model.formName)
        FormContent()
            .onAppear {
                model.trackFormAppearance()
            }
    }
}

struct ShoppingCart: View {
    @Environment(Model.self) private var model
    
    var body: some View {
        Text("Item Count: \(model.cartItemCount)")
        ItemList()
            .onAppear {
                model.trackCartAppearance()
            }
    }
}
```

**A와 B 중 선택하기:** handler의 종류가 서로 독립적이고 그 집합이 open되어 있는 경우 — 예를 들어 third party가 새로운 handler를 추가할 수 있는 경우 — 옵션 A(protocol + concrete handler)를 선호하세요. handler들이 (여기서의 공통 `tracker`처럼) state를 공유하고 그 집합이 closed된 경우에는 옵션 B(통합 model)를 선호하세요. existential을 피할 수 있고 대체로 코드도 줄어듭니다.

## 빠르게 갱신되는 Environment 값

environment key에 대한 모든 업데이트는, 영향을 받는 subtree 안에서 environment로부터 (업데이트되지 않는 key를 포함해) ANY KEY를 읽는 모든 뷰(EVERY VIEW)에 비용을 발생시킵니다. SwiftUI는 각 뷰의 값이 변경되었는지 확인해야 하기 때문입니다. 높은 빈도로 변경되는 값(scroll offset, window size, drag position)은 environment에 넣지 마세요.

client 코드를 리뷰할 때 주의해야 할 흔한 high-frequency 소스들입니다 — 다음 중 어떤 것이든 `@Entry` 값이나 `.environment(\.key, value)` modifier로 흘러들어간다면, 이 anti-pattern으로 취급하세요:

- `scrollPosition` / `onScrollGeometryChange`에서 오는 scroll offset
- `GeometryReader` / `onGeometryChange`에서 오는 window 또는 container size
- `DragGesture().onChanged`에서 오는 drag translation 또는 현재 위치
- 프레임 단위 animation progress (`TimelineView`, `CADisplayLink` 기반 값)
- Timer 기반 state (`.timer` publisher, `Timer`)
- Pointer / cursor / hover 위치

대신, 자주 업데이트되는 값은 `@Observable` model에 저장하세요. `@Observable`은 property 단위로 접근을 tracking하므로, 특정 property를 읽는 뷰만 해당 값이 변경될 때 무효화됩니다. 정밀한 point 값보다는 뭉뚱그려진(coarsened) boolean threshold를 선호하세요: `isWide`를 읽는 뷰는 resize의 모든 pixel마다가 아니라 경계를 넘을 때만 무효화됩니다.

```swift
// AVOID: 빠르게 변하는 CGFloat를 environment로 전파하는 경우.
// window resize의 모든 pixel마다 subtree 안에서 environment를
// 읽는 모든 뷰에 비교 비용이 발생합니다.
extension EnvironmentValues {
    @Entry var windowWidth: CGFloat = 0
}

struct RootView: View {
    var body: some View {
        GeometryReader { proxy in
            ContentView()
                .environment(\.windowWidth, proxy.size.width)
        }
    }
}

struct ContentView: View {
    @Environment(\.windowWidth) private var width

    var body: some View {
        Text(width > 600 ? "Wide layout" : "Compact layout")
    }
}
```

```swift
// PREFER: geometry를 @Observable model에 보관하고 뭉뚱그려진(coarsened)
// threshold를 노출합니다. 뷰는 의미 있는 경계를 넘을 때만 무효화되며,
// 모든 pixel마다 무효화되지는 않습니다.
@MainActor
@Observable
final class ViewportModel {
    var width: CGFloat = 0 {
        didSet { isWide = width > 600 }
    }

    private(set) var isWide: Bool = false
}

struct RootView: View {
    @State private var viewport = ViewportModel()

    var body: some View {
        ContentView()
            .environment(viewport)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                viewport.width = newWidth
            }
    }
}

struct ContentView: View {
    @Environment(ViewportModel.self) private var viewport

    var body: some View {
        // isWide가 뒤바뀔 때만 무효화되며, 모든 pixel마다 무효화되지는 않습니다.
        Text(viewport.isWide ? "Wide layout" : "Compact layout")
    }
}
```

동일한 형태가 리스트에서 항목 단위(per-item) coarsening에도 적용됩니다. 각 row의 외형이 scroll position에 의존할 때, 단순한 수정(offset을 `@Observable` model에 저장하고 row가 이를 그대로 읽게 하는 것)은 실제로 무효화를 줄이지 못합니다. 각 row는 여전히 `offset`에 의존하므로, SwiftUI는 매 프레임마다 보이는 모든 row를 무효화합니다 — 단지 environment 대신 model을 통해 이루어질 뿐입니다. 해야 할 작업은 **model 쪽**에 있습니다: 각 item에 자신만의 `@Observable` object를 부여하고, 그 property가 오직 그 item의 파생된 state만 tracking하게 하세요. Observation은 property 단위로 tracking하므로, `itemModel.isVisible`을 읽는 row는 *그 특정 property*가 변경될 때만 무효화되며, sibling의 property가 변경될 때는 무효화되지 않습니다. 이렇게 하면 진정한 항목 단위 isolation을 달성합니다: 리스트 크기나 scroll 속도와 관계없이 각 row는 최대 두 번만(진입 시 한 번, 이탈 시 한 번) 무효화됩니다.

```swift
// AVOID: @Observable로 옮겼지만 row가 여전히 raw offset을 읽는 경우.
// `FeedItemView`는 이전과 마찬가지로 모든 scroll 프레임마다 무효화됩니다 —
// 비용이 environment 전파에서 observation tracking으로 옮겨갔을 뿐,
// 프레임당 body 무효화 횟수는 그대로입니다.
@MainActor
@Observable
final class FeedModel {
    var offset: CGFloat = 0
}

struct FeedItemView: View {
    let index: Int
    @Environment(FeedModel.self) private var feed

    var body: some View {
        Text("Item \(index)")
            .opacity(feed.offset > CGFloat(index * -50) ? 1 : 0.3)  // raw offset을 읽음
    }
}
```

```swift
// PREFER: 항목 단위 @Observable model. 각 row는 자신의
// `isVisible` property만 observe하므로, 다른 항목들이 몇 개나
// visibility를 바꾸든 상관없이 최대 두 번만(진입 + 이탈) 무효화됩니다.
@MainActor
@Observable
final class FeedModel {
    private(set) var items: [ItemModel] = []

    func updateOffset(_ offset: CGFloat) {
        let visible = Set(computeVisibleIndices(for: offset))
        for (i, item) in items.enumerated() {
            item.isVisible = visible.contains(i)
        }
    }

    private func computeVisibleIndices(for offset: CGFloat) -> [Int] {
        // ... offset, item height, viewport height로부터 보이는 index를 계산합니다.
    }
}

@MainActor
@Observable
final class ItemModel {
    let index: Int
    var isVisible = false
    init(index: Int) { self.index = index }
}

struct FeedItemView: View {
    @Environment(ItemModel.self) private var item

    var body: some View {
        Text("Item \(item.index)")
            .opacity(item.isVisible ? 1 : 0.3)
    }
}

// Parent wiring: row마다 다른 ItemModel을 주입합니다.
struct FeedView: View {
    @State private var feedModel = FeedModel()

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(feedModel.items) { item in
                    FeedItemView()
                        .environment(item)
                }
            }
        }
    }
}
```

흔히 사용하는 중간 단계는 보이는 index들의 공유 `Set<Int>`를 model에 저장하고 각 row가 `.contains(index)`를 호출하게 하는 것입니다. 이는 경계를 넘을 때만(모든 프레임이 아니라) 발생하므로, raw-offset 방식보다는 실질적인 개선입니다. 하지만 Observation은 property 단위로 tracking하기 때문에, set을 변경(mutate)하면 실제로 visibility가 바뀐 1~2개의 row뿐 아니라 그 set을 읽은 *모든* row가 무효화됩니다. 위의 항목 단위 model은 visibility 변경당 진정한 O(1) 무효화를 달성합니다.

핵심이 되는 질문은 *"뷰가 실제로 읽는 값의 granularity(단위)는 무엇인가?"*이며, "그 값이 `@Observable`에 담겨 있는가?"가 아닙니다. `@Observable`은 property 단위 tracking을 위한 전제 조건일 뿐이며, 프레임당 body 무효화 횟수를 줄이는 것은 coarsening입니다.

framework의 대안에 대한 참고: scroll position에 의해서만 좌우되는 순수한 visual effect(viewport 안의 위치에 따른 opacity, scale, rotation)의 경우, `scrollTransition`과 `visualEffect(in:)`은 프레임당 작업을 renderer로 넘기고 body 재평가를 완전히 건너뜁니다. row의 visual styling 외에는 아무것도 scroll position에 의존하지 않을 때 이것이 올바른 도구입니다. scroll에서 파생된 state가 *렌더링이 아닌* 로직(model 업데이트, prefetch, network 호출, sibling-view state)을 구동해야 할 때는 이들이 `@Observable` + coarsening pattern을 대체하지 못합니다. 확신이 서지 않을 때: 어차피 로직을 구동하기 위해 `@State` / `@Environment`로 값을 전파했을 것이라면 coarsened model을 사용하고, view modifier만 필요하다면 framework의 modifier를 사용하세요.

## 불안정한 Environment Default 값

environment key의 `defaultValue`가 computed property로 선언되어 있으면, 그 값으로 폴백하는 모든 읽기마다 다시 평가됩니다. 이런 상황에 흔히 부딪히는 두 가지 경우가 있습니다:

- `@Entry`는 항상 default 표현식을 computed getter로 감쌉니다 (concurrency 안전성을 위해서 — default는 `Sendable`일 필요가 없습니다). 그래서 `@Entry var model = Model()`은 폴백 읽기마다 `Model()`을 다시 할당합니다.
- computed default를 가진 수동 `EnvironmentKey` — `static var defaultValue: T { Model() }` — 도 같은 이유로 접근마다 표현식을 다시 실행합니다.

두 형태 모두 **모든 reference type**에 문제가 됩니다(각 호출이 새 heap instance를 할당하므로 reference equality가 실패합니다). 더 일반적으로는 `Date()`, `UUID()`, 난수처럼 value type이라도 **호출마다 다른 결과를 반환할 수 있는 모든 default 표현식**에 문제가 됩니다.

ancestor가 *어떤* environment key에든 쓰기를 하면 descendant들은 자신의 값을 다시 읽습니다. 불안정한 default로 폴백하는 reader는 이전과 다른 값을 받게 되어 무효화되며, 이는 관련된 것이 아무것도 바뀌지 않았음에도 발생합니다.

`Equatable`은 빠른 경로일 뿐 필수 조건이 아닙니다. `Equatable` 준수가 없어도 SwiftUI는 필드가 일치하는 두 instance를 같다고 취급합니다. 이는 각 저장 property가 호출마다 동일한 값으로 결정되는 한 value-type default가 안정적이라는 뜻입니다 — enum case, `nil`, 고정 리터럴, 그리고 호출 간에 동일한 instance를 가리키는 참조는 모두 이 조건을 만족합니다. 안정성을 깨뜨리는 것은 호출마다 달라지는 저장 property입니다: 새로운 reference 할당(`struct Foo { let model = Model() }` — 각 `Foo()`가 새 `Model`을 생성하므로 두 `Foo` instance의 `model` 필드는 서로 다른 포인터입니다) 이나 런타임에 캡처된 값(`Date()`, `UUID()`)이 그렇습니다. 실제로 적용해야 할 기준은 "이 표현식이 호출마다 다른 결과를 반환하는가"이며, "이 타입이 `Equatable`을 준수하는가"가 아닙니다. (closure는 이 섹션 앞부분의 별도 closures-in-env 규칙이 적용됩니다 — 그 규칙은 default든 쓰기 지점이든 상관없이 closure를 전적으로 금지합니다.)

안정적인 default는 이 문제를 겪지 않습니다: 고정 리터럴, `nil` optional default, 또는 `let`으로 뒷받침되는 값(`static let`으로 뒷받침되는 `@Entry`이든, `static let defaultValue`를 가진 수동 key이든)은 모두 매 읽기마다 동일한 값을 반환합니다.

무효화는 reader가 실제로 default로 폴백할 때만 발생합니다. 모든 reader가 `.environment(\.key, …)`를 통해 상위(upstream)에서 주입된 값을 가지고 있다면, 불안정한 default는 잠재적(latent)인 상태입니다 — 이를 수정하는 것은 여전히 올바른 일이지만(향후 유지보수자가 upstream 주입 없이 reader를 추가하거나 기존 주입을 제거하면 이 문제가 조용히 드러날 것입니다), 이는 현재 비용을 회복하는 것이 아니라 regression guard입니다. 리뷰할 때는 이 둘을 구분하세요: live issue는 reader가 지금 폴백하며 무효화 비용을 지불하고 있는 경우이고, latent한 경우는 현재 모든 reader가 upstream 주입으로 커버되고 있는 경우입니다. 수정 방식은 어느 쪽이든 동일하지만, 그것을 다루는 방식 — 긴급도, 우선순위, PR에서 어떻게 설명할지 — 은 다릅니다.

### 예제: 불안정한 default를 가진 @Entry

```swift
@Observable class Model {}

extension EnvironmentValues {
    @Entry var model = Model()
    @Entry var counter = 0
}

struct ContentView: View {
    @State private var counter = 0

    var body: some View {
        VStack {
            Button("++") { counter += 1 }
            RowContent()
        }
        .environment(\.counter, counter)
    }
}

struct RowContent: View {
    @Environment(\.model) private var model

    var body: some View {
        // "++"를 누를 때마다 이 뷰가 무효화되는 이유는 `model`의 default
        // getter가 매 읽기마다 새로운 `Model()`을 생성하기 때문입니다.
        let _ = Self._printChanges()
        Text("Row Content")
    }
}
```

value-type이면서 다시 평가되는 default도 동일한 문제를 가집니다 — `@Entry var lastRefreshed = Date()`는 매 읽기마다 다른 timestamp를 만들어내며, 같은 이유로 관련 없는 env 업데이트가 있을 때마다 reader가 무효화됩니다.

### 수정이 아님: default 타입을 Equatable로 준수시키기

불안정한 타입을 사소하거나 degenerate한 `==`로 `Equatable`을 준수하게 만들면 무효화 증상은 억제할 수 있지만, default 표현식은 여전히 매 읽기마다 다시 평가됩니다. 매번 새 instance가 할당되고, initializer의 어떤 side effect든 여전히 발생하며, default로 폴백하는 두 reader는 서로 다른 instance를 받게 됩니다 — 그래서 한쪽의 observation 변경이 다른 쪽으로 전파되지 않습니다.

```swift
// AVOID: Equatable은 근본적인 재평가 문제를 고치지 않고 무효화 증상만 가립니다.
@Observable final class Model: Equatable {
    init() { print("init") }  // 관련 없는 env 쓰기가 있을 때마다 여전히 실행됩니다
    var id = 0
    static func == (lhs: Model, rhs: Model) -> Bool { lhs.id == rhs.id }
}

extension EnvironmentValues {
    @Entry var model = Model()
}
```

아래의 옵션 A, B, C를 사용하여 default 자체를 안정적으로 만드세요.

### 수정이 아님: 이미 안정적인 default를 방어적으로 memoization하기

default가 위의 실제 기준을 만족한다면 — 모든 필드가 호출 간에 동일한 값으로 결정된다면(리터럴, `nil`, module-level `let` 참조, module-level `let`을 capture하는 struct 필드 포함) — 그대로 두세요. `static let` 뒷받침, `Optional` 감싸기, 혹은 "명확성을 위한" "regression guard" 재작성을 추천하지 마세요. "안전을 위해" `Equatable` 준수를 추가하는 것도 추천하지 마세요 — default는 이미 그것 없이도 매 호출마다 byte-equal합니다(`Equatable`은 빠른 경로일 뿐 필수 조건이 아닙니다), 그리고 앞의 "수정이 아님: default 타입을 Equatable로 준수시키기" 섹션에서 왜 `Equatable`이 불안정한 default를 고치지 못하는지 이미 설명했습니다. 방어적인 refactor는 존재하지 않는 버그를 암시하는 noise이며 동작을 바꾸지 않으면서 indirection만 추가합니다. 옵션 A/B/C는 실제 기준이 실패할 때만 적용하세요.

Reviewer들이 흔히 잘못 짚는 두 가지 형태가 있습니다 — 이를 구체적으로 짚어내고 그대로 두세요:

- **struct 필드가 reference를 담고 있지만, 그 reference가 안정적인 소스에서 온 경우.** struct 안에 class 타입이 있다는 것 자체는 red flag가 *아닙니다*. 중요한 것은 그 reference의 소스가 안정적인지입니다. module-level `let`, `static let`, 또는 caller가 가지고 있는 dependency-injected instance는 모두 default 표현식이 호출될 때마다 동일한 포인터를 만들어냅니다.
- **`@Entry` 안에서 deterministic한 argument 값으로 인라인으로 생성된 struct.** associated value가 없는 enum case, `nil`, 리터럴, 그리고 위의 안정적인 reference들 모두 이 조건을 만족합니다. struct 자체가 `Equatable`일 필요는 없습니다 — SwiftUI는 필드 단위로 비교합니다.

```swift
// FINE: 안정적인 default입니다 — 이를 "수정"하지 마세요.
// `sharedLogger`는 module-level `let`이므로,
// `RequestContext(logger: sharedLogger, retryBudget: 3)`을 호출할 때마다
// 동일한 `Logger` 포인터를 capture합니다; `retryBudget: 3`은 리터럴입니다.
// default로 평가된 두 `RequestContext` instance는 `RequestContext`가
// `Equatable`을 준수하는지와 관계없이 byte-equal합니다.

final class Logger { func log(_ message: String) {} }

struct RequestContext {
    let logger: Logger
    let retryBudget: Int
}

private let sharedLogger = Logger()

extension EnvironmentValues {
    @Entry var requestContext = RequestContext(logger: sharedLogger, retryBudget: 3)
}
```

```swift
// FINE: 안정적인 default입니다 — 이를 "수정"하지 마세요.
// `.standard`는 associated value가 없는 enum case이고 `PresentationHandler?`의
// `nil`은 상수입니다. 두 번의 `ViewContext(mode: .standard, presentation: nil)`
// 호출은 byte-equal한 instance를 만들어냅니다. SwiftUI가 이를 중복 제거하는 데
// `Equatable` 준수가 필요하지 않습니다.

protocol PresentationHandler { func dismiss() }

struct ViewContext {
    enum Mode { case standard, compact, expanded }
    let mode: Mode
    let presentation: PresentationHandler?
}

extension EnvironmentValues {
    @Entry var viewContext = ViewContext(mode: .standard, presentation: nil)
}
```

불안정한 형태와 대조해보세요 — struct의 골격은 같지만, default 표현식이 호출마다 *새로운* reference를 생성합니다:

```swift
// AVOID: 불안정한 default입니다. `RequestContext()`는 폴백 읽기마다
// `logger = Logger()` default initializer를 실행하므로, default로 평가된
// 두 instance는 서로 다른 `logger` 포인터를 가집니다.

struct RequestContext {
    let logger = Logger()      // init마다 새로 할당됨
    let retryBudget = 3
}

extension EnvironmentValues {
    @Entry var requestContext = RequestContext()
}
```

핵심이 되는 질문은 언제나 *"이 default 표현식이 호출마다 다른 결과를 반환하는가?"*이며, "이 struct가 class를 포함하는가?"도 아니고 "이 타입이 `Equatable`인가?"도 아닙니다.

### 수정: 불안정한 environment default 값

이 옵션들은 reference-type인 경우와 새 값을 만들어내는 경우(`Date()`, `UUID()` 등) 모두에 적용됩니다 — 필요에 따라 불안정한 표현식을 대체하세요.

**옵션 A: 안정적인 property로 default를 뒷받침하기**

`@Entry` 선언 옆에 `static let`을 선언하고 initializer에서 이를 참조하세요. macro는 여전히 표현식을 computed getter로 감싸지만, 이제 표현식은 매 읽기마다 동일한 memoized 값으로 결정됩니다.

```swift
@Observable class Model {}

extension EnvironmentValues {
    @Entry var model = _defaultModel
    private static let _defaultModel = Model()
    @Entry var counter = 0
}

struct ContentView: View {
    @State private var counter = 0

    var body: some View {
        VStack {
            Button("++") { counter += 1 }
            RowContent()
        }
        .environment(\.counter, counter)
    }
}

struct RowContent: View {
    @Environment(\.model) private var model

    var body: some View {
        // `_defaultModel`은 `static let`이므로, 매 읽기마다 동일한
        // instance를 반환합니다. `\.counter`를 업데이트해도 더 이상
        // 무효화되지 않습니다.
        let _ = Self._printChanges()
        Text("Row Content")
    }
}
```

**옵션 B: `EnvironmentKey`를 직접 선언하기**

이 key에는 `@Entry`를 사용하지 말고 준수를 직접 작성하세요. `static let defaultValue`를 사용하세요 — 한 번 평가되어 memoize되는 저장 상수입니다. `static var defaultValue: T { … }`는 사용하지 마세요; computed property는 매 읽기마다 다시 평가되어 macro가 가진 것과 동일한 문제를 겪습니다.

```swift
private struct ModelKey: EnvironmentKey {
    static let defaultValue = Model()
}

extension EnvironmentValues {
    var model: Model {
        get { self[ModelKey.self] }
        set { self[ModelKey.self] = newValue }
    }
}
```

`ContentView`와 `RowContent`는 옵션 A와 동일하게 유지됩니다.

**옵션 C: `nil` default를 가진 optional 사용하기**

`Optional` 타입이고 initializer가 없는 `@Entry`는 `nil`로 default됩니다 — 이는 상수입니다. caller는 optional을 처리해야 하지만, default는 모든 읽기에서 안정적입니다.

```swift
extension EnvironmentValues {
    @Entry var model: Model?
}
```

`ContentView`와 `RowContent`는 옵션 A와 동일하게 유지되며, `model`은 이제 호출 지점에서 optional입니다.

**진단 — reader 안의 sentinel 값은 옵션 C를 시사합니다.** 불안정한 default를 지적할 때, reader가 그 값을 가지고 무엇을 하는지 살펴보세요. reader가 `value.id.isEmpty`, `value.count == 0`, `value == .none`, `value === sentinelInstance`와 같은 방식으로 "empty" 또는 "default" state를 체크하거나, `@Entry`가 만들어내는 동일한 default와 비교한다면 — 그 체크는 사실 위장된 absence test입니다. reader는 "여기에 값이 없다"는 것을 magic value로 인코딩하고 있는 것입니다. 그 의도를 정직하게 표현하는 방법은 실제 instance에 sentinel 필드를 두는 것이 아니라 `Optional` + `if let`입니다. 이런 경우 옵션 A나 B를 선택하면 무효화는 고쳐지지만 더 나쁜 설계가 남습니다: sentinel이 살아남고, 모든 caller가 그 magic value를 알아야 하며, 체크를 빠뜨렸을 때 타입 시스템이 알려주지 못합니다. 옵션 C를 선택하고 reader가 optional로 분기하도록 업데이트하세요.

```swift
// Before: 불안정한 default, reader 안의 sentinel-as-absence.
@Observable final class EditingSession {
    var documentId: String
    init(documentId: String) { self.documentId = documentId }
}

extension EnvironmentValues {
    @Entry var editingSession = EditingSession(documentId: "")  // 불안정 + sentinel default
}

struct DocumentArea: View {
    @Environment(\.editingSession) private var session
    var body: some View {
        if session.documentId.isEmpty {            // sentinel을 부재 표시로 사용
            Text("No document open")
        } else {
            Text("Editing: \(session.documentId)")
        }
    }
}

// After: 옵션 C — absence가 Optional이 되고, sentinel이 사라집니다.
extension EnvironmentValues {
    @Entry var editingSession: EditingSession?
}

struct DocumentArea: View {
    @Environment(\.editingSession) private var session
    var body: some View {
        if let session {                            // 정직한 absence 테스트
            Text("Editing: \(session.documentId)")
        } else {
            Text("No document open")
        }
    }
}
```

**A, B, C 중 선택하기:** 먼저 위의 진단을 실행하세요. reader에 sentinel 체크가 있다면 **옵션 C**를 선택하고 reader를 `if let`을 사용하도록 다시 작성하세요 — 불안정한 default를 고치는 것과 sentinel 설계를 제거하는 것을 동시에 해결합니다. reader가 항상 그 값을 실제 instance로 사용한다면(absence 체크도 없고 magic default와의 비교도 없다면), default 자체가 의미상 실제 값입니다 — `@Entry` 문법을 유지하고 싶고 default 표현식이 짧다면 **옵션 A**를, 수동 `EnvironmentKey` pattern이 더 명확하게 읽힌다면(일반적으로 default가 복잡하거나, 여러 곳에서 사용되거나, `@Entry` 선언에 인라인으로 두기보다 key 타입에 두는 것이 더 나을 때) **옵션 B**를 선택하세요. A/B/C를 동등한 선택지로 나열하고 결정을 읽는 사람에게 맡기지 마세요 — reader들이 실제로 무엇을 하는지에 근거해서 판단하세요.

## 사용하지 않는 @Environment 읽기

뷰에 `@Environment(\.someKey)`를 선언하면, 그 뷰의 `body`가 wrapped 값을 전혀 참조하지 않더라도 `\.someKey`의 변경에 그 뷰가 subscribe됩니다. `\.someKey`가 변경되면 SwiftUI는 그 뷰를 재평가합니다 — body가 그 key에 의존하지 않는다면, 그 재평가는 순전한 오버헤드입니다. `@FocusedValue`에도 동일하게 적용됩니다.

`@Observable` model과 함께 사용하는 타입 기반 형태인 `@Environment(Model.self)`는 다르게 동작합니다. Observation은 **property** 단위로 읽기를 tracking하므로, body에서 `model`의 어떤 property도 읽지 않고 `@Environment(Model.self) var model`을 선언하면 property 단위 의존성이 등록되지 않습니다; `model`의 property가 바뀌어도 그 뷰는 재평가되지 않습니다. 사용하지 않는 타입 형태 선언은 해당 model의 env entry가 불안정한 default를 가지고 있지 않다면 실제 무효화 비용을 발생시키지 않습니다(그런 경우라면 앞서 다룬 unstable-default 섹션이 적용되며, 읽기 지점의 문제가 아닙니다).

리뷰할 때는 각 뷰의 `@Environment` / `@FocusedValue` 선언을 하나씩 살펴보고 wrapped property가 body에서 참조되는지 확인하세요(직접, `_propertyName` projected form을 통해, 또는 body가 호출하는 computed property나 method를 통해서). 아무것도 참조하지 않는다면 그 선언을 삭제하세요:

- **KeyPath 형태 (`@Environment(\.key)`, `@FocusedValue(\.key)`)**: 제거는 실질적인 성능 수정입니다. `\.key`에 대한 모든 ancestor의 쓰기가 현재 그 뷰를 무효화하고 있습니다.
- **타입 형태 (`@Environment(Model.self)`)**: 제거는 dead-code 정리입니다. 근본이 되는 env가 불안정한 default를 가지고 있지 않다면 실제 무효화 비용은 없습니다.

```swift
// AVOID: 선언되었지만 body에서 전혀 읽히지 않음
struct BadgeView: View {
    @Environment(\.theme) private var theme   // 아래에서 전혀 참조되지 않음
    let label: String

    var body: some View {
        Text(label)
    }
}
```

```swift
// PREFER: 사용하지 않는 subscription을 제거
struct BadgeView: View {
    let label: String

    var body: some View {
        Text(label)
    }
}
```
