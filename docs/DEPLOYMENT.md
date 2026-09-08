# CHALLA 배포 전략

> 실배포앱(`CHALLAApp`)의 TestFlight 자동 배포는 Xcode Cloud로 구축 완료다.
> 디자인 시스템 검수앱은 아직 수동 배포 — "남은 결정 사항" 참고.

## 앱 2개 = 완전히 별개의 배포

이 저장소는 실행 앱이 두 개이며, App Store Connect 입장에서 **서로 무관한 별개 앱**이다.

| | 실배포앱 | 디자인 시스템 검수앱 |
| :-- | :-- | :-- |
| 타깃/스킴 | `CHALLAApp` | `CHALLADesignSystemApp` |
| 번들 ID | `com.challa.app` | `com.challa.designsystem` |
| 표시 이름 | CHALLA | CHALLA 디자인 시스템 |
| 배포 대상 | 실사용자 | 디자이너 (TestFlight 내부 그룹) |
| 배포 주기 | 정식 릴리즈 단위 — 신중하게 | DS 변경 시마다 — 자주, 가볍게 |
| 배포 트리거 | **`release/*` 브랜치 푸시 · `v*` 태그** (Xcode Cloud) | 수동 (자동화 미정) |

- 번들 ID는 초기 세팅부터 분리해뒀다 (CI/CD 붙일 때 안 꼬이게).
- 폴더 위치와 배포는 무관 — 검수앱이 `Projects/UI/` 아래 있어도 스킴만 Archive하면 독립 배포된다.

## 파이프라인

```
로컬:      pre-commit 훅 (staged 파일 포맷/린트)                      .githooks/pre-commit
PR·main:   GitHub Actions CI — lint → install → generate → test      .github/workflows/ci.yml
릴리즈:    Xcode Cloud 배포 — ci_post_clone.sh → Archive → TestFlight  ci_scripts/ci_post_clone.sh
```

- **CI(품질 검사)는 GitHub Actions, 배포는 Xcode Cloud로 역할을 나눈다.** 둘은 서로를 트리거하지 않고
  각자 독립적으로 저장소를 본다 — CI는 PR과 main을, Xcode Cloud는 `release/*`와 태그를 본다.
- GitHub Actions CI는 배포 산출물을 만들 수 없다. `Shared.xcconfig.template`을 그대로 복사해
  (팀 ID·API 호스트·카카오 키가 전부 플레이스홀더) **시뮬레이터용 미서명 빌드**만 만들기 때문이다.
- 빌드 번호는 `CI_BUILD_NUMBER` 기반 자동 증가 — 수동 +1 커밋을 만들지 않는다.
- **앱 Info.plist의 `CFBundleShortVersionString`·`CFBundleVersion`은 반드시 `$(MARKETING_VERSION)`·
  `$(CURRENT_PROJECT_VERSION)`를 참조해야 한다** (`Project+Templates.swift`). Tuist 기본값은 `1.0`/`1`을
  리터럴로 넣는데, 그러면 위 자동 증가가 실제 앱에 반영되지 않아 두 번째 업로드부터
  App Store Connect가 빌드 번호 중복으로 거부한다.
- 마케팅 버전은 릴리즈 태그(`v1.2.0` → `1.2.0`)에서 뽑는다. 태그 없는 `release/*` 브랜치 빌드는
  매니페스트의 `marketingVersion` 값을 그대로 쓴다.
- CI는 `paths` 필터로 코드 변경이 있는 PR에서만 돈다. 이 필터 때문에 **required check로 지정하면
  문서만 고친 PR이 pending으로 막힌다** (근거는 `ci.yml` 상단 주석).

---

## Xcode Cloud 워크플로우 — 실배포앱

App Store Connect UI에만 있고 저장소에는 남지 않는 설정이라, **여기가 유일한 기록**이다. 바꿀 때 같이 고칠 것.

| 항목 | 값 |
| :-- | :-- |
| 스킴 | `CHALLAApp` |
| 액션 | Archive — iOS / Release |
| Xcode 버전 | **26.x 고정** (아래 이유 참고 — Latest Release 금지) |
| 시작 조건 ① | Branch Changes on `release/*` |
| 시작 조건 ② | Tag Changes matching `v*` |
| 후처리 | TestFlight Internal Testing |

### Xcode 버전을 고정해야 하는 이유

