# CHALLAApp

## 레이어와 책임

**App 레이어**. 실배포앱이자 유일한 조립 지점이다. Feature끼리 직접 참조하지 않으므로
화면 전이와 의존성 배선이 전부 여기 모인다.

앱에서 Data 구현체를 만지는 곳은 `CompositionRoot` 하나다.

## 화면 전이 (`AppFeature`)

`State`가 enum이라 동시에 두 화면이 살아 있지 않다. `NavigationStack`을 쓰지 않고 뷰를 교체한다 —
`SettingView`가 자기 `NavigationStack`을 소유해서, 밖에서 push하면 중첩으로 깨진다
(`SettingFeature/MODULE.md`).

| 단계 | 다음 |
| :-- | :-- |
| `launching` | 버전 체크 → 강제 업데이트 필요 시 `forceUpdate` / 불필요 시 세션 복원 → 저장 세션 없음이면 `login`, 있으면 프로필 조회 → `home`·`profileSetup` / 실패 → `login` |
| (모든 화면) | 세션 만료 알림 → `login` (이미 `login`이면 무시) |
| `login` | `loginSucceeded` → 프로필 재조회 |
| `profileSetup` | `setupCompleted` → `home` |
| `home` | 설정 버튼 → `setting` / 방 진입(목록에서 고름·방 만들기·초대 코드) → `roomDetail` |
| `roomDetail` | `closeTapped` → `home`(새 State) — 촬영·채팅은 붙일 화면이 아직 없어 TODO |
| `setting` | `backRequested` → `home` / `editProfileRequested` → `profileEdit` / `signedOut`·`accountDeleted` → `login` |
| `profileEdit` | `editCompleted` → `setting`(새 State) / `cancelled` → `setting` |
| `forceUpdate` | **나가는 전이 없음** — 앱 업데이트만 가능 |

`roomDetail`·`setting`·`profileEdit` 케이스는 `UserProfile`을 함께 들고 있다 — 홈이 닉네임을
표시하는데 뒤로 나올 때 재조회 없이 바로 그려야 한다.

편집 저장 후에는 `SettingFeature.State`를 **새로 만든다.** `onAppear`가 `profile == nil`일 때만
조회하므로, 그래야 헤더가 바뀐 닉네임을 다시 읽는다.

방 상세에서 나올 때도 `HomeFeature.State`를 **새로 만든다.** 그 방에서 사진을 찍고 나왔을 수 있어
목록을 다시 조회해야 한다.

## 버전 체크와 강제 업데이트

실행 직후 `CheckAppUpdateUseCase`(`AppDomain`)로 버전을 체크한다 — 실구현은 `AppData.DefaultAppVersionRepository`
(`GET /api/v1/app/version`)이고 `CompositionRoot.registerAppUpdate`가 잇는다. 체크 실패는 **fail-open 정책**으로
`.notRequired`로 취급해 정상 진행하고, 강제 업데이트 필요 시만 `forceUpdate` state에 멈춘다.
`forceUpdate`는 **terminal state**이다 — 앱을 업데이트하거나 종료해야만 벗어난다.
응답에 실려 온 스토어 주소를 `forceUpdate(storeURL:)`에 담아 두고 알럿 '확인'이 연다 (nil이면 아무 것도 안 한다).

버전 체크만 공용 `HTTPClient`를 쓰지 않는다 — 로그인 전이라 토큰이 필요 없고,
스플래시를 잡아 두는 호출이라 타임아웃 3초짜리 전용 세션을 쓴다 (`registerAppUpdate` 주석 참고).

## 자동 로그인 · 토큰 갱신

버전 체크를 통과한 뒤에 두 가지를 동시에 시작한다 — 강제 업데이트로 막힌 화면에서는 아무것도 조회하지 않는다.

1. **자동 로그인** — `RestoreSessionUseCase`로 저장된 세션을 먼저 확인한다.
   없으면 프로필 조회를 아예 보내지 않고 `login`으로 간다 (비로그인 상태에서 실패할 요청을 재시도 백오프까지
   태우면 로그인 화면이 10초 넘게 늦게 뜬다). 이 유스케이스가 **설치 후 최초 실행이면 키체인도 초기화**한다 —
   앱을 지워도 키체인은 남을 수 있어, 지우지 않으면 이전 설치의 죽은 토큰으로 시작한다
2. **세션 만료 감시** — `SessionExpirationChannel`을 구독한다. 토큰 갱신이 최종 실패하면
   어느 화면에 있든 `login`으로 되돌리고 진행 중인 프로필 조회를 취소한다

프로필 조회가 `.network`로 실패해도 `login`으로 간다 — 오프라인에서는 자동 로그인이 유지되지 않는다.
저장된 토큰은 그대로라 연결이 돌아온 뒤 다시 들어오면 자동 로그인된다.

**401 자동 갱신은 `CompositionRoot`가 배선한다** — 요청용 클라이언트에 `TokenRefreshRetrier`를 달고,
갱신 자체는 **retrier 없는 별도 클라이언트**로 보낸다. 같은 클라이언트를 쓰면 갱신 요청의 401이
다시 갱신을 부르는 재귀에 빠진다. `refreshTokenUseCase` 의존성도 이 갱신 전용 클라이언트를 공유한다.

## 어댑터 (`Sources/Adapters/`)

Domain이 모양만 정의하고 구현을 Data에 두지 않은 두 인터페이스를 여기서 잇는다.
두 aggregate를 다 아는 곳이 조립 지점뿐이라 App이 맡는다.

