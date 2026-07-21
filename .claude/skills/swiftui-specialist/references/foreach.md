# ForEach

`ForEach`는 identity를 사용해 body 평가(evaluation)가 반복될 때마다 element들을 매칭합니다. 부모의 `body`가 다시 실행되면 SwiftUI는 이전 identifier 컬렉션과 새 컬렉션을 diff하여 어떤 row가 삽입, 삭제, 이동되었는지, 혹은 단순히 업데이트되었는지를 파악합니다. 각 element의 identity는 SwiftUI가 다음을 할 수 있게 해주는 anchor입니다:

- 단순히 이동했거나 content가 변경된 row에 대해 `@State`, focus, selection, 스크롤 위치를 보존합니다.
- 삽입, 삭제, 재정렬을 올바르게 animate합니다. row는 이동하는 동안에도 화면상의 존재감을 유지하며, 새로운 row는 페이드되거나 슬라이드되어 나타나고, 삭제된 row는 transition되어 사라집니다.
- 불필요하게 subtree를 다시 빌드하지 않도록 합니다. identity가 안정적이면 SwiftUI는 data가 변경된 element에 대해 기존 view를 허물고 새로 만드는 대신 재사용할 수 있습니다.

identity가 불안정하면 이 중 어느 것도 동작하지 않습니다. state가 초기화되고, animation은 갑작스러운 교체로 깨지며, 재사용될 수 있었던 subtree를 SwiftUI가 다시 빌드하면서 성능이 저하됩니다.

기본 원칙은 다음과 같습니다: `ForEach` element의 identity는 **stable**해야 하며(컬렉션 내 위치가 바뀌더라도 동일한 element는 body 평가마다 동일한 id를 가져야 함), **unique**해야 합니다(동일한 `ForEach` 내에서 서로 다른 두 element가 같은 id를 공유하지 않아야 함).

## 다른 data-driven initializer에도 적용됩니다

이 문서의 모든 내용은 data의 `RandomAccessCollection`과 `id:` key path(또는 `Identifiable` element)를 받아 내부적으로 `ForEach`처럼 동작하는 모든 SwiftUI API에 적용됩니다. 가장 흔한 예는 다음과 같습니다:

- `List(_:id:rowContent:)`와 `List(_:rowContent:)`(`Identifiable` overload).
- `List(_:id:selection:rowContent:)`와 관련된 selection-aware overload들.
- `Table(_:)` / `Table(_:selection:)`와 이들의 `id:` overload.
- `OutlineGroup(_:id:children:content:)`와 `List(_:children:rowContent:)`(outline variant).
- data 컬렉션을 iterate하는 `Picker` overload, 예를 들어 내부에서 `ForEach`와 함께 사용되는 `Picker(_:selection:content:)`.
- content에서 `ForEach`와 함께 사용되는 `DisclosureGroup`.

이들 중 하나가 컬렉션을 직접 받는 것을 보면, `ForEach`에서와 마찬가지로 "element당 id"를 stable하고 unique하며 위치나 mutable한 content와 무관해야 하는 것으로 이해하세요.

## identity로 컬렉션의 index를 사용하지 마세요

컬렉션의 index, 혹은 index에 대한 `.self`를 identifier로 사용하는 것은 가장 흔한 anti-pattern입니다. index는 위치를 나타낼 뿐 element를 나타내지 않습니다. 컬렉션이 재정렬되거나, 삽입되거나, 필터링되는 순간 동일한 index는 이제 다른 element를 가리키게 되지만 SwiftUI는 이를 알아낼 방법이 없습니다.

```swift
// AVOID: index를 identity로 사용.
// `items`가 재정렬되거나 element가 삽입되면, 삽입 지점 이후의 모든 id는 이제
// 다른 element를 가리키게 됩니다. SwiftUI는 "id 3의 element가 바뀌었다"고
// 인식할 뿐 "element B가 3에서 4로 이동했다"고 인식하지 못하므로, row state가
// 초기화되고 move가 replacement로 animate됩니다.
struct ItemList: View {
    @State private var items: [Item] = []

    var body: some View {
        List {
            ForEach(items.indices, id: \.self) { index in
                ItemRow(item: items[index])
            }
        }
    }
}
```

