# 데이터 흐름

SwiftUI 앱에서 데이터가 흐르는 방식은 어떤 view가 언제 invalidate되는지를 결정합니다. `@State`는 view-local state를 소유합니다. `@Observable` model 객체는 subtree 전반에서 공유되는 데이터를 담으며, per-property tracking을 통해 변경된 내용을 실제로 읽는 정확한 view로 invalidation의 범위를 좁힙니다. `Binding`을 사용하면 child가 parent가 소유한 state를 편집할 수 있습니다. 아래 섹션들은 각 view에 어떤 형태의 데이터를 건네야 하는지, 각 ownership 도구를 언제 사용해야 하는지, view invalidation을 최대한 좁게 유지하도록 model을 구성하는 방법, 그리고 side effect와 two-way edit를 처리하는 방법을 다룹니다.

## View에 데이터 전달하기

value-type input의 경우 view의 input 형태가 invalidation surface를 결정합니다. SwiftUI는 value type을 field 단위로 비교하며, 어떤 field든 변경되면 해당 view의 body가 실행됩니다. `let user: User`(struct)로 선언된 view는 이 view가 전혀 읽지 않는 property를 포함해서 `User`의 어떤 property가 교체되더라도 invalidate됩니다. `let name: String`으로 선언된 view는 name이 변경될 때만 invalidate됩니다.

Reference type은 다르게 동작합니다. SwiftUI는 class instance를 field 단위가 아니라 pointer identity로 비교합니다 — class reference를 갖는 view는 parent가 다른 instance를 건네줄 때만 다시 invalidate됩니다. `@Observable` class model의 경우 observation system이 그 위에 한 층을 더합니다: 각 view가 `body` 동안 어떤 property를 읽는지 추적해서, 변경된 그 특정 property를 읽은 view만 invalidate합니다(아래 "@Observable을 사용하는 Model 객체" 참고). 따라서 narrow-inputs 규칙은 value-type input에는 매우 중요하지만, reference-type input에는 대체로 적용되지 않습니다.

### View에는 읽는 데이터만 전달하기

value-type input의 경우, 이는 더 큰 parent에서 추출된 subview뿐 아니라 모든 view에 적용됩니다. struct model 전체를 받아서 그중 한 field만 표시하는 top-level screen view는 해당 struct의 관련 없는 업데이트가 있을 때마다 invalidate됩니다. view가 실제로 사용하는 데이터만 받으세요.

```swift
// AVOID: view가 하나의 field만 읽는데도 (value type인) `User` struct
// 전체를 받는 경우. SwiftUI는 `User`를 field 단위로 비교하므로,
// `AvatarBadge`는 `avatarURL`만 표시함에도 bio 수정, follower count
// 변경, preferences 토글 등 `User`의 어떤 변경에도 invalidate됩니다.
struct User {
    var name: String
    var bio: String
    var avatarURL: URL
    var followerCount: Int
    // ... 더 많은 field
}

struct AvatarBadge: View {
    let user: User

    var body: some View {
        AsyncImage(url: user.avatarURL)
    }
}
```

```swift
// PREFER: view가 실제로 읽는 field만 받습니다.
struct AvatarBadge: View {
    let avatarURL: URL

    var body: some View {
        AsyncImage(url: avatarURL)
    }
}
```

"읽는다"는 "subview로 전달한다"도 포함합니다. `let avatarURL: URL`을 받아서 `AvatarBadge(avatarURL: avatarURL)`에 전달하는 view는 `Text(...)`나 modifier에 직접 나타나지 않더라도 `avatarURL`을 사용하고 있는 것입니다. field를 child에게 전달하는 것도 그 field의 사용입니다. 이 규칙이 대상으로 하는 것은 view가 *진짜로* 전혀 손대지 않는 field(struct input의 읽히지 않는 형제 field)이며, view가 그것을 render하는 child를 구성함으로써 소비하는 field는 대상이 아닙니다. 다섯 개의 field를 받아서 각각을 알맞은 subview로 전달하는 parent는 올바르게 구성된 것이며, "읽지 않는 데이터를 들고 있는" 것이 아닙니다.

### 큰 value-type input의 비용에 주의하기