- `SettingProfileProviderAdapter` — `UserRepository.fetchMyProfile()` → `SettingProfile`,
  `UserError` → `SettingError` 매핑
- `AccountRepositoryAdapter` — 로그아웃은 `AuthDomain.LogoutUseCase`, 탈퇴는 `UserRepository.deleteAccount()`.
  **탈퇴 API는 서버 계정만 지우므로 Keychain 토큰은 이 어댑터가 지운다.**
  안 지우면 다음 실행에서 죽은 토큰으로 401을 맞는다. 둘 다 FCM 토큰도 먼저 해제한다

## 푸시 알림 (`Sources/Push/`)

- `AppDelegate` — `FirebaseApp.configure()` · `MessagingDelegate` · `UNUserNotificationCenterDelegate`.
  `UIApplicationDelegate`는 MainActor인데 나머지 둘은 아니라, 그쪽 콜백은 `nonisolated`로 두고
  동기화 객체를 저장 프로퍼티 대신 `@Dependency`로 그때그때 꺼낸다
- `PushTokenSynchronizer` — FCM 토큰과 서버 등록 상태를 맞추는 actor.
  토큰 수신과 토글 변경이 다른 시점에 들어와 마지막 상태를 들고 있다가 둘이 맞을 때만 서버를 부른다

**'서비스 알림' 토글은 토큰 등록·삭제 API로 처리한다** — 켜면 `POST /notifications/tokens`,
끄면 `DELETE`. 서버에 알림 on/off 값을 저장하는 API가 없고, 등록된 토큰이 있는 기기에만
푸시가 가기 때문이다. `CompositionRoot`가 `UpdateServiceNotificationUseCase`를
"로컬 저장 + 토큰 동기화"로 조립한다.

두 가지 한계가 따라온다. **기기별 설정이다** — 한 기기에서 꺼도 같은 계정의 다른 기기는 계속 받는다.
그리고 **알림 종류를 나눌 수 없다** — 지금은 종류가 하나뿐이라 문제되지 않지만,
종류가 늘면 서버에 설정 API가 필요하다.

등록·해제 실패는 알리지 않는다 — 사용자가 시작한 동작이 아니라 보여줄 화면이 없다.
앱 실행 때마다 `sync()`가 저장값과 서버 상태를 다시 맞춰 복구한다.

## 배선 순서

`CHALLAApp.init()`의 세 줄은 순서가 강제된다 — 카카오 SDK 초기화 → `prepareDependencies` →
루트 `Store` 생성. 델리게이트 콜백은 이 `init`이 끝난 뒤 불리므로 그때는 의존성이 이미 등록돼 있다.

`HTTPClient`는 Auth·User·Notification이 **같은 인스턴스**를 쓴다.
다른 걸 넘기면 `AuthInterceptor`가 붙인 토큰이 실리지 않아 401이 난다.
예외는 토큰 갱신 전용 클라이언트 하나뿐이다 (위 "자동 로그인 · 토큰 갱신" 참고).

`SessionExpirationChannel`은 `CompositionRoot`가 만들어 갱신 실패 콜백과 `\.sessionExpirationChannel`
의존성 양쪽에 **같은 인스턴스**로 꽂는다. 기본값(`liveValue`)은 아무것도 흘리지 않는 채널이라
주입을 빠뜨리면 만료 알림이 조용히 사라진다.

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme CHALLAApp \
  -destination 'platform=iOS Simulator,id=<UDID>' test
```

기기 이름은 런타임마다 중복되므로 `xcrun simctl list devices available`로 UDID를 확인해 쓴다.
`AppFeatureTests`가 위 전이표를 TestStore로 고정한다.

## 의존 관계

- **이 앱이 의존**: `LoginFeature` · `ProfileSetupFeature` · `SettingFeature` ·
  `HomeFeature` · `RoomDetailFeature` ·
  `AuthData/Domain` · `UserData/Domain` · `SettingData/Domain` · `NotificationData/Domain` ·
  `RoomData/Domain` · `CHALLADesignSystem` · `CHALLAImageKit` ·
  `CHALLANetwork` · `Keychain` · KakaoSDK · FirebaseCore · FirebaseMessaging

## 선행 조건

- `Configs/Shared.xcconfig` — `./Scripts/bootstrap.sh`가 template에서 만든다. 팀 ID·카카오 키·서버 주소
- `Resources/GoogleService-Info.plist` — **레포에 커밋돼 있다. 실수가 아니라 결정이다.**

  이 파일은 IPA에 그대로 들어가 누구나 추출할 수 있어 통상적 의미의 비밀이 아니고, Firebase 문서도
  커밋을 허용한다. 팀이 서명값·서버 주소를 `Configs/Shared.xcconfig`(gitignore)로 빼는 것과 다른 판단이라
  여기 적어 둔다 — 그쪽은 개인·환경마다 값이 달라서고, 이 파일은 앱 하나에 하나뿐이라 공유가 맞다.

  단, **저장소가 공개라 `API_KEY`에 iOS 번들 ID 제한이 걸려 있어야 한다** (GCP 콘솔 > 사용자 인증 정보).
  제한이 없으면 그 키로 다른 Google API를 호출할 수 있다.
- 실기기 푸시 확인에는 Apple Developer App ID의 Push Notifications 활성화와
  APNs Auth Key(.p8) Firebase 콘솔 업로드가 필요하다