```swift
// PREFER: element와 함께 이동하는 property로 각 element를 식별하세요.
ForEach(items, id: \.id) { item in
    ItemRow(item: item)
}
```

진짜로 identity와 같은 값(예: 이미 unique key인 `String`)이 아닌 대상에 `.indices`, `\.offset`, 혹은 `id: \.self`가 사용되고 있다면, 이는 identity가 위치로부터 파생되고 있다는 신호입니다. 해결책은 element 자체의 property로 element를 식별하는 것입니다.

### `.enumerated()`는 괜찮습니다 - index만 id로 사용하지 않으면 됩니다

`.enumerated()`를 사용하는 것 자체는 anti-pattern이 아닙니다. 예를 들어 row가 자신의 위치를 표시해야 할 때, 각 element와 함께 index를 얻는 합리적인 방법입니다. anti-pattern은 구체적으로 index를 id로 사용하는 것입니다. id는 element 고유의 identity로 유지하고, index는 일반적인 row data로 취급하세요:

```swift
// AVOID: offset을 id로 사용하는 `.enumerated()`.
// `items.indices`와 동일한 실패 양상입니다: id가 element가 아니라 위치입니다.
ForEach(items.enumerated(), id: \.offset) { index, item in
    ItemRow(number: index + 1, item: item)
}
```

```swift
// PREFER: `.enumerated()`는 괜찮습니다; id는 element로부터 오고,
// index는 그저 row view에 전달되는 row data일 뿐입니다.
ForEach(items.enumerated(), id: \.element.id) { index, item in
    ItemRow(number: index + 1, item: item)
}
```

### `.enumerated()`와 `RandomAccessCollection`

Swift 6.1부터 `.enumerated()`가 반환하는 sequence는 base 컬렉션이 conform하는 경우 `Collection`, `BidirectionalCollection`, `RandomAccessCollection`에 조건부로 conform합니다. `ForEach`는 data가 `RandomAccessCollection`이어야 하므로, Swift 6.1 이상에서는 `items.enumerated()`를 별도의 `Array(...)` wrapper 없이 바로 전달할 수 있습니다. 이전 toolchain에서는 여전히 wrapper가 필요합니다. 새 코드에서는 직접 전달하는 형태를 선호하세요. 이렇게 하면 body 평가마다 컬렉션을 즉시(eager) 복사하는 것을 피할 수 있습니다.

## body 평가마다 새로운 id를 생성하지 마세요

`body`가 실행될 때마다 `id`가 새로 생성되는 `Identifiable` 타입은 identity를 갖고 있는 것처럼 보이지만, 실제로는 body 평가마다 완전히 새로운 identifier를 만들어냅니다. `ForEach`의 관점에서는 매 업데이트마다 컬렉션 전체가 교체된 것입니다.

```swift
// AVOID: `body` 내부에서 items를 생성. `Item(title:)`을 호출할 때마다
// 새로운 UUID가 initialize되므로, body 평가마다 완전히 새로운 id 집합이
// 만들어집니다. ForEach는 이를 "컬렉션 전체가 교체됨"으로 인식합니다:
// state가 초기화되고, row가 깜빡이며, animation은 완전한 교체로 저하됩니다.
// `let id = UUID()` 기본값 자체는 문제가 없습니다 - 버그는 `body`보다
// 오래 유지되지 않는 곳에서 값을 생성한다는 점입니다.
struct Item: Identifiable {
    let id = UUID()
    var title: String
}

struct ContentView: View {
    let titles: [String]

    var body: some View {
        List {
            ForEach(titles.map { Item(title: $0) }) { item in
                Text(item.title)
            }
        }
    }
}
```

