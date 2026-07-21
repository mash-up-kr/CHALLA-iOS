# Accessibility Patterns

## VoiceOver 지원

**용도:** 스크린 리더 accessibility

```swift
struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack {
            AsyncImage(url: article.imageURL) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            .accessibilityHidden(true) // Decorative image

            VStack(alignment: .leading) {
                Text(article.title)
                    .font(.headline)
                Text(article.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(article.title), by \(article.author)")
        .accessibilityHint("Double tap to read article")
    }
}
```

## Dynamic Type 지원

**용도:** 사용자 설정에 따라 크기가 조절되는 텍스트

```swift
struct ArticleContent: View {
    let article: Article
    @ScaledMetric private var imageHeight: CGFloat = 200

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: article.imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: imageHeight) // Scales with Dynamic Type
                .clipped()

                Text(article.title)
                    .font(.title)

                Text(article.content)
                    .font(.body)
            }
        }
    }
}
```

## Accessibility 액션

**용도:** 커스텀 VoiceOver 액션

```swift
struct ArticleCard: View {
    let article: Article
    @State private var isSaved = false
    @State private var isShared = false

    var body: some View {
        VStack {
            Text(article.title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(article.title)
        .accessibilityAction(named: "Save") {
            isSaved.toggle()
        }
        .accessibilityAction(named: "Share") {
            isShared = true
        }
    }
}
```
