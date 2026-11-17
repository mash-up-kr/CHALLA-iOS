# CHALLAApp

## 레이어와 책임

**App 레이어**. 실배포앱이자 유일한 조립 지점이다. Feature끼리 직접 참조하지 않으므로
화면 전이와 의존성 배선이 전부 여기 모인다.

앱에서 Data 구현체를 만지는 곳은 `CompositionRoot` 하나다.

## 화면 전이 — 루트 교체(`AppFeature`) + 스택(`MainFeature`)

화면 이동은 두 층이다 (#126 리팩토링 진행 중).

- **`AppFeature` — 돌아갈 일이 없는 큰 흐름만 enum으로 교체한다.** 스플래시 · 로그인 · 프로필 설정 · 강제 업데이트 ·
  메인(`.main`). 동시에 두 case가 살아 있지 않다.
- **`MainFeature` — 로그인 뒤 화면은 홈 위에 쌓는다.** `home`(항상 있음) + `path: StackState<Path>`.
  `MainView`가 앱의 유일한 `NavigationStack`이다. 뒤로 가면 위 화면만 빠지고 **아래 화면 State는 그대로 살아 있다** —
  스크롤·목록·조회 결과가 유지된다. 다만 아래 화면이 다시 보일 때 SwiftUI가 그 뷰의 `.task`를 다시 실행해
  홈·방 상세가 **뒤에서 조용히 재조회**한다 (목록이 있으면 스피너 없음).

아직 스택으로 옮기지 않은 **설정 · 프로필 편집 · 카메라**는 `AppFeature`의 enum 화면으로 남아 있다.
메인에서 그리로 나가는 요청은 `AppFeature`가 `.main(...)` 액션을 엿보고 처리하고("메인에서 enum 화면으로 나가는 요청" 블록),
돌아올 때는 `returnToMain(profile:cards:room:)`로 메인을 새로 만든다. 단계 3·4에서 이 화면들이 스택·`@Presents`로 옮겨 가면
이 다리와 `returnToMain`은 함께 지운다. `SettingView`가 자기 `NavigationStack`을 소유해서 지금은 메인 스택에 push하지 못한다
(`SettingFeature/MODULE.md`).

### `AppFeature` (루트)

| 단계 | 다음 |
| :-- | :-- |
| `launching` | 버전 체크 → 강제 업데이트 필요 시 `forceUpdate` / 불필요 시 저장 세션 없음 → `login`, 있으면 프로필 조회 → 성공 시 `main`·`profileSetup`, 실패 시 `login`. 어느 목적지든 **스플래시 최소 노출 2초**(`splashMinimumHold`)를 지킨다 — 먼저 준비되면 `SplashScreen.pendingDestination`에 맡아 뒀다가 노출이 끝나는 순간 전이한다 (#98) |
| (모든 화면) | 세션 만료 알림 → `login` (이미 `login`이면 무시) |
| `login` | `loginSucceeded` → 프로필 재조회 |
| `profileSetup` | `setupCompleted` → `main` |
| `main` | 홈의 설정 버튼 → `setting` / 홈·방 상세의 촬영 준비 완료 → `camera` (그 밖의 이동은 아래 `MainFeature`) |
| `camera` | `closeRequested` → 들어온 곳으로(홈이면 `main`, 방 상세면 그 방 상세를 쌓은 `main`) / `captureFinished` → 찍은 방 상세를 쌓은 `main`(방금 올린 사진 강조) |
| `setting` | `backRequested` → `main` / `editProfileRequested` → `profileEdit` / `signedOut`·`accountDeleted` → `login` |
| `profileEdit` | `editCompleted` → `setting`(새 State) / `cancelled` → `setting` |
| (로그인 후 모든 화면) | 초대 링크 수신 → 메인이면 쌓인 화면만 비우고, 아니면 메인을 새로 만들어 홈에 입장을 맡긴다 → 성공 시 방 상세가 쌓인다 |
| `forceUpdate` | **나가는 전이 없음** — 앱 업데이트만 가능 |

`camera`·`setting`·`profileEdit` 케이스는 돌아올 때 메인을 다시 만들 재료(`UserProfile`·홈 목록)를 포장 struct에
함께 들고 있다. 편집 저장 후에는 `SettingFeature.State`를 **새로 만든다** — `onAppear`가 `profile == nil`일 때만
조회하므로, 그래야 헤더가 바뀐 닉네임을 다시 읽는다.

### `MainFeature` (스택)

| 화면 | 다음 |
| :-- | :-- |
| 홈 | 방 진입(목록에서 고름·방 만들기·초대 코드) → 방 상세 push |
| 방 상세 | `closeTapped` → pop / 채팅 → 채팅 push / 사진 슬롯 탭 → 사진 상세 push / 설정 → 방 설정 push |
| 사진 상세 · 채팅 | `closeRequested` → pop |
| 방 설정 | `closeTapped` → pop / `coverEditRequested` → 커버 수정 push (인원수·커버는 스택 아래 방 상세에서 읽는다) |
| 커버 수정 | `closeTapped` → 저장된 커버(`savedCover`)를 아래 방 상세·홈 카드에 반영하고 pop |
| (스와이프 뒤로) | NavigationStack이 `.path(.popFrom(id:))`를 보내 `.forEach`가 뺀다 — 버튼과 같은 결과 |

- **위에서 바꾼 것은 아래에 직접 알려 준다.** 아래 화면이 살아 있어 새로 만들어지지 않으므로, 방 설정의 이름 변경
  (`rename` 드로어의 `renamed`)과 커버 저장 결과를 `MainFeature.State.updateRoom(id:_:)`가 스택 안 그 방의 상세 전부와
  홈 카드에 끼워 넣는다. 서버가 저장한 값이 액션에 실려 오므로 재조회하지 않는다.
- **커버 수정을 스와이프로 닫으면 대신 저장한다.** 커버 수정은 "뒤로 버튼 = 저장"인데 스와이프는 버튼을 거치지 않는다.
  `popFrom`은 부모 Reduce가 먼저 받고 `.forEach`가 그다음에 원소를 빼므로, 그 사이에 편집값을 읽어 아래 화면에
  낙관 반영하고 `UpdateRoomCoverUseCase`를 부른다. 실패하면 `roomCoverSaveFailed`로 저장 전 커버로 되돌린다
  (사용자는 이미 다른 화면이라 알리지 않는다). 성공하면 `roomCoverSaved`로 **한 번 더 반영한다** — 스와이프 직후 방 상세가
  다시 보이며 재조회하는데, 그 응답이 저장보다 먼저 처리되면 옛 커버로 덮이기 때문이다. 올리는 중이던 사진은 화면과 함께 끝나 실리지 않는다.
- 스택 안 화면은 전부 `CHALLATopNavigation`을 직접 그려 `MainView`가 시스템 바를 숨긴다. 바를 숨기면 꺼지는
  스와이프 뒤로가기는 `InteractivePopGestureEnabler`(`Sources/Main/`)가 루트에서 한 번 다시 켠다.
- 화면 하나를 스택에 추가하는 순서: `Path`에 case 1줄 → `MainView` destination 1줄 → 여는 delegate를 `MainFeature`에서
  `append` → `AppFeature`의 다리 case 삭제 → 옛 enum case·포장 struct 삭제.

## 초대 링크 진입 (`onOpenURL` · `PendingInviteCode`)

초대 링크로 앱이 열리면 `CHALLAApp`의 `.onOpenURL`이 URL을 `AppFeature.inviteLinkOpened`로
넘긴다 (SwiftUI 수명주기 앱은 유니버설 링크도 이 입구로 전달한다 — #100 실기기에서 확인.
카카오 로그인 복귀 URL만 SDK로 먼저 돌려보낸다). 들어오는 링크는 두 모양이다:

- 유니버설 링크 `https://challa.stellaris.co.kr/invite/{코드}` — 메모·문자 등에서 탭
- 커스텀 스킴 `challa://invite/{코드}` — 카톡 인앱 브라우저(웹뷰)에서는 유니버설 링크가
  앱을 못 열어, 서버 폴백 페이지의 "앱에서 보기" 버튼이 이 모양으로 쏜다 (Info.plist에
  `challa` 스킴 등록)

파싱은 `RoomDomain.InviteLink`가 한다 — 두 모양이 아니면 조용히 무시한다.

- **로그인 후** — 메인에 있으면 쌓인 화면을 비워 홈을 드러내고(홈은 새로 만들지 않는다), 메인 밖이면 메인을 새로
  만든 뒤 홈에 `inviteCodeReceived(code)`를 넘긴다. 입장(드로어와 같은 `JoinRoomUseCase`)·목록 반영·실패 얼럿까지
  홈이 맡고, 성공하면 `roomJoined`로 방 상세가 쌓인다. 서버는 이미 참여한 방도 성공(그 방 id)으로 준다
  (2026-09-05 실서버 확인) — 내 방 링크 = 그 방 열기다
- **로그인 전(스플래시·로그인·프로필 설정)** — 아직 입장할 수 없어 코드를 `PendingInviteCode`
  보관함에 넣어 두고, 홈에 도달하는 두 지점(프로필 조회 성공 · 프로필 설정 완료)이 꺼내 잇는다.
  보관함이 State가 아니라 의존성인 이유: `AppFeature.State`가 화면 enum이라 화면과 무관한 값을
  얹을 자리가 없다. 꺼내면 비워져 같은 코드로 두 번 입장하지 않고, 프로세스가 끝나면 사라진다
  (`forceUpdate`처럼 홈에 도달하지 못하는 화면에서 받은 코드는 그대로 소멸한다)

## 자동 로그인 · 토큰 갱신

버전 체크를 통과하면 `AppFeature`가 두 가지를 동시에 시작한다.

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

## 버전 체크와 강제 업데이트

실행 직후 `CheckAppUpdateUseCase`(`AppDomain`)로 버전을 체크한다 — 실구현은 `AppData.DefaultAppVersionRepository`
(`GET /api/v1/app/version`)이고 `CompositionRoot.registerAppUpdate`가 잇는다. 체크 실패는 **fail-open 정책**으로
`.notRequired`로 취급해 정상 진행하고, 강제 업데이트 필요 시만 `forceUpdate` state에 멈춘다.
`forceUpdate`는 **terminal state**이다 — 앱을 업데이트하거나 종료해야만 벗어난다.
응답에 실려 온 스토어 주소를 `forceUpdate(storeURL:)`에 담아 두고 알럿 '확인'이 연다 (nil이면 아무 것도 안 한다).

버전 체크만 공용 `HTTPClient`를 쓰지 않는다 — 로그인 전이라 토큰이 필요 없고,
스플래시를 잡아 두는 호출이라 타임아웃 3초짜리 전용 세션을 쓴다 (`registerAppUpdate` 주석 참고).

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
`AppFeatureTests`가 루트 전이표를, `MainFeatureTests`가 스택 규칙("뒤로 가도 아래 화면이 그대로" ·
버튼과 스와이프 pop이 같음 · 이름·커버 반영 · 스와이프 저장과 실패 되돌리기)을 TestStore로 고정한다.
`AppInviteLinkTests`는 초대 링크 분기(초대 링크 아님 무시 · 홈에서 즉시 입장 · 다른 방에서 스택 비우고 입장 ·
메인 밖에서 메인 새로 만들어 입장 · 로그인 전 보관 → 홈 도달 후 전달)를 본다.

스택 테스트에서 원소 id(`StackElementID`)를 `path[id: 0] = …`처럼 손으로 넣으면 테스트용 id 생성기가 그걸 모르고
같은 번호를 다시 발급해 덮어쓴다. 초기 상태는 `append`로 쌓아 번호를 소비시키고, 새로 쌓일 원소는 다음 번호로 기대한다.

## 의존 관계

- **이 앱이 의존**: `LoginFeature` · `ProfileSetupFeature` · `SettingFeature` ·
  `HomeFeature` · `RoomDetailFeature` · `PhotoDetailFeature` · `ChatRoomFeature` · `CameraFeature` ·
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

## RootFeature · RootView

`AppFeature`(화면 전환) 위에 화면과 무관한 것을 얹는 루트다. 지금 얹는 것은 **방 참여 토스트** 하나다 —
"방 참여 시 어떤 화면에 있든 상단 토스트" 정책이라 방 상세 화면이 아니라 여기가 주인이어야 한다.

구독은 사용자 단위 주소(`/user/queue/member-joined`) **하나**다. 방 개수와 무관하다.

- 구독 대상 목록은 **홈이 이미 받아 둔 방 목록**이다. 이 값을 쓰려고 목록을 따로 조회하지 않는다.
  지금은 구독 주소가 방과 무관하지만, 목록을 계속 보는 이유는 두 가지다 —
  토스트를 눌렀을 때 열 방을 여기서 찾고, 로그아웃·마지막 방 퇴장에 구독을 거둬야 한다.
  비교는 방 **id 목록**으로만 한다. `Room` 전체를 보면 사진 한 장에 `remainedPhotoCount`가 달라져
  전체 재구독이 돌고 그 사이 이벤트를 놓친다.
- 홈의 빈 목록은 `loadState`로 가른다. 조회 전의 빈 목록은 구독을 유지하고,
  조회가 끝난 뒤의 빈 목록(마지막 방 퇴장)에는 구독과 토스트를 함께 거둔다.
- **내 참여는 나에게 띄우지 않는다.** 사용자 단위 주소라 내가 들어간 것도 나에게 온다.
  판별은 `userId` 비교다 — 닉네임은 동명이인을 가리지 못한다.
- 같은 참여가 두 번 와도 한 번만 띄운다. 비교 키는 `(방 id, 닉네임)`이다.
  방 이름·프로필 URL·`userId`는 서버가 어느 주소로 보내느냐에 따라 실릴 수도 빠질 수도 있어,
  값 전체를 비교하면 같은 참여가 서로 다른 값이 되어 토스트가 두 번 뜬다.
- 토스트를 누르면 그 방으로 이동한다(`AppFeature.Action.openRoomRequested`). 메인에 있으면 `MainFeature`가
  쌓인 화면을 비우고 그 방 상세를 쌓는다 — push마다 새 원소라 방 A를 보다 방 B로 가도 뷰가 새로 만들어져 `.task`가 돈다.
  촬영 중에는 무시한다 — 찍고 있던 것이 사라진다.
- 참여 이벤트가 오면 **스택에 쌓인 그 방의 상세 전부**에 참여자를 다시 조회하라고 알린다(`memberJoined`) —
  위에 사진 상세·채팅이 덮여 있어도 돌아왔을 때 최신이어야 한다.
- 재연결(`.resumed`)에는 토스트를 띄우지 않는다. 그동안 누가 들어왔는지 알 수 없기 때문이다.
  대신 스택에 쌓인 방 상세가 있으면 참여자를 다시 조회하게 한다.
- 구독 실패는 얼럿 없이 정해진 횟수(3회·5초 간격)만 다시 건다. 재시도 예산은
  새로 구독을 걸 때와 `.resumed`를 받을 때 되돌린다 — 되돌리지 않으면 한 번 소진한 뒤로는
  어떤 장애에도 다시 시도하지 않는다.