`let id = UUID()` 기본값은 값 자체가 어딘가 durable한 곳(`@State`, `@Observable` model, 데이터베이스 row)에 저장되어 있는 한 잘 동작합니다. 값이 매 body pass마다 재구성되는 순간 버그가 됩니다. 해결책은 id가 body 평가 전체에 걸쳐 유지되는 무언가에 묶이도록 하는 것입니다. 원본 data에 natural key(데이터베이스 id, 파일 URL, 서버가 할당한 id)가 있다면 그것을 사용하세요. id를 합성해야 한다면, `body`보다 오래 유지되는 storage - 보통 model layer - 에서 한 번만 생성하세요.

```swift
// PREFER: 주어진 element에 대해 그 자체로 immutable한 property -
// 서버가 할당한 id, 파일 URL, 카탈로그 SKU - 로부터 identity를 파생시키세요.
// property가 `let`이기 때문에, 계산된 `id`는 element가 수정되어도 변하지
// 않습니다.
struct Document: Identifiable {
    let url: URL              // 파일이 위치하는 곳; 생성 시 할당됨
    var displayName: String   // 사용자가 편집 가능

    var id: URL { url }
}
```

```swift
// PREFER: UUID를 items를 소유한 model에서 한 번만 생성하고, 업데이트 전반에
// 걸쳐 유지하세요. `body`는 그저 이미 stable한 id를 읽기만 합니다.
@MainActor
@Observable
final class ItemStore {
    var items: [Item] = []

    func add(title: String) {
        items.append(Item(id: UUID(), title: title))
    }
}

struct Item: Identifiable {
    let id: UUID
    var title: String
}
```

## `Identifiable` conformance를 선호하세요

`ForEach`는 명시적인 `id:` key path를 받을 수 있지만, element가 natural한 identity를 가지고 있다면 element 타입을 `Identifiable`에 conform시키는 것이 idiomatic한 선택입니다. 이렇게 하면 호출자가 key path를 반복하지 않고 `ForEach(items)`라고 쓸 수 있고, 타입 수준에서 identity를 문서화하며, `Identifiable`을 요구하는 다른 SwiftUI API(`List`, `sheet(item:)`, `confirmationDialog(..., presenting:)`, navigation value type 등)에서도 그 타입을 사용할 수 있게 됩니다.

```swift
// PREFER: Identifiable conformance; identity가 타입에서 한 번만 선언됩니다.
struct Item: Identifiable {
    let id: UUID
    var title: String
}

ForEach(items) { item in
    ItemRow(item: item)
}
```

```swift
// element 타입을 직접 바꿀 수 없거나, id가 다른 타입에 존재하는 경우
// (예: reference를 감싸는 value type)라면 허용됩니다.
ForEach(items, id: \.serverID) { item in
    ItemRow(item: item)
}
```

타입에 의미 있는 identity 개념이 없다면, 단지 `ForEach`를 만족시키기 위해 그 타입을 `Identifiable`에 conform시키지 마세요. 이런 경우에는 이 context에서 identity 역할을 하는 property에 대한 명시적인 key path를 전달하세요.

## id를 hash하기 저렴하게 유지하세요

`ForEach`는 element id를 자주 hash하고 비교합니다 - 이는 매 diff마다 발생하며, 이는 감싸고 있는 view의 `body`가 컬렉션을 다시 평가할 때마다 일어납니다. id 타입을 hash하는 비용이 크다면, 그 비용은 매 업데이트마다 지불되며 컬렉션 크기에 비례해 커집니다.

흔한 anti-pattern은 element 전체를 id로 사용하는 것입니다 - 큰 `Hashable` struct에 `id: \.self`를 쓰거나, 값 전체를 반환하는 `id` property를 사용하는 경우입니다. compiler가 synthesize한 `Hashable` conformance는 모든 저장 property를 hasher에 입력합니다. 긴 문자열, nested 컬렉션, 혹은 많은 필드를 가진 struct의 경우 각 hash 연산은 실질적인 작업을 수행하며, 이 작업은 매 업데이트마다 모든 row에서 반복됩니다.

