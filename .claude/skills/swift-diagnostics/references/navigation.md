# Navigation 진단

NavigationStack 문제에 대한 체계적인 디버깅입니다. navigation 문제의 85%는 path state 관리, view identity, 또는 destination 배치에서 비롯됩니다.

## 진단 결정 테이블

| 관찰 내용 | 진단 | 다음 단계 |
|-------------|-----------|-----------|
| tap해도 onChange가 전혀 발생하지 않음 | NavigationLink가 NavigationStack 내부에 없음 | view hierarchy 확인 |
| onChange는 발생하지만 view가 push되지 않음 | navigationDestination을 찾을 수 없음 | destination 배치 확인 |
| push된 후 즉시 pop됨 | view identity 문제 또는 path reset | @State 위치 확인 |
| path가 예기치 않게 변경됨 | 외부 코드가 path를 수정 | 원인을 찾기 위해 로깅 추가 |
| deep link가 navigate하지 않음 | timing 문제 또는 잘못된 thread | MainActor isolation 확인 |
| tab 전환 시 state 손실 | NavigationStack이 tab 간에 공유됨 | tab마다 별도의 stack 사용 |

## 필수 1차 확인 항목

코드를 변경하기 전에 다음을 실행하세요:

```swift
// 1. Add NavigationPath logging
NavigationStack(path: $path) {
    RootView()
        .onChange(of: path.count) { oldCount, newCount in
            print("Path changed: \(oldCount) -> \(newCount)")
        }
}

// 2. Verify navigationDestination is evaluated
.navigationDestination(for: Recipe.self) { recipe in
    let _ = print("Destination for: \(recipe.name)")
    RecipeDetail(recipe: recipe)
}

// 3. Test minimal case in isolation
NavigationStack {
    NavigationLink("Test", value: "test")
        .navigationDestination(for: String.self) { str in
            Text("Pushed: \(str)")
        }
}
```

## 결정 트리

```
Navigation problem?
|-- Link tap does nothing?
|   |-- onChange fires? -> Check navigationDestination placement
|   |-- onChange silent? -> Link outside NavigationStack
|
|-- Unexpected pop back?
|   |-- Immediate after push? -> Path recreated (check @State location)
|   |-- Random timing? -> External code modifying path
|
|-- Deep link fails?
|   |-- URL received? -> Check MainActor for path.append
|   |-- URL not received? -> Check URL scheme in Info.plist
|
|-- State lost on tab switch?
    |-- Same path for all tabs? -> Each tab needs own NavigationStack
```

## 흔한 Pattern

### Pattern 1: NavigationStack 밖의 Link

```swift
// WRONG - Link outside stack
VStack {
    NavigationLink("Go", value: "test")  // Won't work
    NavigationStack {
        Text("Root")
    }
}

// CORRECT - Link inside stack
NavigationStack {
    VStack {
        NavigationLink("Go", value: "test")
        Text("Root")
    }
    .navigationDestination(for: String.self) { Text($0) }
}
```

### Pattern 2: Lazy Container 내의 Destination

```swift
// WRONG - Destination may not be loaded
LazyVStack {
    ForEach(items) { item in
        NavigationLink(item.name, value: item)
            .navigationDestination(for: Item.self) { /* ... */ }
    }
}

// CORRECT - Destination outside lazy container
LazyVStack {
    ForEach(items) { item in
        NavigationLink(item.name, value: item)
    }
}
.navigationDestination(for: Item.self) { item in
    ItemDetail(item: item)
}
```

### Pattern 3: 렌더링마다 재생성되는 Path

```swift
// WRONG - Path reset on every body evaluation
struct ContentView: View {
    var body: some View {
        let path = NavigationPath()  // Recreated!
        NavigationStack(path: .constant(path)) { /* ... */ }
    }
}

// CORRECT - @State persists across renders
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) { /* ... */ }
    }
}
```

### Pattern 4: MainActor 밖에서 수정되는 Path

```swift
// WRONG - May fail silently
func loadAndNavigate() async {
    let recipe = await fetchRecipe()
    path.append(recipe)  // Not on MainActor
}

// CORRECT - Explicit MainActor
@MainActor
func loadAndNavigate() async {
    let recipe = await fetchRecipe()
    path.append(recipe)
}
```

### Pattern 5: Deep Link Timing

```swift
// WRONG - NavigationStack may not exist yet
.onOpenURL { url in
    handleDeepLink(url)  // Too early on cold start
}

// CORRECT - Queue until ready
@State private var pendingDeepLink: URL?
@State private var isReady = false

var body: some View {
    NavigationStack(path: $path) {
        RootView()
            .onAppear {
                isReady = true
                if let url = pendingDeepLink {
                    handleDeepLink(url)
                    pendingDeepLink = nil
                }
            }
    }
    .onOpenURL { url in
        if isReady {
            handleDeepLink(url)
        } else {
            pendingDeepLink = url
        }
    }
}
```

### Pattern 6: Tab 간에 공유되는 NavigationStack

```swift
// WRONG - All tabs share navigation state
NavigationStack(path: $path) {
    TabView {
        Tab("Home") { HomeView() }
        Tab("Settings") { SettingsView() }
    }
}

// CORRECT - Each tab has own stack
TabView {
    Tab("Home", systemImage: "house") {
        NavigationStack {
            HomeView()
        }
    }
    Tab("Settings", systemImage: "gear") {
        NavigationStack {
            SettingsView()
        }
    }
}
```

## Type 불일치 디버깅

```swift
// Check: Value type must exactly match destination type
NavigationLink(recipe.name, value: recipe)  // Recipe type

// This won't work if destination is for Recipe.ID
.navigationDestination(for: Recipe.ID.self) { id in  // Wrong!
    RecipeDetail(id: id)
}

// Types must match
.navigationDestination(for: Recipe.self) { recipe in  // Correct
    RecipeDetail(recipe: recipe)
}
```

## 검증 체크리스트

수정 적용 후:
- [ ] 예상되는 시점에 onChange(of: path)가 발생
- [ ] Destination의 print 구문이 실행됨
- [ ] Navigation이 유지됨 (다시 pop되지 않음)
- [ ] cold start에서도 동작 (deep link)
- [ ] tab 전환 시에도 state가 유지됨
