# Migration Patterns

Legacy Swift 코드를 최신 best practice로 마이그레이션하기 위한 흔한 pattern입니다.

## Delegate → AsyncStream

### ✅ 현대적 Pattern

```swift
// Before: Delegate pattern
protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdateLocation: Location)
}

class LocationManager {
    weak var delegate: LocationManagerDelegate?
}

// After: AsyncStream
class LocationManager {
    var locations: AsyncStream<Location> {
        AsyncStream { continuation in
            // Setup location updates
            self.onLocationUpdate = { location in
                continuation.yield(location)
            }
            continuation.onTermination = { _ in
                // Cleanup
            }
        }
    }
}

// Usage
for await location in locationManager.locations {
    updateUI(with: location)
}
```

**소요 시간:** delegate당 ~3시간
**위험도:** 중간 - API surface가 변경됨

---

## UIKit → SwiftUI

### ✅ 현대적 Pattern

```swift
// Before: UIKit
class ProfileViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        nameLabel.text = user.name
        avatarImageView.load(url: user.avatarURL)
    }
}

// After: SwiftUI
struct ProfileView: View {
    let user: User

    var body: some View {
        VStack {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Text(user.name)
                .font(.headline)
        }
    }
}
```

**소요 시간:** view controller당 ~8시간
**위험도:** 높음 - 두 framework 모두에 대한 이해가 필요함

### 흔한 UIKit → SwiftUI Mapping

| UIKit | SwiftUI |
|-------|---------|
| `UILabel` | `Text()` |
| `UIImageView` | `Image()` or `AsyncImage()` |
| `UIButton` | `Button()` |
| `UITextField` | `TextField()` |
| `UIStackView` | `VStack`, `HStack`, `ZStack` |
| `UIScrollView` | `ScrollView` |
| `UITableView` | `List` |
| `UINavigationController` | `NavigationStack` |

---

## Migration Workflow

### 1. 분석

- Grep을 사용해 pattern의 모든 발생 위치를 식별
- 의존성과 call site를 매핑
- 소요 시간과 위험도를 추정

### 2. 계획

- TodoWrite로 migration checklist 작성
- 테스트 지점 식별
- 필요할 경우 rollback 전략 계획

### 3. 실행

- 한 번에 하나의 component씩 마이그레이션
- 필요하다면 호환성 shim 추가
- Call site를 점진적으로 업데이트

### 4. 검증

- 각 변경 후 기존 테스트 실행
- Edge case 테스트
- 성능 영향 확인

---

## 소요 시간 & 위험도 표

| Migration 유형 | 일반적인 소요 시간 | 위험 수준 | 비고 |
|---------------|----------------|------------|-------|
| Completion → async/await | 파일당 ~2시간 | 낮음 | Compiler가 잘 지원함 |
| DispatchQueue → Actor | class당 ~4시간 | 중간 | Concurrency 경계에 대한 이해 필요 |
| Delegate → AsyncStream | delegate당 ~3시간 | 중간 | API surface가 변경됨 |
| UIKit → SwiftUI | view controller당 ~8시간 | 높음 | 두 framework 모두에 대한 지식 필요 |
| Sendable 추가 | type당 ~1시간 | 낮음 | Compile-time 검증 |

---

## Deprecated API 대체

현재 API 상태와 대체 방법은 항상 Sosumi MCP server에서 확인하세요:

| Deprecated | 현대적 대체 |
|-----------|-------------------|
| `UIApplication.shared.keyWindow` | `UIApplication.shared.connectedScenes` |
| `UIDevice.current.name` | Privacy manifest required |
| `URLSession.dataTask` | `URLSession.data(from:)` |

Sosumi를 사용해 deprecation 상태를 검증하고 2025년 기준 migration guide를 찾으세요.
