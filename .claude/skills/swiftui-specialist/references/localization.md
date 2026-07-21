# String Catalogs

대부분의 프로젝트는 String Catalogs(`.xcstrings`)를 통해 localization을 수행합니다. 빌드할 때마다 코드의 새로운 문자열이 catalog로 동기화되지만, catalog 파일은 미리 존재해야 합니다 — Xcode가 자동으로 생성해 주지는 않습니다. 프로젝트가 이미 `.strings`나 `.stringsdict` 파일을 사용하고 있다면, 사용자에게 마이그레이션을 요청하기보다는 기존 파일에 새 문자열을 추가하세요.

프로젝트는 여러 개의 String Catalogs를 사용할 수 있으며, `tableName` 매개변수로 문자열을 특정 catalog로 라우팅할 수 있습니다 — 문자열 그룹을 분리해서 관리하는 것이 합리적일 때 유용합니다(예: feature 또는 module 단위).

```swift
Text("Explore", tableName: "Navigation",
     comment: "Tab bar item title for the Explore screen.")
```

# Swift Package와 Framework를 위한 Bundle

App, app extension, XPC service는 각각 자신만의 main bundle이므로 `bundle` 매개변수를 생략할 수 있습니다. Framework와 Swift package는 명시적인 `bundle`이 필요합니다. 이를 지정하지 않으면 SwiftUI가 `Bundle.main`에서 문자열을 조회하며, 이 조회는 조용히 실패합니다 — 런타임에 해당 문자열은 localize되지 않은 상태로 나타납니다.

```swift
// AVOID: Inside a framework or Swift package, this searches the app's catalog.
Text("Save to Favorites")
```

```swift
// PREFER: #bundle resolves to the current target's bundle.
Text("Save to Favorites", bundle: #bundle,
     comment: "Button to bookmark a recipe.")
```

`#bundle`이 선호되는 형태입니다. `Bundle.module`과 `Bundle(for: MyClass.self)`도 동작하지만 더 오래된 pattern입니다.

# SwiftUI View는 String Literal을 자동으로 Localize한다

`LocalizedStringKey`를 받는 SwiftUI initializer(예: `Text`, `Button`, `.navigationTitle`)는 string literal을 localization key로 자동 처리합니다. literal을 `NSLocalizedString`, `String(localized:)`, `LocalizedStringResource`로 감쌀 필요가 없습니다.

```swift
// AVOID: Text already treats literals as LocalizedStringKey; wrapping
// also resolves the string eagerly, ignoring \.locale overrides.
Text(NSLocalizedString("start_workout", comment: ""))
Text(String(localized: "start_workout"))
```

```swift
// PREFER: Pass the string literal directly.
Text("start_workout")
```

opaque key(`"start_workout"`)와 natural-language 문자열(`"Start Workout"`) 모두 `LocalizedStringKey` 값으로 동작합니다. 프로젝트에서 일관되게 사용하는 convention을 선택하면 됩니다 — opaque key를 쓰는 경우, source-language 텍스트는 호출 지점이 아니라 String Catalog에 직접 설정합니다.

string literal에 대해 localization을 사용하지 않으려면 `Text(verbatim:)`을 사용하세요 — 가장 흔한 경우는 런타임 값을 interpolation하는 디버그 라벨입니다(예: `Text(verbatim: "Session: \(sessionID)")`). 이런 literal은 그렇지 않으면 localization key로 처리되어 버립니다. argument가 이미 `String` 타입 variable인 경우에는 `Text(value)`가 `StringProtocol` overload를 호출하여 자체적으로 localization을 건너뛰므로 `verbatim:`이 필요하지 않습니다.

# Variable과 Custom Type Localize하기

`String` 타입 variable을 `Text`에 전달하면 `StringProtocol` overload가 실행되며 해당 문자열은 localize되지 않습니다. 호출 지점에서 variable을 `LocalizedStringKey(_:)`로 감싸는 것도 도움이 되지 않습니다 — Xcode는 런타임 값에서 literal을 추출할 수 없으므로 해당 항목은 catalog에 결코 반영되지 않습니다. 알려진 key 집합 중에서 선택된 값을 localize하려면, `LocalizedStringResource`를 노출하는 type으로 그 집합을 모델링하세요.

```swift
enum Category {
    case appetizers, mains, desserts
    var name: LocalizedStringResource {
        switch self {
        case .appetizers: "Appetizers"
        case .mains: "Mains"
        case .desserts: "Desserts"
        }
    }
}

Text(category.name)
```

view나 view model이 user-facing 텍스트를 노출할 때는, property의 타입을 `String` 대신 `LocalizedStringKey`나 `LocalizedStringResource`로 지정하세요. localize된 텍스트를 받는 모든 SwiftUI view는 이 두 타입을 모두 받아들이므로, resolution을 지연시켜도 표시 지점에서 비용이 들지 않으며 locale과 bundle context가 끝까지 보존됩니다.