```swift
// AVOID: id가 struct 전체입니다. 각 row를 hash할 때마다 매 diff마다 모든
// 필드를 순회합니다 - 긴 문자열, nested 배열 등 전부. 비용은 컬렉션 크기와
// element당 필드 수 모두에 비례해 커집니다.
struct Article: Hashable {
    let title: String
    let body: String        // 커질 수 있음
    let tags: [String]
    let author: Author
    let publishedAt: Date
}

ForEach(articles, id: \.self) { article in
    ArticleRow(article: article)
}
```

```swift
// PREFER: id는 element를 고유하게 식별하는, 작고 hash하기 저렴한
// property입니다. row view에는 여전히 struct 전체가 전달되지만,
// diffing 중에는 id만 hash됩니다.
struct Article: Identifiable, Hashable {
    let id: UUID
    let title: String
    let body: String
    let tags: [String]
    let author: Author
    let publishedAt: Date
}

ForEach(articles) { article in
    ArticleRow(article: article)
}
```

좋은 id는 작은 primitive입니다: `UUID`, `Int`, 짧은 `String` key, `URL`. 이들은 기반 element의 크기와 무관하게 constant time에 hash됩니다. element에 natural key(데이터베이스 id, 서버가 할당한 id, 파일 URL)가 있다면 그것을 사용하고, 그렇지 않다면 하나를 합성하여 element에 저장하세요.

해결책은 올바른 id를 선택하는 것이며, `Hashable` conformance를 손대는 것이 아닙니다. 그대로 두세요 - 다른 곳(selection, set, dictionary key, navigation value)에서 사용될 수 있으며, 이를 제거하는 것은 diffing 비용과 무관합니다.

## identity는 `ForEach`를 렌더링하는 view보다 오래 유지되어야 합니다

`ForEach`는 element의 identity가 최소한 `ForEach`를 렌더링하는 view가 화면에 있는 동안에는 stable하다고 가정합니다. 감싸고 있는 view가 여전히 살아있는 동안 element의 id가 바뀌면, SwiftUI는 이를 "기존 element가 삭제되고 새로운 element가 삽입됨"으로 해석하여, row의 state를 잃고 제자리 업데이트 대신 삭제/삽입 animation을 재생합니다.

흔한 함정은 in place로 mutate되는 property로부터 id를 파생시키는 것입니다(예를 들어 현재 title로부터 `id`를 계산한 다음 title을 편집하는 경우). 편집이 id를 바꾸고, row는 편집 중에 파괴되고 다시 생성되며, focus, selection, 그리고 row별 `@State`가 모두 사라집니다.

```swift
// AVOID: 편집으로 값이 바뀌는 mutable property로부터 파생된 id입니다.
// row의 text field에 입력하면 item의 이름이 바뀌고, 이는 id를 바꾸며,
// ForEach는 row가 삭제되고 새로운 row가 삽입되었다고 생각하게 됩니다.
// text field는 매 keystroke마다 focus를 잃습니다.
struct Item: Identifiable {
    var id: String { title }
    var title: String
}
```

```swift
// PREFER: id는 어떤 mutable한 content와도 무관합니다. `title`을 편집해도
// identity는 그대로 유지되므로, row는 자신의 state와 focus를 유지합니다.
struct Item: Identifiable {
    let id: UUID
    var title: String
}
```

확실하지 않을 때는 이렇게 자문하세요: "이 element를 in place로 편집하면 id가 바뀌는가?" 만약 그렇다면, identity가 content에 묶여 있는 것이며 편집할 때마다 깨질 것입니다. id는 element가 진짜로 다른 element일 때만 바뀌어야 하며, data가 업데이트될 때 바뀌어서는 안 됩니다.

## `ForEach` 내부에서 inline으로 sort하거나 filter하지 마세요