SwiftUI가 value-type input에 대해 수행하는 field 단위 비교는 공짜가 아닙니다: 모든 input check는 모든 field를 순회합니다. 몇 개의 primitive와 URL 정도로 이루어진 작은 struct라면 비용은 무시할 만합니다. 하지만 큰 JSON payload로부터 decode된 struct — nested array, dictionary, 수십 개의 field — 라면 그 비용이 누적됩니다. parent의 모든 body evaluation은 child가 변경되었는지를 판단하기 위해 전체 payload에 대해 deep comparison을 수행하며, payload를 input으로 받는 모든 subview가 동일한 비용을 지불합니다.

위의 "narrow inputs" 규칙은 이미 이를 완화합니다 — `let title: String`을 받는 subview는 decode된 response 전체를 순회하는 대신 문자열 비교 한 번만 수행합니다.

```swift
// AVOID: 큰 value-type payload를 view tree를 통해 전달하는 경우.
// parent의 모든 body evaluation은 row가 변경되었는지 판단하기 위해
// struct 전체를 이전 값과 deep-compare하며, payload를 input으로 받는
// 모든 subview가 동일한 비용을 지불합니다.
struct Article {
    let id: UUID
    let title: String
    let author: String
    let body: String                  // 50KB+가 될 수 있음
    let comments: [Comment]           // 수백 개가 될 수 있음
    let related: [RelatedArticle]
    let editorialNotes: [Note]
    // ... 더 많은 field
}

struct ArticleRow: View {
    let article: Article

    var body: some View {
        Text(article.title)
    }
}
```

```swift
// PREFER: 전체 payload는 어떤 view에도 존재하지 않습니다. model layer가
// 이를 소유하며(한 번만 `@Observable`로 decode하거나, 더 작은 view별
// struct로 나눔), view는 자신이 render하는 좁은 값만 봅니다. view tree의
// 어떤 것도 `body`, `comments`, `related`에 대한 deep-comparison 비용을
// 지불하지 않습니다.
struct ArticleRow: View {
    let title: String

    var body: some View {
        Text(title)
    }
}
```

#### Payload를 view별 struct로 분리하기

큰 struct의 모든 field가 실제로 view tree 전체에서 소비된다면, 정답은 "그래도 통째로 전달한다"가 아닙니다. payload를 각각 특정 view에 속하는 개별 struct들로 분리해서, 각 view의 비교 surface가 그 view가 실제로 표시하는 것으로 제한되도록 하세요. 앱의 전체 value-type data model을 hierarchy의 모든 view에 대한 input으로 만들지 마세요.

#### 또는 payload를 @Observable model에 담기

큰 value type을 더 작은 것들로 나누고 싶지 않다면 — 보통 그 타입이 server payload에 깔끔하게 대응되어 재구성하면 decoding 전반에 영향이 파급되기 때문에 — 이를 `@Observable` model 안에 넣고 model을 대신 전달하세요. Reference comparison은 (pointer identity이므로) 저렴하며, observation system은 개별적으로 추적되는 property를 읽는 view만 invalidate합니다. 다만 model의 compound stored property에는 주의해야 합니다: 전체 `Array`, `Dictionary`, `Set`을 읽는 view는 *컬렉션 전체*에 대한 dependency를 형성하므로, 어떤 element라도 변경되면 그 view가 invalidate됩니다. 완화 방법은 아래 "@Observable model의 property별 dependency granularity"를 참고하세요 — derived value를 캐시하거나 더 작은 `@Observable` model을 추출해서 각 view에 전달하세요.

## @State를 사용하는 View-local State

- `@State` property는 항상 `private`로 표시하세요. 이미 access control이 지정된 `@State` 변수를 발견한 경우 `private`로 바꾸도록 권장하되, (build를 깨뜨리지 않기 위해) 명시적으로 그렇게 하라는 지시가 없다면 직접 변경하지는 마세요.

## @Observable을 사용하는 Model 객체

view에 데이터를 제공하는 class에는 (`ObservableObject`가 아니라) `@Observable`을 사용하세요. 이 macro는 변경된 property를 실제로 읽는 정확한 view로 invalidation의 범위를 좁히는 per-property observation tracking을 생성하며, 이는 `ObservableObject`의 거친 `objectWillChange` broadcast보다 훨씬 저렴합니다.

프로젝트에 Main Actor default actor isolation이 설정되어 있지 않다면(일반적으로 build settings의 `SWIFT_DEFAULT_ACTOR_ISOLATION`으로 설정) `@Observable` class에 `@MainActor`를 표시하세요. view는 body evaluation 동안 main actor에서 model을 읽습니다; `@MainActor`가 없으면 model의 property는 어떤 thread에서든 접근 가능해지고, background task의 write가 view read와 race할 수 있습니다. Swift 6 strict concurrency는 이를 flag합니다.

