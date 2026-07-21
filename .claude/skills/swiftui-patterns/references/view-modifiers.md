# 최신 View Modifier (iOS 17+)

## onChange(of:initial:_:) — 새로운 시그니처

### ✅ 최신 패턴
```swift
struct SearchView: View {
    @State private var searchText = ""

    var body: some View {
        TextField("Search", text: $searchText)
            .onChange(of: searchText) { oldValue, newValue in
                performSearch(query: newValue)
            }
            // Run on appear with initial: true
            .onChange(of: searchText, initial: true) { oldValue, newValue in
                validateInput(newValue)
            }
    }
}
```

### ❌ 지원 종료된 패턴
```swift
// DEPRECATED: onChange(of:perform:)
.onChange(of: searchText) { newValue in
    performSearch(query: newValue)
}
```

## task(priority:_:) — 비동기 작업

### ✅ 최신 패턴
```swift
struct UserListView: View {
    @State private var users: [User] = []
    @State private var isLoading = false

    var body: some View {
        List(users) { user in
            UserRow(user: user)
        }
        .task {
            await loadUsers()
        }
        .task(id: selectedFilter) {
            // Cancelled and restarted when selectedFilter changes
            await loadUsers(filter: selectedFilter)
        }
    }

    func loadUsers() async {
        isLoading = true
        users = try? await fetchUsers()
        isLoading = false
    }
}
```

### ❌ 지원 종료된 패턴
```swift
// NEVER use .onAppear with Task
.onAppear {
    Task {
        await loadUsers()
    }
}
```
