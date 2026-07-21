# View 구조

view는 SwiftUI에서 invalidation의 단위입니다. 무언가 변경되면 SwiftUI는 변경된 대상에 의존하는, 가장 작게 둘러싸는 view의 body를 다시 실행합니다. Factoring은 가독성뿐만 아니라 성능에도 영향을 미치며, `init`은 사람들이 예상하는 것보다 훨씬 더 자주 실행됩니다. 각 view가 입력으로 어떤 데이터를 받아야 하는지, 그리고 그것이 invalidation에 어떤 영향을 미치는지는 `dataflow.md`를 참고하세요.

구분된 section들을 가진 새로운 view를 만들 때 — header, list, footer, sidebar + main, content + counter, 또는 그 밖의 multi-region layout — 각 section을 `View`를 conform하는 자신만의 `struct`로 선언하세요. section을 `private var` computed property나 parent의 `@ViewBuilder` helper method로 factor하지 **마세요**. 아래 section들에서 그 이유를 설명하고 AVOID/PREFER pattern을 보여줍니다.

## section에는 항상 별도의 `View` type을 사용하고, computed property는 사용하지 마세요

긴 `var body` 구현은 읽기 어렵지만, 더 중요한 문제는 같은 body 안에 있는 모든 것이 동일한 invalidation boundary에 속한다는 점입니다. view의 input이 하나라도 변경되면 SwiftUI는 전체 body를 다시 평가합니다 — 모든 conditional, 모든 modifier chain, 모든 string interpolation을 — 실제로는 하나의 작은 leaf만 변경된 것에 의존하고 있어도 마찬가지입니다.

큰 body는 computed property나 `@ViewBuilder` helper function으로 나누지 말고, 개별 `View` type으로 factor하세요. computed property는 이를 둘러싼 view의 body에 inline되기 때문에 자신만의 invalidation boundary를 만들지 않으므로 update cost를 줄이지 못합니다. 명확하고 좁은 input을 가진 별도의 `View` type은 그 input이 변경될 때만 invalidate됩니다.

```swift
// AVOID: Computed properties look like factoring but share the parent's
// invalidation boundary. Toggling `isExpanded` invalidates `ProfileView`,
// which re-evaluates `header`, `details`, AND `footer` together — even
// though only `details` actually reads `isExpanded`.
struct ProfileView: View {
    @State private var isExpanded = false
    let user: User
    let stats: Stats

    var body: some View {
        VStack {
            header
            details
            footer
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "person.circle")
            Text(user.name).font(.title)
        }
    }

    private var details: some View {
        Group {
            if isExpanded {
                Text(user.bio)
                Text(user.location)
            }
        }
    }

    private var footer: some View {
        HStack {
            Label("\(stats.followers)", systemImage: "person.2")
            Label("\(stats.posts)", systemImage: "doc.text")
        }
        .font(.caption)
    }
}
```

```swift
// PREFER: Each subview is its own invalidation boundary with its own
// inputs. Toggling `isExpanded` invalidates `ProfileView` and
// `ProfileDetails`; `ProfileHeader` and `ProfileFooter` are skipped
// because none of their inputs changed.
struct ProfileView: View {
    @State private var isExpanded = false
    let user: User
    let stats: Stats

    var body: some View {
        VStack {
            ProfileHeader(name: user.name)
            ProfileDetails(
                bio: user.bio,
                location: user.location,
                isExpanded: isExpanded
            )
            ProfileFooter(followers: stats.followers, posts: stats.posts)
            Button(isExpanded ? "Less" : "More") { isExpanded.toggle() }
        }
    }
}

struct ProfileHeader: View {
    let name: String

    var body: some View {
        HStack {
            Image(systemName: "person.circle")
            Text(name).font(.title)
        }
    }
}

struct ProfileDetails: View {
    let bio: String
    let location: String
    let isExpanded: Bool

    var body: some View {
        if isExpanded {
            Text(bio)
            Text(location)
        }
    }
}

struct ProfileFooter: View {
    let followers: Int
    let posts: Int

    var body: some View {
        HStack {
            Label("\(followers)", systemImage: "person.2")
            Label("\(posts)", systemImage: "doc.text")
        }
        .font(.caption)
    }
}
```

각 subview에는 실제로 사용하는 데이터만 전달하세요 — `dataflow.md`에 나오는 "Pass views only the data they read" 규칙과 같습니다. 위 예제는 이미 이 규칙을 따르고 있습니다: 각 subview는 parent의 전체 `User`/`Stats` struct가 아니라, 자신이 읽는 field만 정확히 받습니다.

computed property와 작은 `@ViewBuilder` helper는 독립적인 invalidation story가 없는, 같은 body 내에서 두세 번 재사용되는 작은 fragment에는 여전히 쓸 자리가 있습니다. 이 규칙이 대상으로 하는 것은 *구성*을 위해서나 *body 길이*를 관리하기 위해 이루어지는 factoring이며, 이 경우에는 실제 `View` type을 쓰는 것이 올바른 처리입니다.

### section이 여러 개인 detail view

이 규칙이 가장 자주 누락되는 경우는 요구사항으로부터 코드를 작성하는 상황입니다: prompt가 여러 개의 구별된 section을 가진 `SomethingDetailView`를 요청하는 경우 — header + body + metadata + related items, header + ingredients + steps + footer, hero + description + specs + reviews 등입니다. 이런 prompt에 대한 training-data 상의 형태는 "`private var header: some View`, `private var body: some View` 등을 가진 단일 `View`"입니다. 이 형태는 잘못된 것입니다. 이름이 붙은 각 section은 항상 좁은 input을 가진 별도의 `View` type으로 factor하세요.

