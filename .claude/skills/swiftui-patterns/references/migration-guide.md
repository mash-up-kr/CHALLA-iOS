# 마이그레이션 체크리스트

레거시 SwiftUI 코드를 iOS 17+로 업데이트할 때:

- [ ] `ObservableObject`를 `@Observable`로 교체
- [ ] 모든 `@Published`를 제거 (일반 속성은 자동으로 게시됩니다)
- [ ] `@StateObject`를 `@State`로 교체
- [ ] `@ObservedObject`를 `@Bindable`로 교체
- [ ] `environmentObject(_:)`를 `environment(_:)`로 교체
- [ ] `@EnvironmentObject`를 `@Environment(Type.self)`로 교체
- [ ] `onChange(of:perform:)`를 `onChange(of:initial:_:)`로 업데이트
- [ ] `.onAppear { Task {} }`를 `.task`로 교체

## 이전 및 이후 예제

### 이전 (iOS 16)
```swift
class UserProfileModel: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
}

struct ProfileView: View {
    @StateObject private var model = UserProfileModel()

    var body: some View {
        TextField("Name", text: $model.name)
            .onAppear {
                Task {
                    await model.load()
                }
            }
    }
}
```

### 이후 (iOS 17+)
```swift
@Observable
class UserProfileModel {
    var name: String = ""
    var email: String = ""
}

struct ProfileView: View {
    @State private var model = UserProfileModel()

    var body: some View {
        TextField("Name", text: $model.name)
            .task {
                await model.load()
            }
    }
}
```