```swift
// AVOID: String properties lose localization context.
struct SectionHeader {
    let title: String
}
```

```swift
// PREFER: LocalizedStringResource keeps the string localizable.
struct SectionHeader {
    let title: LocalizedStringResource
}
```

# String Interpolation vs Concatenation

String interpolation은 `LocalizedStringKey`를 보존하며 catalog 내에 format string을 생성합니다(예: `"Welcome, %@"`). `+`를 이용한 concatenation은 `String`을 생성하며 — 그 결과는 localize되지 않습니다.

```swift
// AVOID: + produces String, not LocalizedStringKey. Not localized.
Text("Error: " + statusMessage)
```

```swift
// PREFER: Interpolation preserves LocalizedStringKey.
Text("Error: \(statusMessage)")
```

별도로 localize된 조각들을 이어붙여 하나의 문장을 만들지 마세요 — 언어마다 어순이 다릅니다.

```swift
// AVOID: Sentence assembly breaks in languages with different word order.
Text(String(localized: "Created by")) + Text(" ") + Text(authorName)
```

```swift
// PREFER: A single string lets translators rearrange the structure.
Text("Created by \(authorName)")
```

# Casing

원하는 대소문자를 `.textCase(_:)`, `.localizedUppercase`, `.localizedCapitalized` 같은 런타임 transform으로 처리하지 말고, 문자열 자체에 원하는 casing을 미리 반영하세요. 런타임 transform은 모든 번역에 대해 동일한 casing 결정을 강제하기 때문에, translator가 언어별로 조정할 방법이 없어집니다.

```swift
// AVOID: forces the same casing on every translation.
Text("Section Header").textCase(.uppercase)

// PREFER: provide the desired case in the string itself.
Text("SECTION HEADER")
```

이는 localize된 문자열에 해당하는 이야기입니다. 사용자가 직접 입력한 문자열은 그대로 표시해야 합니다 — 사용자가 어떤 casing을 의도했는지 알 수 없기 때문입니다. transform이 불가피한 경우에는, 사용자의 locale을 존중하는 `.localizedUppercase` / `.localizedCapitalized`를 사용하세요(터키어의 dotted/dotless I, 독일어의 ß 등).

# Date, Number, Currency Formatting

하드코딩된 format string을 사용하는 `DateFormatter`나 `NumberFormatter` 대신 `Text`의 `format` 매개변수 또는 `.formatted()`를 사용하세요. format style은 사용자의 locale에 맞춰 적응하지만, 하드코딩된 format string은 그렇지 않습니다. 이러한 overload는 format style을 통해 localize되는 것이며 — localization을 회피하는 수단이 아닙니다. 다만 값 자체가 catalog entry를 생성하지는 않습니다. 값이 localize된 literal 안에 interpolate될 때(예: `"Total: \(price, format: ...)"`), 그 literal은 여전히 평소처럼 `comment:`를 받을 수 있습니다.

```swift
// AVOID: Hardcoded format does not adapt to locale.
let formatter = DateFormatter()
formatter.dateFormat = "MM/dd/yyyy"
Text(formatter.string(from: workout.date))
```

```swift
// PREFER: Format styles adapt to the user's locale automatically.
Text(workout.date, format: .dateTime.month().day().year())
```

date field component(`.month()`, `.day()`, `.year()`)는 어떤 field가 나타날지를 결정할 뿐이며, 출력 순서는 locale이 결정합니다 — chain의 순서가 layout을 고정하지 않습니다.

```swift
// AVOID: Hardcoded currency formatting.
Text("$\(product.price, specifier: "%.2f")")
```

```swift
// PREFER
Text(product.price, format: .currency(code: store.currencyCode))
```

문자열 목록의 경우, 하드코딩된 `joined(separator: ", ")` 대신 `Array.formatted()`가 locale에 맞는 구분자와 접속사를 삽입해 줍니다.

```swift
// AVOID
Text("Order: \(items.joined(separator: ", "))")
```

```swift
// PREFER
Text("Order: \(items.formatted())")
```

`DateFormatter`가 정말로 불가피한 경우에는, `dateFormat`을 직접 지정하는 대신 `setLocalizedDateFormatFromTemplate(_:)`를 사용하세요 — 이 template은 locale에 따라 field 순서를 재배열합니다.

# Localization을 위한 Layout

`.left`와 `.right` 대신 `.leading`과 `.trailing`을 사용하세요 — 이들은 right-to-left locale에서 뒤집히지만, `.left`와 `.right`는 그렇지 않습니다.

