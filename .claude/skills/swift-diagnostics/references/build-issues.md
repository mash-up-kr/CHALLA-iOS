# Build 문제 진단

SPM resolution, "No such module", dependency 충돌에 대한 체계적인 디버깅입니다. 지속적인 build 실패의 80%는 코드 버그가 아니라 dependency resolution 문제입니다.

## 진단 결정 테이블

| 오류 | 예상 원인 | 1차 확인 |
|-------|--------------|-------------|
| package 추가 후 "No such module" | SPM 캐시가 오래됨 | package 캐시 정리 |
| "Multiple commands produce" | target 내 중복 파일 | target membership 확인 |
| Build는 로컬에서는 성공하지만 CI에서는 실패 | 환경/캐시 차이 | Podfile.lock 비교 |
| SPM resolution이 멈춤 | package 캐시 손상 | .build와 DerivedData 삭제 |
| Framework 버전 충돌 | 전이 dependency 문제 | Package.resolved 확인 |

## 필수 1차 확인 항목

```bash
# 1. Check Derived Data size (>10GB = stale)
du -sh ~/Library/Developer/Xcode/DerivedData

# 2. Check for zombie xcodebuild processes
ps aux | grep xcodebuild | grep -v grep

# 3. List available schemes
xcodebuild -list
```

## 결정 트리

```
Build failing?
|-- "No such module XYZ"?
|   |-- After adding SPM package? -> Clean + reset package caches
|   |-- After pod install? -> Check Podfile.lock conflicts
|   |-- Framework not found? -> Check FRAMEWORK_SEARCH_PATHS
|
|-- "Multiple commands produce"?
|   |-- Duplicate files in target membership -> Check File Inspector
|
|-- SPM resolution hangs?
|   |-- Clear package caches + Derived Data
|
|-- Version conflicts?
    |-- Use dependency resolution strategies below
```

## 빠른 해결

### SPM Package를 찾을 수 없음

```bash
# Nuclear clean
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm

# Reset packages in project
xcodebuild -resolvePackageDependencies

# Clean build
xcodebuild clean build -scheme YourScheme
```

### CocoaPods 충돌

```bash
# Check what versions were installed
cat Podfile.lock | grep -A 2 "PODS:"

# Clean reinstall
rm -rf Pods/
rm Podfile.lock
pod install

# Always open workspace (not project)
open YourApp.xcworkspace
```

### "Multiple commands produce" 오류

1. Xcode 열기
2. 내비게이터에서 파일 선택
3. File Inspector > Target Membership
4. 중복된 target 체크 해제
5. 또는: Build Phases > Copy Bundle Resources > 중복 항목 제거

### Framework Search Paths

```bash
# Show all build settings
xcodebuild -showBuildSettings -scheme YourScheme | grep FRAMEWORK_SEARCH_PATHS
```

Xcode에서 수정:
1. Target > Build Settings
2. "Framework Search Paths" 검색
3. 추가: `$(PROJECT_DIR)/Frameworks` (recursive)

## Dependency Resolution 전략

### 전략 1: 특정 버전 고정

```ruby
# Podfile - exact versions
pod 'Alamofire', '5.8.0'
pod 'SwiftyJSON', '~> 5.0.0'  # Any 5.0.x
```

```swift
// Package.swift - exact versions
.package(url: "...", exact: "1.2.3")
```

### 전략 2: 버전 범위 사용

```swift
// Package.swift
.package(url: "...", from: "1.2.0")              // 1.2.0 and higher
.package(url: "...", .upToNextMajor(from: "1.0.0"))  // 1.x.x but not 2.0
```

### 전략 3: SPM Resolution 재설정

```bash
# Clear package caches
rm -rf .build
rm Package.resolved

# Re-resolve
swift package resolve
```

## Debug와 Release 차이

```bash
# Compare configurations
xcodebuild -showBuildSettings -configuration Debug > debug.txt
xcodebuild -showBuildSettings -configuration Release > release.txt
diff debug.txt release.txt
```

흔한 원인:
- SWIFT_OPTIMIZATION_LEVEL (-Onone vs -O)
- ENABLE_TESTABILITY (Debug에서는 YES, Release에서는 NO)
- DEBUG 전처리기 플래그

## 명령어 참조

```bash
# CocoaPods
pod install                    # Install dependencies
pod update                     # Update to latest versions
pod outdated                   # Check for updates
pod deintegrate                # Remove CocoaPods from project

# Swift Package Manager
swift package resolve          # Resolve dependencies
swift package update           # Update dependencies
swift package show-dependencies # Show dependency tree
xcodebuild -resolvePackageDependencies  # Xcode's SPM resolve

# Xcode Build
xcodebuild clean               # Clean build folder
xcodebuild -list               # List schemes and targets
xcodebuild -showBuildSettings  # Show all build settings
```

## 흔한 실수

### Lockfile을 커밋하지 않음
```bash
# BAD: .gitignore includes lockfiles
Podfile.lock
Package.resolved

# These should be committed for reproducible builds
```

### "Latest" 버전 사용
```ruby
# BAD: No version specified
pod 'Alamofire'  # Breaking changes when updated

# GOOD: Explicit version
pod 'Alamofire', '~> 5.8'
```

### Project 대신 Workspace 열기
```bash
# BAD (with CocoaPods)
open YourApp.xcodeproj

# GOOD
open YourApp.xcworkspace
```

## 검증 체크리스트

수정 적용 후:
- [ ] 깨끗한 Derived Data 상태에서 build 성공
- [ ] 모든 dependency가 예상 버전으로 resolve됨
- [ ] Debug와 Release configuration 모두 build됨
- [ ] CI build가 local build와 일치
- [ ] Lockfile이 source control에 커밋됨