`@Observable`은 `actor` 타입에서는 지원되지 않습니다.

```swift
// AVOID: @MainActor가 없는 @Observable class. property는 어떤 thread에서든
// 접근 가능하지만, view는 main actor에서 이를 읽습니다 — background
// write가 main-actor read와 race할 수 있고, strict concurrency가 이
// model을 flag할 것입니다.
@Observable
final class OrderModel {
    var status: DeliveryStatus = .placed
}
```

```swift
// PREFER: @Observable class에 @MainActor를 지정. read와 write가 main
// actor로 한정되어, view가 model을 소비하는 방식과 일치합니다.
// 새 값을 만드는 background 작업은 main actor로 hop합니다
// (예: `await MainActor.run { model.status = .shipped }`).
@MainActor
@Observable
final class OrderModel {
    var status: DeliveryStatus = .placed
}
```

### @Observable property 타입을 Equatable로 만들기

`@Observable` model 객체의 stored property 타입은 `Equatable`을 준수하도록 만드는 것을 선호하세요. `@Observable` macro는 새 값이 현재 값과 같을 때 invalidation을 건너뛰는 setter를 생성합니다 — 하지만 이는 오직 두 값을 비교할 수 있을 때, 즉 타입이 `Equatable`일 때만 가능합니다. 이 conformance가 없으면 새 값이 동일하더라도 모든 set이 notify를 발생시킵니다. 이는 (polling, streaming update, timer 등으로) 동일한 값이 자주 write되는 property에 대해 손쉽게 얻을 수 있는 성능 이점입니다.

이는 현재 Xcode로 빌드할 때 `@Observable`을 지원하는 모든 OS release(iOS 17 / macOS 14 및 그에 대응하는 release)에 적용됩니다 — equality check는 runtime 기능에 위임되는 것이 아니라 user code로서 생성된 setter에 emit됩니다.

```swift
// AVOID: DeliveryStatus가 Equatable이 아님.
// 값이 실제로 바뀌지 않았어도 `status`에 대한 모든 대입이 observing
// view를 invalidate합니다.
enum DeliveryStatus {
    case placed, preparing, shipped, delivered
}

@MainActor
@Observable
final class OrderModel {
    var status: DeliveryStatus = .placed
}
```

```swift
// PREFER: DeliveryStatus를 Equatable로 만들면 같은 status가 다시
// set되었을 때 @Observable setter가 불필요한 invalidation을
// short-circuit할 수 있습니다.
enum DeliveryStatus: Equatable {
    case placed, preparing, shipped, delivered
}

@MainActor
@Observable
final class OrderModel {
    var status: DeliveryStatus = .placed
}
```

동일한 원칙이 collection property에도 적용됩니다. property가 `Array`(또는 `Set`, `Dictionary` 등)인 경우, collection의 `Equatable` conformance는 자신의 element에 위임됩니다. element 타입이 `Equatable`이 아니면 collection도 마찬가지이므로, 내용이 동일하더라도 collection에 대한 모든 대입이 invalidation을 유발합니다.

```swift
// AVOID: Ingredient가 Equatable이 아니어서, `recipe.ingredients`에 같은
// ingredient 배열을 대입해도 항상 observing view를 invalidate합니다.
struct Ingredient {
    var name: String
    var quantity: Double
    var unit: String
}

@MainActor
@Observable
final class RecipeModel {
    var ingredients: [Ingredient] = []
}
```

```swift
// PREFER: Ingredient를 Equatable로 만들면 Array의 내장 Equatable
// conformance가 element 단위로 비교할 수 있게 되어, 같은 ingredient가
// 다시 set되었을 때 @Observable setter가 불필요한 invalidation을
// 건너뜁니다.
struct Ingredient: Equatable, Identifiable {
    var name: String
    var quantity: Double
    var unit: String
}

@MainActor
@Observable
final class RecipeModel {
    var ingredients: [Ingredient] = []
}
```

### @Observable model의 property별 dependency granularity

view가 `@Observable` model의 property를 읽으면, observation system은 정확히 그 property에 대한 dependency를 기록하고 *그* property가 변경될 때만 view를 invalidate합니다. 따라서 `model.title`을 읽는 view는 `title`이 변경될 때 invalidate되지만 `model.description`이 변경될 때는 invalidate되지 않습니다 — 이러한 per-property tracking이 `@Observable`이 granular update에서 `ObservableObject`보다 훨씬 저렴한 주된 이유입니다.