`ForEach`에 전달되는 컬렉션은 감싸고 있는 view의 `body`가 실행될 때마다 평가됩니다. 그 expression이 사소하지 않은 transformation - `sorted`, `filter`, element를 재구성하는 `map`, grouping, deduplication 등 - 이라면, 해당 작업은 list content와 아무 관련이 없는 invalidation(부모의 state 변경, environment 업데이트, window resize)에서도 매번 반복됩니다.

```swift
// AVOID: ForEach의 argument 내부에서 sort하고 filter합니다.
// 이 view를 invalidate시킨 변경이 `items`나 `searchText`와 전혀 무관해도,
// body 평가마다 `filter`와 `sorted`가 전체 배열에 대해 다시 실행됩니다.
struct ItemList: View {
    let items: [Item]
    let searchText: String

    var body: some View {
        List {
            ForEach(
                items
                    .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                    .sorted { $0.title < $1.title }
            ) { item in
                ItemRow(item: item)
            }
        }
    }
}
```

파생된 컬렉션은 model이나 view state에 캐시하고, input이 실제로 변경될 때만 다시 계산하세요. `@Observable` model이 자연스러운 위치입니다: `didSet`이나 mutating entry point에서 다시 계산하고, view는 이미 sort되고 filter된 배열을 읽도록 하세요.

```swift
// PREFER: model이 파생된 컬렉션을 소유하며 자신의 input이 변경될 때만
// 이를 업데이트합니다. view는 준비된 배열을 읽으며, `body`는 iterate하는
// 것 이상의 작업을 하지 않습니다.
@MainActor
@Observable
final class ItemListModel {
    var items: [Item] = [] {
        didSet { recomputeVisibleItems() }
    }

    var searchText: String = "" {
        didSet { recomputeVisibleItems() }
    }

    private(set) var visibleItems: [Item] = []

    private func recomputeVisibleItems() {
        visibleItems = items
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.title < $1.title }
    }
}

struct ItemList: View {
    let model: ItemListModel

    var body: some View {
        List {
            ForEach(model.visibleItems) { item in
                ItemRow(item: item)
            }
        }
    }
}
```

파생된 컬렉션이 정말로 view-local하다면(예: model에 속하지 않는 local filter box), `body`에서 다시 계산하는 대신 `@State`에 캐시하고 `onChange(of:)`를 통해 input이 변경될 때 업데이트하세요. 원칙은 동일합니다: body 평가마다 계산하는 것이 아니라 input 변경마다 한 번씩 계산하세요.

저렴한 transformation - 작은 slice, `prefix(n)`, 이미 준비된 배열을 읽는 것, struct로의 trivial한 map - 은 inline으로 사용해도 괜찮습니다. 이 규칙이 대상으로 하는 것은 컬렉션 크기에 비례해 커지는 작업이나 새로운 element를 할당하는 작업입니다.

## `List`에서는 unary row view를 선호하세요

`List`는 모든 row의 identity를 미리 필요로 합니다: 이전 업데이트와 diff하기 위해 전체 id 집합을 materialize해야 합니다. 각 row가 element당 단일 view일 때, SwiftUI는 각 row의 `body`를 실행하지 않고도 `ForEach` element의 id만으로 row id를 template할 수 있습니다. 이 fast path가 긴 `List`를 저렴하게 만드는 요인입니다.

row의 최종 id는 `ForEach`로부터의 명시적인 id와 약간의 structural identity - 대략적으로, row 내부에서 어떤 top-level view가 생성되었는지를 나타내는 marker - 를 결합한 것입니다. row body가 단일 top-level view를 생성한다면 structural identity는 constant이며 각 row의 id는 element의 id만으로 완전히 결정됩니다. row body가 서로 다른 top-level shape(맨 위 레벨의 `switch`, top-level `if`/`else`) 사이를 분기한다면, structural 부분은 row마다 달라집니다. SwiftUI는 이후 row들이 동일한 branch를 탔다고 가정할 수 없으므로 첫 row로부터 template할 수 없고, id를 계산하기 위해 모든 row의 body를 평가하는 방식으로 fallback하며, 업데이트 비용은 row 수에 비례해 커집니다.

