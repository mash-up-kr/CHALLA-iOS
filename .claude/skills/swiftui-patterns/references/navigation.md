# NavigationStack 패턴 (iOS 16+)

**용도:** 타입 안전한 프로그래밍 방식 내비게이션

**문제:** 딥 링킹을 지원하는 프로그래밍 방식 내비게이션이 필요합니다.

**해결책:**
```swift
// Navigation coordinator
@Observable
@MainActor
final class NavigationCoordinator {
    var path = NavigationPath()

    func navigateTo(_ article: Article) {
        path.append(article)
    }

    func navigateToAuthor(_ author: Author) {
        path.append(author)
    }

    func navigateToRoot() {
        path.removeLast(path.count)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}

// App navigation
struct AppNavigationView: View {
    @State private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ArticleListView()
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
                .navigationDestination(for: Author.self) { author in
                    AuthorProfileView(author: author)
                }
                .environment(coordinator)
        }
    }
}

// Usage in views
struct ArticleListView: View {
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        List(articles) { article in
            Button {
                coordinator.navigateTo(article)
            } label: {
                ArticleRow(article: article)
            }
        }
    }
}
```

**이점:**
- 타입 안전한 내비게이션
- 프로그래밍 방식 제어
- 딥 링킹 지원 준비 완료
- 중앙화된 내비게이션 로직