미묘한 점은 granularity가 "property" 단위이지 "property 내부의 field" 단위가 아니라는 것입니다. 타입 자체가 compound인 property — struct, `Array`, `Dictionary`, `Set` — 는 *전체 값*에 대한 dependency를 만듭니다. stored struct의 어떤 field를 읽거나 stored collection의 어떤 element를 읽더라도 전체 stored property에 대한 dependency가 형성됩니다. 아래 하위 섹션들은 이 함정의 흔한 형태들을 다룹니다.

Computed property 역시 여전히 전이적으로 dependency를 형성합니다: computed `var selectedItem: Item? { items.first { $0.id == selectedID } }`는 body 내부에서 `items`를 읽으므로, `model.selectedItem`을 읽는 어떤 view든 결국 `items`에 대한 dependency를 갖게 됩니다. access 방식의 이름을 바꾼다고 해서 observation이 추적하는 대상이 바뀌지는 않습니다. 해결책은 derived value를 별도의 stored property로 캐시하고 동기화를 유지하는 것입니다.

### Derived @Observable 값 캐시하기; computed property도 여전히 전이적으로 dependency를 형성함

```swift
// AVOID: 하나의 item만 필요한 view가 전체 collection을 통해 그것에
// 접근하는 경우. `users`에 대한 모든 변경 — 추가, 삭제, 어떤 user의
// 어떤 field 수정 — 이 `CurrentUserBadge`를 invalidate합니다.
@MainActor
@Observable
final class AppState {
    var users: [User] = []
    var currentUserID: User.ID?
}

struct CurrentUserBadge: View {
    let state: AppState

    var body: some View {
        if let id = state.currentUserID,
           let user = state.users.first(where: { $0.id == id }) {
            Text(user.name)
        }
    }
}
```

```swift
// AVOID (동작하지 않는 시도): lookup을 computed property로 감싸면
// dependency를 좁히는 것처럼 *보이지만*, computed body가 `users`를
// 읽으므로 `state.currentUser`는 전이적으로 배열 전체에 대한 dependency를
// 형성합니다. access 방식의 이름을 바꾼다고 observation이 추적하는
// 대상이 바뀌지는 않습니다.
@MainActor
@Observable
final class AppState {
    var users: [User] = []
    var currentUserID: User.ID?

    var currentUser: User? {
        users.first { $0.id == currentUserID }
    }
}

struct CurrentUserBadge: View {
    let state: AppState

    var body: some View {
        if let user = state.currentUser {
            Text(user.name)
        }
    }
}
```

```swift
// PREFER: derived value를 별도의 stored property로 캐시하고 didSet에서
// 최신 상태로 유지합니다. view는 준비된 property를 읽고 *그것이*
// 변경될 때만 invalidate됩니다 — `users`의 모든 변경마다가 아니라.
@MainActor
@Observable
final class AppState {
    var users: [User] = [] {
        didSet { recomputeCurrentUser() }
    }
    var currentUserID: User.ID? {
        didSet { recomputeCurrentUser() }
    }

    private(set) var currentUser: User?

    private func recomputeCurrentUser() {
        currentUser = users.first { $0.id == currentUserID }
    }
}

struct CurrentUserBadge: View {
    let state: AppState

    var body: some View {
        if let user = state.currentUser {
            Text(user.name)
        }
    }
}
```

### 많은 view가 데이터를 공유할 때는 더 작은 @Observable로 추출하기

어떤 데이터가 많은 독립적인 view에서 읽히거나, 서로 invalidation이 격리되어야 하는 view들에서 읽힌다면, 이를 별도의 `@Observable` model로 뽑아내서 더 큰 model 대신 더 작은 이 model을 각 view에 전달하세요. 그러면 view의 dependency surface는 더 작은 model로 제한되고, 더 큰 model은 파급 효과 없이 변경될 수 있습니다.

### 여러 개의 개별 @Observable property를 읽는 것은 문제없음

