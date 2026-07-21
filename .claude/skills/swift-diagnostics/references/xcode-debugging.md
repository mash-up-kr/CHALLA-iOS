# Xcode 디버깅 참조

iOS/macOS 개발을 위한 LLDB 명령어, breakpoint, view 디버깅 기법.

## LLDB 빠른 참조

### 기본 명령어

```lldb
# Print variable
po myVariable
p myVariable

# Print with format
p/x myInt          # Hexadecimal
p/t myInt          # Binary
p/d myInt          # Decimal

# Print object description
po self
po myArray

# Expression evaluation
expr myVariable = 5
expr self.isLoading = true
```

### 객체 검사

```lldb
# Print all properties
po self.debugDescription

# Print specific property
po self.viewModel.state

# Print array contents
po myArray.map { $0.name }

# Print dictionary
po myDict.keys
po myDict["key"]
```

### SwiftUI 디버깅

```lldb
# Print view hierarchy (from any breakpoint in a View)
po Self._printChanges()

# Check @State value
po _myStateVariable.wrappedValue

# Check @Binding
po _myBinding.wrappedValue
```

### Memory 검사

```lldb
# Check memory address
p unsafeBitCast(myObject, to: Int.self)

# Check reference count
po CFGetRetainCount(myObject as CFTypeRef)

# Print type
po type(of: myObject)
```

## Breakpoint 기법

### 조건부 Breakpoint

1. Breakpoint 설정 (줄 번호 거터 클릭)
2. Breakpoint 우클릭 > Edit Breakpoint
3. 조건 추가:
   - `myVariable == 5`
   - `myArray.count > 10`
   - `self.state == .loading`

### Action Breakpoint

멈추지 않고 코드 실행:

1. Edit Breakpoint
2. Add Action > Debugger Command
3. 입력: `po "Value is: \(myVariable)"`
4. "Automatically continue" 체크

### Exception Breakpoint

crash가 발생하기 전에 포착:

1. Debug Navigator > + 버튼
2. Add Exception Breakpoint
3. 선택: All Exceptions 또는 Objective-C only

### Symbolic Breakpoint

임의의 method 호출에서 중단:

1. Debug Navigator > + 버튼
2. Add Symbolic Breakpoint
3. Symbol: `-[UIViewController viewDidLoad]`
4. 또는: `UIApplication.shared`

## View 디버깅

### View Hierarchy 디버깅

1. 앱 실행
2. Debug > View Debugging > Capture View Hierarchy
3. 또는 debug 툴바의 큐브 아이콘 클릭

### 확인해야 할 사항

- **View 겹침** - view가 예기치 않게 겹쳐서 쌓임
- **Constraint 문제** - 모호한 layout 경고
- **숨겨진 view** - alpha가 0이거나 isHidden이 true인 view
- **화면 밖 콘텐츠** - bounds 밖에 위치한 view

### Runtime Attribute 검사

view debugger에서:
1. 3D hierarchy에서 view 선택
2. Object Inspector에 모든 property가 표시됨
3. frame, bounds, constraint 확인

### View 디버깅 명령어

```lldb
# Print view hierarchy
po self.view.recursiveDescription()

# Print responder chain
po self.responderChain()

# Highlight view (in simulator)
expr self.view.layer.borderWidth = 2
expr self.view.layer.borderColor = UIColor.red.cgColor
```

## Network 디버깅

### Network Request 출력

```swift
// Add to URLSession configuration
#if DEBUG
URLSession.shared.configuration.protocolClasses?.insert(NetworkLogger.self, at: 0)
#endif
```

### LLDB Network 검사

```lldb
# Print URL request
po request.url
po request.httpMethod
po String(data: request.httpBody ?? Data(), encoding: .utf8)

# Print response
po response.statusCode
po String(data: responseData, encoding: .utf8)
```

## Thread 디버깅

### 현재 Thread 확인

```lldb
# Print current thread
thread info

# Print all threads
thread list

# Print backtrace
bt
bt all
```

### Main Thread Checker

scheme에서 활성화:
1. Edit Scheme > Run > Diagnostics
2. "Main Thread Checker" 체크

background thread에서의 UI 업데이트를 포착합니다.

## 성능 디버깅

### LLDB의 Time Profiler

```lldb
# Measure execution time
expr let start = CFAbsoluteTimeGetCurrent()
# ... execute code ...
expr print("Time: \(CFAbsoluteTimeGetCurrent() - start)")
```

### Memory 디버깅

scheme에서 활성화:
1. Edit Scheme > Run > Diagnostics
2. "Malloc Stack Logging" 체크
3. "Zombie Objects" 체크 (EXC_BAD_ACCESS용)

## 흔한 디버깅 시나리오

### 시나리오: View가 나타나지 않음

```lldb
# Check if view is in hierarchy
po self.view.superview

# Check frame
po self.view.frame

# Check if hidden
po self.view.isHidden
po self.view.alpha

# Check constraints
po self.view.constraints
```

### 시나리오: Button이 반응하지 않음

```lldb
# Check if user interaction enabled
po button.isUserInteractionEnabled

# Check if enabled
po button.isEnabled

# Check gesture recognizers
po button.gestureRecognizers

# Check if obscured
po self.view.hitTest(touchPoint, with: nil)
```

### 시나리오: Data가 로드되지 않음

```lldb
# Check network reachability
po NetworkMonitor.shared.isConnected

# Check API response
po lastResponse?.statusCode
po String(data: lastResponseData, encoding: .utf8)

# Check decoding
expr try JSONDecoder().decode(MyModel.self, from: data)
```

## 유용한 Xcode 단축키

| 동작 | 단축키 |
|--------|----------|
| Toggle breakpoint | Cmd + \ |
| Step over | F6 |
| Step into | F7 |
| Step out | F8 |
| Continue | Cmd + Ctrl + Y |
| View debugger | Cmd + Shift + D |
| Memory graph | Cmd + Shift + M |
| Debug navigator | Cmd + 7 |

## Debug Console 팁

```lldb
# Clear console
Cmd + K

# Search console output
Cmd + F

# Copy console selection
Cmd + C

# Increase console font
Cmd + + (plus)
```

## 검증 체크리스트

디버깅 세션 종료 후:
- [ ] debug print 구문 제거
- [ ] 불필요한 breakpoint 비활성화
- [ ] scheme의 diagnostic 옵션 끄기 (production용)
- [ ] 디버깅 중 추가한 `expr` 수정 사항 제거