`Settings+Templates.swift`가 모든 타깃에 타입 추론 예산 플래그
(`-Xfrontend -solver-scope-threshold=...`)를 건다. **이 플래그는 Swift 6.2(Xcode 26.x)부터 존재한다.**
더 낮은 Xcode에서는 컴파일이 아예 안 된다. GitHub Actions CI가 러너 기본 Xcode를 버리고
`xcode-select -s Xcode_26.3`을 하는 것과 같은 이유다 (#57).

### 환경변수

`ci_post_clone.sh`가 이 값들로 `Configs/Shared.xcconfig`(gitignore)를 통째로 만든다.
**template의 키를 전부 채워야 한다.** 일부만 채우면:

- `API_SCHEME` 누락 → `tuist generate`가 즉사한다. ATS 예외 도메인은 plist dictionary의 **key**라
  `$(API_HOST)` 빌드타임 치환이 안 통해서, 매니페스트가 이 파일을 직접 읽기 때문이다.
  (에러 메시지가 "signal with code 5"라 원인을 못 알려준다 — 그래서 스크립트가 먼저 검사한다.)
- `KAKAO_NATIVE_APP_KEY` 누락 → 빌드는 통과하고 **실행 즉시 죽는 빌드**가 TestFlight에 올라간다
  (`CHALLAAPIEnvironment`의 `fatalError`. `CHALLAApp.swift`에도 `assert`가 있지만 Release에서는 빠진다).

| 환경변수 | xcconfig 키 | 필수 | secret | 값의 출처 |
| :-- | :-- | :--: | :--: | :-- |
| `CHALLA_TEAM_ID` | `DEVELOPMENT_TEAM` | ✅ | | Xcode > Settings > Accounts |
| `CHALLA_API_HOST` | `API_HOST` | ✅ | ✅ | 백엔드 팀 채널 |
| `CHALLA_API_SCHEME` | `API_SCHEME` | ✅ | | `http` 또는 `https` |
| `CHALLA_API_PORT` | `API_PORT` | ✅ | | https면 **빈 값으로 등록** |
| `CHALLA_KAKAO_NATIVE_APP_KEY` | `KAKAO_NATIVE_APP_KEY` | ✅ | ✅ | 카카오 개발자 콘솔 > 앱 키 |

> ⚠️ scheme·port에 기본값을 두지 않는다. 기본값을 두면 둘을 빠뜨렸을 때 조용히 `https`로 나가서,
> 백엔드가 http인 동안에는 **빌드는 멀쩡한데 모든 API 호출이 실패하는 빌드**가 TestFlight에 올라간다.
> port는 https에서 비어 있는 게 정상이므로 값이 아니라 **등록 여부**만 본다 — 빈 값으로라도 등록해야 통과한다.
> scheme이 `http`면 매니페스트가 해당 도메인에 ATS 평문 예외를 자동으로 붙인다.

### 서명

Xcode Cloud는 클라우드 관리 인증서·프로파일로 서명하며 **자동 서명을 전제한다.**
`CHALLAApp`은 로컬에서 `.manual`(팀 프로파일 이름 지정)을 쓰는데 그 프로파일은 러너에 없으므로,
`ci_post_clone.sh`가 `TUIST_CLOUD_SIGNING=true`를 켜서 `AppSigning`이 manual → automatic으로 낮춘다.
**로컬과 GitHub Actions는 이 변수를 설정하지 않아 기존 동작 그대로다.**

`aps-environment`는 Debug=`development` / Release=`production`으로 갈려 있다
(`CHALLAApp.entitlements` / `CHALLAApp.Release.entitlements`).
App Store 프로파일이 `development`를 포함하지 않아 안 갈라두면 아카이브 서명이 거부된다.
**두 파일은 이 항목만 달라야 하므로 항목 추가 시 함께 고칠 것.**

### 사전 준비 (최초 1회)

- [ ] App Store Connect에 `com.challa.app` 앱 레코드 등록
- [ ] Apple Developer 포털의 App ID `com.challa.app`에 **Push Notifications**·**Sign in with Apple**·**Associated Domains** capability 활성화
      (자동 서명이 프로파일을 만들 때 이게 없으면 엔타이틀먼트 불일치로 실패)
- [ ] TestFlight Internal Testing 그룹 생성
- [x] **앱 아이콘 1024pt** — `AppIcon-1024.png` 추가 완료.
      아이콘이 없으면 아카이브·업로드는 성공하고 App Store Connect 처리 단계에서
      "Missing app icon"으로 거부되어 TestFlight에 안 뜬다.
      **교체할 때 알파 채널을 반드시 제거할 것** — ASC는 알파가 있는 large app icon을 받지 않는다.
      (`sips -g hasAlpha <파일>`로 확인. 1024 한 장만 두면 나머지 크기는 actool이 만든다)
- [ ] 워크플로우 생성은 **로컬에 `tuist generate`된 상태의 Xcode에서** 한다 —
      `*.xcodeproj`/`*.xcworkspace`가 gitignore라 저장소에는 프로젝트 파일이 없다.
      빌드 시점에는 `ci_post_clone.sh`가 생성해 준 워크스페이스를 쓴다.

### 릴리즈 절차

```bash
git switch main && git pull
git tag v1.2.0 && git push origin v1.2.0    # 또는 release/1.2.0 브랜치 푸시
```

**아카이브 성공에서 멈추지 말고 App Store Connect 처리 완료 → TestFlight 노출까지 확인한다.**
앱 아이콘 누락 같은 문제는 업로드가 성공한 뒤에야 드러난다.

> Xcode Cloud는 `tuist cache`를 쓰지 않아 전 모듈을 소스에서 컴파일한다.
> GitHub Actions CI(캐시 웜 ~10분)와 비교하지 말 것 — 첫 실행 30~60분을 예상한다.

---

## 수동 배포 (Xcode Cloud 장애 시 폴백 · 검수앱 배포)

1. `mise exec -- tuist generate` → Xcode에서 열기
2. 스킴 선택, 타깃 `Any iOS Device`
3. Product > Archive → Organizer > Distribute App > App Store Connect > Upload
4. App Store Connect > TestFlight > 대상 그룹에 배포

`Configs/Shared.xcconfig`는 `Shared.xcconfig.template`을 복사해 값을 채운다(gitignore).

## 남은 결정 사항 (팀 논의)

- [ ] 검수앱(`CHALLADesignSystemApp`) 자동 배포 여부 — 붙인다면 DS 변경 감지 path 필터 범위
      (`Projects/UI/**`만? 폰트/애셋 리소스 변경도?)
- [ ] TestFlight 그룹 구성 — 디자이너 외 QA 그룹 필요 여부
