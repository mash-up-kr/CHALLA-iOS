# @Observable — ObservableObject가 아님

**iOS 17+ 패턴**

## ✅ 최신 패턴
```swift
import Observation

@Observable
class UserProfileModel {
    var name: String = ""
    var email: String = ""
    var isLoading: Bool = false

    func save() async {
        isLoading = true
        // Save logic
        isLoading = false
    }
}

// In SwiftUI view
struct ProfileView: View {
    let model: UserProfileModel

    var body: some View {
        TextField("Name", text: $model.name)
    }
}
```

## ❌ 지원 종료된 패턴
```swift
// NEVER use ObservableObject for new code
class UserProfileModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
}
```

## 왜 @Observable을 사용해야 하는가?

**이점:**
- **더 적은 보일러플레이트** — `@Published`가 필요 없음
- **더 나은 성능** — 세밀한(fine-grained) 관찰 방식 (접근한 프로퍼티만 추적)
- **타입 안전한 environment** — `@EnvironmentObject` 대신 `@Environment(Type.self)` 사용
- **더 단순한 바인딩** — `@ObservedObject` 대신 `@Bindable` 사용

**요구 사항:** iOS 17.0+ / macOS 14.0+