```swift
// PREFER: Detail view with multiple sections, each section a separate
// `View` type that takes only the fields it renders. The parent stays
// thin — it just composes the sections.
struct ProductDetailView: View {
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProductHeader(name: product.name, price: product.price)
                ProductGallery(images: product.imageURLs)
                ProductDescription(text: product.descriptionText)
                ProductReviews(
                    averageStars: product.averageStars,
                    reviewCount: product.reviewCount
                )
            }
            .padding()
        }
    }
}

struct ProductHeader: View {
    let name: String
    let price: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.largeTitle).fontWeight(.bold)
            Text(price, format: .currency(code: "USD"))
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ProductGallery: View {
    let images: [URL]

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(images, id: \.self) { url in
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.secondary.opacity(0.2)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct ProductDescription: View {
    let text: String

    var body: some View {
        Text(text).font(.body)
    }
}

struct ProductReviews: View {
    let averageStars: Double
    let reviewCount: Int

    var body: some View {
        HStack {
            Label("\(averageStars, specifier: "%.1f")", systemImage: "star.fill")
            Text("(\(reviewCount) reviews)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
```

이 형태는 다른 모든 detail view에도 일반화됩니다: `MovieDetailView`, `RecipeDetailView`, `ArticleDetailView`, `ProfileDetailView`, `EpisodeDetailView`. 매번 동일한 factoring을 적용합니다 — section마다 하나의 `View` type, 각각 좁은 input, 그리고 이들을 조합하는 얇은 parent입니다. parent에 `private var header: some View`를 두려고 하지 마세요.

## view의 `init`을 가볍게 유지하기

view의 `init`은 parent가 body를 다시 평가할 때마다 실행되며, `List`, `LazyVStack`, scroll container, 또는 animated parent 안에 있는 view의 경우 초당 여러 번 실행될 수 있습니다. `init`은 input을 stored property로 constant-time에 복사하는 작업으로 취급하세요. 그 안에서 데이터를 불러오거나, JSON을 decode하거나, file system에 접근하거나, 날짜를 formatting하거나, 큰 구조체를 allocate하지 마세요.

```swift
// AVOID: Expensive work in `init`. Every time the parent's body runs,
// the JSON is decoded again, the date formatter is allocated again,
// and the formatted string is rebuilt — even though the inputs haven't
// changed.
struct WeatherCard: View {
    let summary: WeatherSummary
    let formattedDate: String

    init(rawJSON: Data, date: Date) {
        self.summary = try! JSONDecoder().decode(WeatherSummary.self, from: rawJSON)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        self.formattedDate = formatter.string(from: date)
    }

    var body: some View {
        VStack {
            Text(summary.headline)
            Text(formattedDate)
        }
    }
}
```

```swift
// PREFER: Inputs are already-prepared values. Decoding lives in the
// model layer (or in a `.task`); formatting uses SwiftUI's built-in
// `Text(_:format:)` which is cached and locale-aware.
struct WeatherCard: View {
    let summary: WeatherSummary
    let date: Date

    var body: some View {
        VStack {
            Text(summary.headline)
            Text(date, format: .dateTime.day().month().year())
        }
    }
}
```

derived value를 정말로 한 번만 계산해서 view의 lifetime 동안 cache해야 한다면, 이를 `@State`가 소유하는 `@Observable` model에 저장하거나 `.task`에서 비동기로 계산하세요. `init`은 한 번만 실행되는 setup hook이 아니며, parent의 body만큼 자주 실행됩니다.

## 자식이 하나뿐인 `Group`

자식이 하나뿐인 `Group`인 `Group { SomeView() }`는 공짜가 아닙니다. 시각적으로는 아무런 효과가 없지만, view를 `Group<SomeView>`라는 추가적인 type으로 감쌉니다. 그 뒤에 chain하는 모든 modifier(`.onChange`, `.background`, `.frame` 등)는 원래 view의 type이 아니라 이 감싸진 type을 기준으로 type-check되어야 합니다. modifier chain이 길어지면 이 추가적인 type wrapper가 완전히 불필요한 type checking overhead를 더할 수 있습니다.

이 "자식이 하나뿐인" 규칙은 구체적으로 *하나의 concrete view*에 관한 것입니다. content가 `ForEach`, sibling view들의 `TupleView`, 또는 (`_ConditionalContent`를 만들어내는) `if`/`else`인 `Group`은 실제로 의미 있는 일을 하고 있으므로 문제가 없습니다.

```swift
// AVOID: A single concrete child inside Group. The Group wraps `Text` in
// an extra type that every chained modifier must type-check against, for
// no behavioral benefit.
Group {
    Text(status)
}
.padding(.horizontal, 8)
.background(.thinMaterial, in: Capsule())
```

```swift
// PREFER: Drop the Group and chain the modifiers directly on the child.
Text(status)
    .padding(.horizontal, 8)
    .background(.thinMaterial, in: Capsule())
```

```swift
// PREFER: Multiple siblings is exactly what Group is for — modifiers
// apply to each child as a unit without needing an HStack/VStack
// container that would change layout.
Group {
    Button("Save", action: onSave)
    Button("Cancel", action: onCancel)
    Button("Delete", role: .destructive, action: onDelete)
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

```swift
// PREFER: Wrapping an `if`/`else` in Group so a shared modifier applies
// uniformly to both branches. This is NOT the single-child anti-pattern —
// the Group's content is `_ConditionalContent<...>`, not a single concrete
// view, and removing the Group would either drop the modifier from one
// branch or force you to repeat it on both.
Group {
    if let label {
        Text(label)
            .padding(4)
            .background(.thinMaterial, in: Capsule())
    } else {
        Color.clear
    }
}
.accessibilityHidden(label == nil)
```