```swift
// AVOID: 이 row view는 "multi"입니다 - top-level `switch`로 인해 각 row의
// structural identity가 어떤 case가 실행되었는지에 따라 달라집니다. id를
// 계산하기 위해 SwiftUI는 긴 list에서도 모든 row의 body를 평가해야 합니다.
struct ItemRow: View {
    var item: Item

    var body: some View {
        switch item.kind {
        case .plain:       Text(item.title)
        case .highlighted: Text(item.title).bold()
        case .disabled:    Text(item.title).foregroundStyle(.secondary)
        }
    }
}

struct ItemList: View {
    let items: [Item]

    var body: some View {
        List {
            ForEach(items) { item in
                ItemRow(item: item)
            }
        }
    }
}
```

```swift
// PREFER: 분기하는 content를 container로 감싸서 row를 "unary"로 만드세요
// - 어떤 case가 실행되었든 top-level view는 하나입니다. SwiftUI는 모든
// row를 순회하지 않고도 ForEach로부터 id를 template할 수 있습니다.
struct ItemRow: View {
    var item: Item

    var body: some View {
        VStack {
            switch item.kind {
            case .plain:       Text(item.title)
            case .highlighted: Text(item.title).bold()
            case .disabled:    Text(item.title).foregroundStyle(.secondary)
            }
        }
    }
}
```

single-root container라면 어떤 것이든 동작합니다 - `VStack`, `HStack`, `ZStack`, 혹은 custom wrapper view. 핵심은 N개의 가능한 top-level view를 하나로 바꾸는 것입니다.

switch를 conditional modifier가 있는 단일 shape로 평탄화해서(예: `Text(item.title).bold(item.kind == .highlighted)`) 이 문제를 "해결"하려고 하지 마세요. 이 방법이 이 row를 unary로 만드는 것은 단지 세 case가 모두 동일한 top-level shape를 생성했기 때문일 뿐이며, 잘못된 교훈을 주고 case들이 structurally 다른 view(Text vs Image vs Divider)를 생성하는 순간 깨지게 됩니다. 대신 switch를 container로 감싸세요.

### unary view vs multi view

`View`는 `body`가 단일 top-level view를 생성할 때(즉 `VStack`, `HStack`, `ZStack`, 혹은 다른 single-root container로 감싸져 있을 때) **unary**입니다. body가 하나 이상의 top-level view를 생성하거나, 서로 다른 top-level shape 사이를 분기할 때는 **multi**입니다. `Group`과 `ForEach`는 container가 아니라 passthrough입니다 - 이들은 자신의 content를 unary로 만들지 않습니다. `Group { A(); B(); C() }`는 `A(); B(); C()`를 직접 쓰는 것과 동일한 세 개의 top-level view를 만들어냅니다.

`List`의 row에서는 unary를 선호하세요. 해결책은 보통 `body`를 `VStack`으로 감싸는 것만큼 간단합니다.

### `else`가 없는 top-level `if` 역시 multi입니다

`ForEach`의 doc comment는 이 fast path를 "constant number of views"라는 관점에서 설명합니다: 각 row의 builder는 모든 element에 대해 동일한 개수의 top-level view를 생성해야 합니다. `else`가 없는 top-level `if`는 조건에 따라 0개 또는 1개의 view를 생성하므로 개수가 constant하지 않으며, 동일한 fast path가 무력화됩니다 - SwiftUI는 어떤 element가 애초에 row를 만들어내는지 알아내기 위해 모든 row의 body를 평가해야 합니다.

```swift
// AVOID: lazy container 안에 맨 top-level `if`가 있습니다.
// `namedFont.name.count`에 따라 row는 0개 또는 1개의 view가 되므로,
// row builder는 constant한 개수의 view를 생성하지 못하고 List의
// fast path가 무력화됩니다.
ForEach(namedFonts) { namedFont in
    if namedFont.name.count != 2 {
        Text(namedFont.name)
    }
}
```

