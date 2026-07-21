# Memory 진단

retain cycle, memory leak, deallocation 문제에 대한 체계적인 디버깅입니다. memory leak의 90%는 세 가지 pattern을 따릅니다: timer leak, observer leak, closure capture.

## 진단 결정 테이블

| 증상 | 예상 원인 | 진단 도구 |
|---------|--------------|-----------------|
| Memory가 50MB -> 100MB -> 200MB로 증가 | retain cycle 또는 timer leak | Memory Graph Debugger |
| 10~15분 후 앱이 crash함 | 점진적인 memory leak | Instruments Allocations |
| deinit이 호출되지 않음 | strong reference cycle | Memory Graph Debugger |
| 특정 action에서 memory spike 발생 | collection/closure leak | Allocations + filtering |
| view를 dismiss한 후에도 memory가 높게 유지됨 | ViewController가 deallocate되지 않음 | deinit 로깅 추가 |

## 필수 1차 확인 항목

```swift
// 1. Add deinit logging to suspected class
class PlayerViewModel: ObservableObject {
    deinit {
        print("PlayerViewModel deallocated")
    }
}

// 2. Test deallocation
var vm: PlayerViewModel? = PlayerViewModel()
vm = nil  // Should print "deallocated"
```

```bash
# 3. Check device logs for memory warnings
# Connect device, open Xcode Console (Cmd+Shift+2)
# Look for: "Memory pressure critical", "Jetsam killed"

# 4. Check memory baseline
# Xcode > Product > Profile > Memory
# Perform action 5 times, check if memory keeps growing
```

## 결정 트리

```
Memory growing?
|-- Progressive growth every minute?
|   |-- Timer or notification leak -> Check Pattern 1 & 2
|
|-- Spike when action performed?
|   |-- Check if operation runs multiple times
|   |-- Spike then flat? -> Probably normal caching
|
|-- deinit not called?
|   |-- Use Memory Graph Debugger
|   |-- Look for purple/red circles with warning badge
|
|-- Can't tell from inspection?
    |-- Use Instruments > Allocations
    |-- Track object counts over time
```

## 흔한 Leak Pattern

### Pattern 1: Timer Leak (가장 흔함)

```swift
// WRONG - Timer never invalidated
class PlayerViewModel: ObservableObject {
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        // Timer never stopped -> keeps firing forever
    }
}

// CORRECT - Invalidate in deinit
class PlayerViewModel: ObservableObject {
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}
```

### Pattern 2: Observer Leak

```swift
// WRONG - Observer never removed
class PlayerViewModel: ObservableObject {
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChange),
            name: .audioRouteChanged,
            object: nil
        )
    }
}

// CORRECT - Use Combine (auto-cleanup)
class PlayerViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: .audioRouteChanged)
            .sink { [weak self] _ in
                self?.handleChange()
            }
            .store(in: &cancellables)
    }
}
```

### Pattern 3: Closure Capture Leak

```swift
// WRONG - Closure captures self strongly
class ViewController: UIViewController {
    var callbacks: [() -> Void] = []

    func addCallback() {
        callbacks.append {
            self.refresh()  // Strong capture
        }
    }
}

// CORRECT - Use weak self
class ViewController: UIViewController {
    var callbacks: [() -> Void] = []

    func addCallback() {
        callbacks.append { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        callbacks.removeAll()
    }
}
```

### Pattern 4: Delegate Cycle

```swift
// WRONG - Strong delegate reference
class Player {
    var delegate: PlayerDelegate?  // Strong reference
}

class Controller: PlayerDelegate {
    var player: Player?

    init() {
        player = Player()
        player?.delegate = self  // Creates cycle
    }
}

// CORRECT - Weak delegate
class Player {
    weak var delegate: PlayerDelegate?
}
```

## Memory Graph Debugger 사용

1. Xcode simulator에서 앱 실행
2. Debug > Memory Graph Debugger (또는 툴바 아이콘)
3. 그래프가 생성될 때까지 대기 (5~10초)
4. 경고 배지가 있는 보라색/빨간색 원 확인
5. 클릭하여 retain cycle 체인 확인

출력 예시:
```
PlayerViewModel
  ^ strongRef from: progressTimer
    ^ strongRef from: TimerClosure
      ^ CYCLE DETECTED
```

## Instruments Allocations 사용

1. Product > Profile (Cmd+I)
2. "Allocations" 템플릿 선택
3. action을 5~10회 수행
4. 확인: memory 라인이 계속 UP(상승)하는가?
   - YES -> leak 확인됨
   - NO -> leak이 아닐 가능성이 높음

```
Time -->
Memory
   |     -------- <- Memory keeps growing (LEAK)
   |    /
   |   /
   |  /
   +----------

vs normal:

   |  -------- <- Memory plateaus (OK)
   | /
   |/
   +----------
```

## PhotoKit Request Leak

```swift
// WRONG - Requests accumulate without cancellation
func loadImage(asset: PHAsset) {
    imageManager.requestImage(for: asset, ...) { image, _ in
        self.imageView.image = image
    }
}

// CORRECT - Cancel in prepareForReuse
class PhotoCell: UICollectionViewCell {
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    func configure(asset: PHAsset) {
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }

        requestID = imageManager.requestImage(for: asset, ...) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}
```

## 빠른 참조

| Leak 유형 | 탐지 방법 | 해결 방법 |
|-----------|-----------|-----|
| Timer | deinit이 호출되지 않음 | deinit에서 invalidate() 호출 |
| Observer | memory가 꾸준히 증가 | Combine + cancellables 사용 |
| Closure | Memory Graph에 cycle 표시 | [weak self] capture 사용 |
| Delegate | 두 객체가 모두 해제되지 않음 | delegate를 weak var로 선언 |
| Image request | 스크롤 시 memory spike 발생 | prepareForReuse에서 취소 |

## 검증 체크리스트

수정 적용 후:
- [ ] 예상되는 시점에 deinit이 출력됨
- [ ] Instruments에서 memory가 평평하게 유지됨
- [ ] Memory Graph에 보라색/빨간색 경고 없음
- [ ] 장시간 사용 후에도 앱이 crash하지 않음
- [ ] 시뮬레이션된 압박 상황에서 memory가 감소 (Xcode > Debug > Simulate Memory Warning)