하나의 `@Observable` model에서 여러 개별 property를 읽는 view는 over-subscribed된 것이 **아니며** 분리할 필요가 없습니다. per-property tracking이 이미 view의 invalidation을 정확히 그 property들로 범위를 좁혀두었으므로, model을 property별 subview로 쪼개는 것은 언제 무엇이 재실행되는지를 바꾸지 않으면서 indirection만 추가합니다. 이 문서의 granularity 함정들은 너무 많은 것을 끌어들이는 *단일* read에 관한 것입니다 — struct 전체를 끌어들이는 struct-typed field, collection 전체를 끌어들이는 array access, 동일하게 넓은 read를 대리하는 computed property. 이미 충분히 좁은 여러 property를 정당하게 읽는 view에 관한 것이 아닙니다.

### @Observable collection의 element를 row view에 직접 전달하기

`@Observable` model의 collection을 iterate할 때, `ForEach`를 갖는 list view는 collection에 정당하게 의존합니다 — element가 삽입, 삭제, 재정렬될 때 재실행되어야 하기 때문입니다. 하지만 row view가 자신의 element를 index나 key로 model에 다시 접근해서 찾아서는 안 됩니다: 그렇게 하면 모든 row가 collection 전체에 의존하게 되어, 한 user를 수정하면 모든 row가 invalidate됩니다. element 값을 row에 직접 전달하세요.

#### Single-field row: field를 전달하기

```swift
// AVOID: row가 index로 model에 다시 접근합니다. 모든 UserRow의 body가
// `state.users`를 읽으므로, 어떤 user에 대한 수정이든 변경된 그 user의
// row뿐 아니라 모든 row를 invalidate합니다.
struct UserList: View {
    let state: AppState

    var body: some View {
        ForEach(state.users.indices, id: \.self) { index in
            UserRow(state: state, index: index)
        }
    }
}

struct UserRow: View {
    let state: AppState
    let index: Int

    var body: some View {
        Text(state.users[index].name)
    }
}
```

```swift
// PREFER: row에는 표시할 field만 전달합니다. `UserList`는
// `state.users`에 의존하지만(list의 형태가 이에 의존하므로 맞습니다),
// 각 `UserRow`는 자신이 render하는 name만 받습니다. 한 user의 email을
// 수정해도 어떤 row의 body도 재실행되지 않습니다; 한 user의 name을
// 수정하면 그 row만 재실행됩니다.
struct UserList: View {
    let state: AppState

    var body: some View {
        ForEach(state.users) { user in
            UserRow(name: user.name)
        }
    }
}

struct UserRow: View {
    let name: String

    var body: some View {
        Text(name)
    }
}
```

#### Multi-field row: persist된 @Observable instance를 전달하기

각 row가 element의 여러 field를 실제로 observe하는 경우에 유용한 대안 패턴은, 각 element를 자체 `@Observable`로 모델링하고 parent가 그 instance들을 **persist**하게 하는 것입니다. list view는 여전히 reference 배열에 의존하므로(삽입, 삭제, 재정렬 시 재실행됩니다), 각 row의 dependency는 자신의 model로 범위가 좁혀집니다 — row는 collection 전체나 struct 전체에 의존하지 않고도 자신의 user의 여러 property를 observe할 수 있으며, 한 user의 한 field를 수정하면 그 user를 표시하는 row만 invalidate됩니다.

instance는 반드시 persist되어야 합니다. read할 때마다 새로 생성한 `@Observable`을 건네주면 parent의 body evaluation마다 각 row에 새 reference를 주게 되고, stored reference는 매번 다르게 비교되어 모든 row의 body가 재실행되지만 실제로는 아무것도 바뀌지 않은 상태가 됩니다.

```swift
// PREFER (multi-field row): parent가 저장하고 재사용하는 element별
// @Observable model. `UserRow`는 자신의 특정 user를 직접 observe하므로,
// 한 user의 한 field를 수정하면 그 row만 invalidate됩니다 — 그리고
// row는 collection 전체 비용을 지불하지 않고도 여러 field를 읽을 수
// 있습니다.
@MainActor
@Observable
final class User: Identifiable {
    let id: UUID
    var name: String
    var email: String
    var avatarURL: URL

    init(id: UUID = UUID(), name: String, email: String, avatarURL: URL) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
    }
}

@MainActor
@Observable
final class AppState {
    var users: [User] = []  // persist됨; 각 User의 identity는 안정적
    // ... 변경은 기존 User instance를 in place로 수정함
}

struct UserList: View {
    let state: AppState

    var body: some View {
        ForEach(state.users) { user in
            UserRow(user: user)
        }
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                Text(user.email).font(.caption)
            }
        }
    }
}
```

