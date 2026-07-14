# Async 작업 Patterns

## Task Modifier

**용도:** View가 나타날 때 데이터 로드

```swift
struct ArticleDetailView: View {
    let articleId: String
    @State private var article: Article?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let article {
                ArticleContent(article: article)
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Article Not Found", systemImage: "doc.text")
            }
        }
        .task {
            await loadArticle()
        }
    }

    private func loadArticle() async {
        isLoading = true
        defer { isLoading = false }

        do {
            article = try await articleService.fetchArticle(id: articleId)
        } catch {
            print("Error loading article: \(error)")
        }
    }
}
```

## Refreshable 콘텐츠

**용도:** Pull-to-refresh 리스트

```swift
struct ArticleListView: View {
    @State private var articles: [Article] = []

    var body: some View {
        List(articles) { article in
            ArticleRow(article: article)
        }
        .refreshable {
            await refreshArticles()
        }
    }

    private func refreshArticles() async {
        do {
            articles = try await articleService.fetchArticles()
        } catch {
            print("Error refreshing: \(error)")
        }
    }
}
```

## 백그라운드 Task

**용도:** 논블로킹 async 작업

```swift
struct ArticleDetailView: View {
    let article: Article
    @State private var isSaved = false

    var body: some View {
        ArticleContent(article: article)
            .toolbar {
                Button(isSaved ? "Saved" : "Save") {
                    Task {
                        await saveArticle()
                    }
                }
            }
    }

    private func saveArticle() async {
        do {
            try await articleService.saveArticle(article)
            isSaved = true
        } catch {
            print("Error saving: \(error)")
        }
    }
}
```