```swift
// AVOID: .left does not flip for RTL languages.
Text(recipe.title)
    .frame(maxWidth: .infinity, alignment: .left)
```

```swift
// PREFER: .leading flips to the trailing edge in RTL locales.
Text(recipe.title)
    .frame(maxWidth: .infinity, alignment: .leading)
```

텍스트에 대해 frame의 width나 height를 하드코딩하지 마세요 — 번역에 따라 길이가 달라지고, script에 따라 높이도 달라집니다. 더 긴 번역에 layout이 맞지 않을 수 있는 경우에는 `ViewThatFits`를 사용하세요.

```swift
// PREFER: ViewThatFits picks the first layout that fits.
ViewThatFits {
    HStack { actionButtons }
    VStack { actionButtons }
}
```

고정된 point size 대신 SwiftUI의 text style을 사용하세요. text style은 script별로 line height가 적응하도록 해주지만, 고정된 point size는 키가 큰 script의 glyph를 자를 수 있습니다.

```swift
// AVOID: fixed point size locks line height.
Text("Welcome").font(.system(size: 17))

// PREFER: text styles let line height adapt per script.
Text("Welcome").font(.body)
```

# 현재 Locale 읽기

view 내에서 locale에 의존하는 로직을 처리할 때는 `Locale.current` 대신 `@Environment(\.locale)`을 사용하세요 — environment는 preview override와 view별 injection을 존중하지만, `Locale.current`는 그렇지 않습니다.

# SwiftUI View 외부에서 String(localized:) 사용하기

SwiftUI view 외부에서 localize된 `String`이 필요할 때는 `NSLocalizedString`이 아니라 `String(localized:)`를 사용하세요.

```swift
// AVOID
let title = NSLocalizedString("activity_summary", comment: "Dashboard header")
```

```swift
// PREFER
let title = String(localized: "activity_summary", comment: "Dashboard header")
```

`NSLocalizedString` 내부에서 interpolation을 사용하지 마세요 — Xcode는 build time에 literal 문자열에서 key를 추출하며, interpolate된 값은 추출할 수 없습니다. 대신 interpolation과 함께 `String(localized:)`를 사용하세요. Xcode는 format string을 추출하고(예: `"reminder_body %@"`), interpolate된 값은 런타임 argument로 처리합니다.

`String(format:)`과 `String.localizedStringWithFormat`보다 `String(localized:)`를 선호하세요. `String(format:)`은 locale과 무관하게 항상 숫자를 0–9로 렌더링하므로 user-facing 텍스트에 적합하지 않습니다. `String.localizedStringWithFormat`은 `NSLocalizedString`과 함께 사용할 때는 동작하지만, `String(localized:)`가 현대적인 API이며 올바른 기본 선택입니다.

# Non-View Type을 위한 LocalizedStringResource

model object, tip, 대기 중인 notification 등 non-view type이 user-facing 문자열을 가지고 있을 때는 `String` 대신 `LocalizedStringResource`를 사용하세요. 이 문자열은 생성 시점이 아니라 표시 시점에 resolve되므로, 값이 실제로 렌더링될 때 활성화된 locale을 존중합니다. `String`이 view model, module 사이에서 전달되거나 view로 전달될 상황이라면, `LocalizedStringResource`가 올바른 타입입니다. 이는 새로운 type을 설계하거나 user-facing 텍스트를 변경할 때 적용하세요 — 관련 없는 편집을 하면서 기존 `String` property를 일괄적으로 바꾸지는 마세요.

```swift
// AVOID: Resolving at creation time loses the ability to display
// in a different locale later.
struct Tip {
    let headline: String
}
let tip = Tip(headline: String(localized: "Tip of the Day"))
```

```swift
// PREFER: LocalizedStringResource defers resolution to display time.
struct Tip {
    let headline: LocalizedStringResource
}
let tip = Tip(headline: "Tip of the Day")
```

# Translator를 위한 Comment

UI 요소와 그 목적을 설명하는 `comment`를 추가하세요. 특히 모호한 문자열의 경우 더욱 그렇습니다. interpolate된 문자열의 경우, 각 placeholder를 위치 기준으로 설명하세요 — translator는 Swift variable 이름을 보지 못합니다.

```swift
// AVOID: "Edit" could be a noun or a verb — different translations.
Text("Edit")
```

```swift
// PREFER
Text("Edit", comment: "Toolbar button that enters editing mode for the list.")
```

```swift
// PREFER: refer to placeholders by position, not by Swift name.
Text("Completed \(count) of \(total)",
     comment: "Progress label — the first variable is finished items, the second is the total.")
```

comment는 String Catalog 안(문자열별 Comment field)에도 둘 수 있으며, 이는 호출 지점에서 `comment:`를 전달하는 것과 동등합니다 — 문자열마다 하나의 source of truth를 유지하세요.