### Struct field를 개별 @Observable property로 노출하기

`@Observable` model이 value-type struct를 stored property로 가지고 있을 때, observation system은 *property* 수준에서 read를 추적합니다 — struct의 field 수준이 아닙니다. `session.user.name`을 읽는 view는 `session.user`에 의존합니다. `user`의 어떤 field를 수정하거나 새로운 `User` 값으로 교체하면, `name`만 표시했던 view까지 포함해서 이를 건드린 모든 view가 invalidate됩니다.

해결책은 struct의 field를 `@Observable` model의 개별 property로 노출하는 것입니다. observation system은 각 field를 별도로 추적하며, `userName`만 읽는 view는 `userName`이 변경될 때만 invalidate됩니다.

```swift
// AVOID: User struct가 @Observable model의 단일 property로 저장된
// 경우. `ProfileBadge`는 `session.user.name`, `session.user.email`,
// `session.user.avatarURL`을 읽는데 — 이 read들 각각이 `session.user`에
// 대한 dependency를 형성합니다. `preferences`를 수정해도(또는 `user`의
// 다른 어떤 field라도) view가 invalidate됩니다.
struct User {
    var name: String
    var email: String
    var avatarURL: URL
    var preferences: Preferences
}

@MainActor
@Observable
final class UserSession {
    var user: User

    init(user: User) { self.user = user }
}

struct ProfileBadge: View {
    let session: UserSession

    var body: some View {
        HStack {
            AsyncImage(url: session.user.avatarURL)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(session.user.name).font(.headline)
                Text(session.user.email).font(.caption)
            }
        }
    }
}
```

```swift
// PREFER: struct의 field를 model에 flatten합니다. 각 field가
// 독립적으로 추적됩니다. `ProfileBadge`는 `userName`, `userEmail`,
// `avatarURL`에 의존하지만 `preferences`에는 의존하지 않으므로,
// preferences를 수정해도 더 이상 invalidate되지 않습니다.
@MainActor
@Observable
final class UserSession {
    var userName: String
    var userEmail: String
    var avatarURL: URL
    var preferences: Preferences

    init(user: User) {
        self.userName = user.name
        self.userEmail = user.email
        self.avatarURL = user.avatarURL
        self.preferences = user.preferences
    }
}

struct ProfileBadge: View {
    let session: UserSession

    var body: some View {
        HStack {
            AsyncImage(url: session.avatarURL)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(session.userName).font(.headline)
                Text(session.userEmail).font(.caption)
            }
        }
    }
}
```

struct를 round-trip해야 하고(payload로 다시 encode해서 server로 보내야 하는 등) 그 형태를 잃고 싶지 않다면, 둘 다 유지하세요: round-trip을 위한 `var user: User`와, view 소비를 위한 개별 property들을 두고 `user`의 `didSet`을 통해 동기화하세요.

## View에서의 Side Effect

### onChange(of:)의 side-effect invalidation 분리하기

view가 dependency(`@Environment` 값, `@Binding`, 또는 `@Observable` 객체의 property)에 반응하기 위해 `.onChange(of:)`를 사용하면, 그 dependency는 view의 body scope에서 읽힙니다. 이는 그 값에 대한 dependency를 만듭니다: dependency가 rendering에 사용되지 않더라도 그것이 변경될 때마다 view의 body가 다시 evaluate됩니다.

view의 body가 비용이 큰 경우(deep hierarchy, 많은 child) 이는 불필요한 작업을 유발합니다. `.onChange`와 그것이 observe하는 dependency를 그 side effect만 처리하는 별도의 view로 추출하세요. 이렇게 하면 값이 변경될 때 가벼운 side-effect view만 다시 evaluate됩니다.

```swift
// AVOID: ContentView가 오직 .onChange를 위해 environment에서 `counter`를
// 읽습니다. `counter`가 변경될 때마다 dependency가 생성되고 비용이 큰
// ScrollView hierarchy가 다시 evaluate됩니다.
struct ContentView: View {
    @State private var model = Model()
    @Environment(\.counter) private var counter

    var body: some View {
        ScrollView {
            // ... 비용이 큰 view hierarchy ...
        }
        .onChange(of: counter) {
            model.counter = counter
        }
    }
}
```