```swift
// PREFER: single-root container로 감싸서 row가 항상 정확히 하나의
// top-level view가 되도록 하세요; `if`는 내부 content가 됩니다.
ForEach(namedFonts) { namedFont in
    VStack {
        if namedFont.name.count != 2 {
            Text(namedFont.name)
        }
    }
}
```

의도가 실제로 "이 element를 건너뛰기"라면, 0개의 view를 만들어내는 row를 생성하는 대신 `ForEach`에 전달하기 전에 컬렉션을 filter하세요. wrapping으로 해결하는 방법은 row 내부에 정말로 optional한 content가 있을 때 적합하고, upstream에서 filter하는 방법은 일부 element가 애초에 row가 되어서는 안 될 때 적합합니다.

### `ForEach`의 row로 `AnyView`를 사용하지 마세요

`AnyView`는 감싸고 있는 view의 타입을 erase하며, 이는 structural identity 역시 erase합니다: SwiftUI는 더 이상 타입만으로 row가 어떤 shape를 생성했는지 알 수 없습니다. 이는 top-level `switch`와 동일하게 templating fast path를 무력화합니다 - framework는 내부에 무엇이 있는지 알아내기 위해 각 row의 body를 평가해야 합니다.

```swift
// AVOID: row를 `AnyView`로 만들기. 각 row의 structural identity가
// SwiftUI에게 opaque하므로, List는 id를 template할 수 없고 모든 row의
// body를 평가하는 방식으로 fallback합니다.
ForEach(items) { item in
    rowView(for: item) // AnyView를 반환
}

func rowView(for item: Item) -> AnyView {
    switch item.kind {
    case .plain:       return AnyView(Text(item.title))
    case .highlighted: return AnyView(Text(item.title).bold())
    case .disabled:    return AnyView(Text(item.title).foregroundStyle(.secondary))
    }
}
```

```swift
// PREFER: single-root container 내부에서 `switch`나 `if`/`else`를 사용하는
// body를 가진 concrete row view. row의 static한 shape가 SwiftUI에게
// 보이므로, list 전체에 걸쳐 id를 template할 수 있습니다.
struct ItemRow: View {
    var item: Item

    var body: some View {
        VStack {
            switch item.kind {
            case .plain:       Text(item.title)
            case .highlighted: Text(item.title).bold()
            case .disabled:    Text(item.title).foregroundStyle(.secondary)
            }
        }
    }
}

ForEach(items) { item in
    ItemRow(item: item)
}
```

`AnyView`의 비용은 `List`에 데이터를 공급하는 `ForEach`의 row로 사용될 때 특히 두드러집니다. structural 정보의 손실이 row 수에 비례해 커지기 때문입니다. row 타입을 통일하기 위해 `AnyView`를 사용하는 어떤 설계보다도, container 내부에서 `switch`/`if`/`else`를 사용하는 concrete row view를 선호하세요.

`AnyView`를 `some View`를 반환하는 `@ViewBuilder` helper로 바꿔서 이 문제를 "해결"하려고 하지 마세요. helper의 body는 여전히 `_ConditionalContent` tree를 생성하는 맨 `switch`이며 - row는 여전히 multi-shape이고 동일한 fast path가 여전히 무력화됩니다. type erasure를 제거하는 것은 해결책의 절반일 뿐이며, 나머지 절반은 분기하는 content를 single-root container를 가진 concrete row view 안에 감싸는 것입니다.

### `-LogForEachSlowPath`로 진단하기

기존 앱에서 non-constant한 row builder를 찾으려면 다음과 같이 launch하세요:

```
-LogForEachSlowPath YES
```

SwiftUI는 row body가 non-constant한 개수의 view를 생성하는, lazy container(`List`, `LazyVStack` 등) 내부의 각 `ForEach`를 log로 남깁니다. 이를 사용해 triage하세요 - log가 문제가 되는 call site를 가리켜주므로 그것들을 refactor할지 선택할 수 있습니다.
