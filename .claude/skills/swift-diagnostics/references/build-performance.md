# Build 성능 진단

느린 build, Derived Data 문제, Xcode 멈춤 현상에 대한 체계적인 디버깅입니다. "원인 불명의" build 문제의 80%는 코드 버그가 아니라 환경 문제입니다.

## 진단 결정 테이블

| 증상 | 예상 원인 | 1차 확인 |
|---------|--------------|-------------|
| Build이 10분 이상 걸림 | Derived Data가 오래됨 | DerivedData 크기 확인 |
| "Build succeeded"인데 이전 코드가 실행됨 | 캐시된 build artifact | Derived Data 삭제 |
| build 중 Xcode에 beach ball이 나타남 | 좀비 xcodebuild 프로세스 | 프로세스 목록 확인 |
| Simulator가 splash 화면에서 멈춤 | Simulator가 비정상 상태 | simctl list devices |
| 간헐적인 build 실패 | 환경 손상 | 전체 clean rebuild |

## 필수 1차 확인 항목

```bash
# 1. Check for zombie processes
ps aux | grep -E "xcodebuild|Simulator" | grep -v grep

# 2. Check Derived Data size (>10GB = stale)
du -sh ~/Library/Developer/Xcode/DerivedData

# 3. Check simulator states
xcrun simctl list devices | grep -E "Booted|Booting|Shutting Down"
```

이 결과가 의미하는 것:
- **프로세스 0개 + 작은 DerivedData + 멈춘 simulator 없음** -> 환경이 깨끗함
- **프로세스 10개 이상 OR DerivedData 10GB 초과 OR simulator 멈춤** -> 먼저 clean 수행

## 결정 트리

```
Build/performance problem?
|-- BUILD FAILED with no details?
|   |-- Clean Derived Data -> rebuild
|
|-- Build succeeds but old code executes?
|   |-- Delete Derived Data -> rebuild (2-5 min fix)
|
|-- Build intermittent (sometimes succeeds/fails)?
|   |-- Clean Derived Data -> rebuild
|
|-- Xcode hangs during build?
|   |-- Check for zombie xcodebuild processes
|   |-- killall -9 xcodebuild
|
|-- "Unable to boot simulator"?
|   |-- xcrun simctl shutdown all
|   |-- xcrun simctl erase <device-uuid>
|
|-- Tests hang indefinitely?
    |-- Check simctl list -> reboot simulator
```

## 빠른 해결

### Derived Data 정리

```bash
# Delete all Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Also clean project-specific build folders
rm -rf .build/ build/

# Clean and rebuild
xcodebuild clean -scheme YourScheme
xcodebuild build -scheme YourScheme \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 좀비 프로세스 종료

```bash
# Kill all xcodebuild processes
killall -9 xcodebuild

# Verify they're gone
ps aux | grep xcodebuild | grep -v grep

# Kill Simulator if stuck
killall -9 Simulator
```

### Simulator 문제 해결

```bash
# Shutdown all simulators
xcrun simctl shutdown all

# If simctl fails, force quit first
killall -9 Simulator
xcrun simctl shutdown all

# List simulators to find problematic one
xcrun simctl list devices

# Erase specific simulator
xcrun simctl erase <device-uuid>

# Boot fresh simulator
xcrun simctl boot "iPhone 16 Pro"
```

### SPM 캐시 재설정

```bash
# Clear SPM caches
rm -rf ~/Library/Caches/org.swift.swiftpm

# Reset package dependencies
xcodebuild -resolvePackageDependencies

# Full clean rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean build -scheme YourScheme
```

## Build 시간 핫스팟 식별

```bash
# Enable build timing
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES

# Restart Xcode, build, check activity log
# Xcode > Report Navigator > Build log
```

## Xcode Build 명령어

```bash
# List available schemes
xcodebuild -list

# Show build settings
xcodebuild -showBuildSettings -scheme YourScheme

# Verbose build (more diagnostics)
xcodebuild -verbose build -scheme YourScheme

# Build for testing only (faster iteration)
xcodebuild build-for-testing -scheme YourScheme

# Run tests without rebuilding
xcodebuild test-without-building -scheme YourScheme \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test only
xcodebuild test -scheme YourScheme \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:YourTests/SpecificTestClass
```

## Crash Log 분석

```bash
# Find recent crashes
ls -lt ~/Library/Logs/DiagnosticReports/*.crash | head -5

# View crash log
cat ~/Library/Logs/DiagnosticReports/YourApp-*.crash | head -100

# Symbolicate address (if you have .dSYM)
atos -o YourApp.app.dSYM/Contents/Resources/DWARF/YourApp \
  -arch arm64 0x<address>
```

## 환경 재설정 (최후의 수단)

다른 방법이 모두 실패했을 때:

```bash
# 1. Quit Xcode
osascript -e 'quit app "Xcode"'

# 2. Kill all related processes
killall -9 xcodebuild Simulator

# 3. Clean all caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build/ build/

# 4. Reset simulators
xcrun simctl shutdown all
xcrun simctl erase all

# 5. Reopen Xcode
open -a Xcode YourProject.xcodeproj
```

## 흔한 오류 Pattern

| 오류 | 해결 방법 |
|-------|-----|
| BUILD FAILED (세부 정보 없음) | Derived Data 삭제 |
| Simulator를 부팅할 수 없음 | `xcrun simctl erase <uuid>` |
| No such module | Clean 후 Derived Data 삭제 |
| 테스트가 멈춤 | simctl list 확인 후 simulator 재부팅 |
| 이전 코드가 실행됨 | Derived Data 삭제 |

## 흔한 실수

- **환경을 확인하기 전에 코드부터 디버깅** - 항상 필수 단계를 먼저 실행
- **Simulator 상태 무시** - "Booting" 상태가 10분 이상 멈출 수 있음
- **git 변경이 문제를 유발했다고 가정** - Derived Data가 이전 build를 캐싱함
- **테스트 하나가 실패했는데 전체 test suite를 실행** - `-only-testing` 사용

## 검증 체크리스트

수정 적용 후:
- [ ] 좀비 xcodebuild 프로세스 없음
- [ ] Derived Data가 5GB 미만
- [ ] 모든 Simulator가 Shutdown 상태
- [ ] Clean build 성공
- [ ] 올바른 코드가 실행됨 (캐시된 것이 아님)
- [ ] 테스트가 일관되게 통과