```swift
// PREFER: dependency와 .onChange를 ViewModifier로 추출합니다.
// modifier가 `counter`의 read를 소유합니다 — counter가 변경되면
// ContentView의 body가 아니라 modifier의 body만 재실행됩니다. host
// view의 dependency surface에는 `counter`가 전혀 포함되지 않습니다.
struct CounterSyncModifier: ViewModifier {
    let model: Model
    @Environment(\.counter) private var counter

    func body(content: Content) -> some View {
        content
            .onChange(of: counter) {
                model.counter = counter
            }
    }
}

extension View {
    func counterSync(model: Model) -> some View {
        modifier(CounterSyncModifier(model: model))
    }
}

struct ContentView: View {
    @State private var model = Model()

    var body: some View {
        ScrollView {
            // ... 비용이 큰 view hierarchy ...
        }
        .counterSync(model: model)
    }
}
```

동일한 원칙이 어떤 dependency 타입에도 적용됩니다 - `@Binding`, `@Observable` property, 또는 이들의 조합:

```swift
// AVOID: EditorView가 오직 side effect를 위해 `document.wordCount`와
// `isActive`를 모두 읽습니다. 둘 중 하나만 바뀌어도 비용이 큰 editor
// body가 다시 evaluate됩니다.
struct EditorView: View {
    var document: DocumentModel
    @Binding var isActive: Bool
    @State private var model = EditorModel()

    var body: some View {
        ScrollView {
            // ... 비용이 큰 text editor hierarchy ...
        }
        .onChange(of: document.wordCount) {
            model.updateStatistics(wordCount: document.wordCount)
        }
        .onChange(of: isActive) {
            model.setActive(isActive)
        }
    }
}
```

```swift
// PREFER: 두 side effect를 하나의 ViewModifier로 추출합니다.
struct EditorChangesModifier: ViewModifier {
    var document: DocumentModel
    @Binding var isActive: Bool
    let model: EditorModel

    func body(content: Content) -> some View {
        content
            .onChange(of: document.wordCount) {
                model.updateStatistics(wordCount: document.wordCount)
            }
            .onChange(of: isActive) {
                model.setActive(isActive)
            }
    }
}

extension View {
    func editorChanges(
        document: DocumentModel,
        isActive: Binding<Bool>,
        model: EditorModel
    ) -> some View {
        modifier(
            EditorChangesModifier(
                document: document,
                isActive: isActive,
                model: model
            )
        )
    }
}

struct EditorView: View {
    var document: DocumentModel
    @Binding var isActive: Bool
    @State private var model = EditorModel()

    var body: some View {
        ScrollView {
            // ... 비용이 큰 text editor hierarchy ...
        }
        .editorChanges(document: document, isActive: $isActive, model: model)
    }
}
```

다음 조건이 모두 성립할 때 이 패턴을 적용하세요:
- dependency가 rendering이 아니라 오직 side effect(`.onChange`)를 위해서만 읽힐 때.
- parent view가 다시 evaluate하기에 비용이 큰, non-trivial한 body를 가지고 있을 때.

다음의 경우에는 이 패턴을 적용하지 마세요:
- dependency가 view의 rendering 출력에도 직접 사용되는 경우. view는 어차피 invalidate되므로 분리해도 이점이 없습니다.
- view body가 이미 trivial한 경우. 추가 view의 오버헤드가 정당화되지 않습니다.

## Binding

### Closure binding 대신 KeyPath binding 사용하기

closure 기반의 get-set binding 대신 subscript를 사용하는 KeyPath 기반 Binding을 항상 선호하세요. 다음 model과 child view를 살펴보세요:

```swift
@Observable
final class ScoreboardModel {
    private(set) var scores: [String: Int] = [
        "Alice": 42, "Bob": 17, "Carol": 99,
    ]

    let players = ["Alice", "Bob", "Carol"]

    // labeled argument를 가진 subscript는, 그것에 대한 Binding이
    // 주어지면 기저 model로의 functional 'projection'처럼 사용될 수
    // 있습니다.
    subscript(scoreFor player: String) -> Int {
        get { scores[player, default: 0] }
        set { scores[player] = newValue }
    }
}

/// score에 대한 two-way binding을 갖는 기본 view.
struct PlayerScoreRow: View {
    var player: String
    @Binding var score: Int

    var body: some View {
        HStack {
            Text(player)
                .frame(width: 80, alignment: .leading)
            Stepper("\(score) pts", value: $score, in: 0...999)
        }
    }
}
```

`PlayerScoreRow`의 binding을 만들기 위해 closure를 사용하지 마세요. 대신 subscript를 거치는 binding을 사용하세요. 기존에 subscript가 없다면 하나를 만들어야 할 수도 있습니다.

