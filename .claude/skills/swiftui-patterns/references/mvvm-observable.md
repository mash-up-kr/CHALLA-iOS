# @Observable를 사용하는 MVVM (iOS 17+)

**용도:** 리액티브 상태를 가진 view model

**문제:** @Published 보일러플레이트 없이 리액티브 view model이 필요합니다.

**해결책:**
```swift
import Observation

@Observable
@MainActor
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let articleService: ArticleService

    init(articleService: ArticleService) {
        self.articleService = articleService
    }

    func loadArticles() async {
        isLoading = true
        errorMessage = nil

        do {
            articles = try await articleService.fetchArticles()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ArticleListView: View {
    @State private var viewModel: ArticleListViewModel

    init(articleService: ArticleService) {
        _viewModel = State(wrappedValue: ArticleListViewModel(articleService: articleService))
    }

    var body: some View {
        List(viewModel.articles) { article in
            ArticleRow(article: article)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .task {
            await viewModel.loadArticles()
        }
    }
}
```

**장점:**
- `@Published` 불필요
- 세밀한 observation (접근한 속성만 추적)
- ObservableObject보다 나은 성능
- 더 적은 보일러플레이트