```swift
/// Parent view.
struct ScoreboardView: View {
    @State private var model = ScoreboardModel()

    var body: some View {
        NavigationStack {
            List(model.players, id: \.self) { player in
                // ❌ BAD: closure를 생성하면 `body`가 실행될 때마다 새로운
                // heap allocation이 발생하며, 비교 문제를 일으켜 불필요한
                // invalidation을 유발할 수 있습니다.
                let badModelBinding = Binding(
                    get: { model[scoreFor: player] }
                    set: { model[scoreFor: player] = newValue }
                )
                PlayerScoreRow(player: player, score: badModelBinding)

                // ✅ GOOD: labeled argument를 가진 subscript는, 그것에
                // 대한 Binding이 주어지면 기저 model로의 functional
                // 'projection'처럼 사용될 수 있습니다.
                @Bindable var model = model
                PlayerScoreRow(player: player, score: $model[scoreFor: player])
            }
            .navigationTitle("Scoreboard")
        }
    }
}
```

# `@Entry` macro

custom environment, transaction, container, 또는 focused value를 정의할 때는 boilerplate code를 줄이고 실수를 피하기 위해 항상 `@Entry` 사용을 선호하세요.

`@Entry`는 stable한 default를 요구합니다 — 즉 표현식이 매 read마다 동일한 결과를 반환해야 합니다. 전체 규칙, 피해야 할 unstable한 형태(`Model()`, `Date()`, `UUID()`, 새로운 allocation, 캡처된 runtime 값), 그리고 세 가지 수정 형태(Option A: `static let` backing; Option B: `static let defaultValue`를 갖는 manual `EnvironmentKey`; Option C: `nil` default를 갖는 optional)는 `environment.md`의 "Unstable Environment Default Values" 부분을 참고하세요. 동일한 규칙이 `Transaction`, `ContainerValues`, `FocusedValues`의 `@Entry`에도 적용됩니다. 이러한 수정이 필요 없는 stable한 default 형태로는 literal(`"home"`, `0`, `true`), associated value가 없는 enum case(`.standard`), optional에 대한 `nil`, 그리고 stable한 instance(`static let`, module-level `let`, 또는 그것을 캡처하는 struct)에 대한 reference가 있습니다. `@Entry` 선언을 review하거나 작성할 때는, 다른 무엇보다 먼저 default 표현식을 이 규칙에 따라 확인하세요.

custom environment, transaction, container value는 관련된 구조체(structure)를 새로운 property로 extension하고 variable 선언에 `@Entry` macro를 붙여서 만드세요:

```swift
extension EnvironmentValues {
    @Entry var myCustomValue: String = "Default value"
    @Entry var anotherCustomValue = true
}

extension Transaction {
    @Entry var myCustomValue: String = "Default value"
}

extension ContainerValues {
    @Entry var myCustomValue: String = "Default value"
}
```

`FocusedValues`의 default 값은 항상 nil이므로, `FocusedValues`의 entry는 다른 default 값을 지정할 수 없고 반드시 Optional 타입이어야 합니다:

```swift
extension FocusedValues {
    @Entry var myCustomValue: String?
}
```

manual한 `EnvironmentKey` / `ContainerValuesKey` / `FocusedValueKey` conformance와 `get`/`set` extension property를 통해 custom environment, transaction, container, 또는 focused value를 정의하는 기존 코드를 review할 때는, `@Entry` refactor를 top-line review finding으로 제시하세요 — footnote가 아니라, "Optional Improvements" 같은 부수적인 언급이 아니라, "괜찮아 보이지만, 추가로 고려해볼 만한…" 식의 꼬리말이 아니라. manual한 형태는 `@Entry`가 대체하기 위해 특별히 설계된 더 오래된 boilerplate입니다; 이 둘을 스타일상의 우열이 없는 선택으로 취급하는 것은 잘못되었습니다. deployment target이 availability를 gate합니다(`@Entry`는 iOS 18 / macOS 15 / Xcode 16을 요구합니다); review 대상 코드에서 target이 명시되지 않은 경우, 방어적인 hedge 없이 refactor를 권장하세요 — availability는 많아야 한 줄의 caveat으로만 언급하세요. (review 중에 요청받지 않은 rewrite를 수행하지 마세요 — diff나 refactor된 snippet을 finding으로 제시하세요.)
