# SettingFeature

## 레이어와 책임

**Feature 레이어**. 설정 화면(이슈 #35)과 그 하위 화면 3종(테마 · 알림 · 계정 관리)의
TCA Feature와 SwiftUI 뷰를 담는다.

하위 화면은 별도 모듈이 아니라 **이 모듈 안의 child reducer**다. 설정 안에서 시작해 설정 안에서
끝나고 다른 화면이 재사용하지 않아서, 모듈로 쪼개면 조립 비용만 늘어난다.
그래서 `SettingFeature`가 `StackState<Path.State>`를 직접 소유하고 push/pop을 관리한다.

App에 올리는 `delegate`는 **설정 밖으로 나가야 하는 것**뿐이다 — 프로필 편집,
뒤로가기, 그리고 앱 전체를 되돌려야 하는 로그아웃·탈퇴 완료.
프로필 편집은 `ProfileSetupFeature`의 편집 모드이며 `CHALLAApp`이 화면을 교체해 띄운다.

`SettingData`를 import 하지 않는다 (규칙 2) — UseCase 8종을 `@Dependency`로만 꺼내 쓴다.

## 공개 API

- `struct SettingFeature: Reducer` — 설정 메인 + 하위 화면 스택
  - `State` — `profile`(원격, 실패 시 `nil`) · `theme`(`@Shared(.appTheme)`) ·
    `isLoading`(프로필 조회 중) · `alert` · `path`
    - `themeDisplayName` — 테마 행에 표시할 값. 항상 값이 있다
  - `view(.onAppear)`은 프로필만 읽는다. 테마는 `@Shared`가 저장소를 직접 읽어 불러오는 단계가 없다
  - `Action.ViewAction` — `onAppear` · `editProfileButtonTapped` · `themeRowTapped` ·
    `notificationRowTapped` · `accountRowTapped` · `supportRowTapped` · `feedbackRowTapped` · `backButtonTapped`
  - `Action.Delegate` — `editProfileRequested` · `backRequested` · `signedOut` · `accountDeleted`
  - 찰나 응원하기 · 피드백 보내기는 delegate가 아니라 `@Dependency(\.settingExternalLinks)`의
    주소를 `@Dependency(\.openURL)`로 직접 연다 (App이 조립할 것이 없는 외부 링크다)
  - `@Reducer enum Path` — `.theme` · `.notification` · `.account`.
    `public`인 이유는 데모앱이 특정 하위 화면으로 바로 진입할 때 `path`에 직접 넣기 때문이다
- `struct ThemeFeature` — `State()`, delegate 없음
  - 고른 값을 `@Shared(.appTheme)`에 직접 쓴다. 설정 화면과 앱 루트가 같은 값을 읽으므로
    부모에게 알릴 것이 없다 (아래 "설정 저장은 누가 하나" 참고)
  - 고른 뒤 **화면을 닫지 않는다**. 결과가 화면에 남고, 잘못 눌렀을 때
    그 자리에서 다시 고를 수 있다 (iOS 설정 앱의 단일 선택 목록과 같은 동작)
- `struct NotificationSettingFeature` — `State()`, delegate 없음
  - 토글 ON 색은 부모가 시드하지 않는다. 뷰가 `@Environment(\.challaTheme)`로 읽는다
  - `showsPermissionBanner` — 권한이 `.authorized`가 아닐 때만 `true`.
    조회 전(`systemAuthorization == nil`)에는 `false`다 — 띄웠다 사라지면 깜빡인다
  - `view(.sceneBecameActive)` — 설정 앱에 다녀온 뒤 권한을 다시 읽는다.
    뷰가 `@Environment(\.scenePhase)`로 보낸다
- `struct AccountFeature` — `State(profile:)`, `Delegate.signedOut` · `.accountDeleted`
  - `Drawer` — `.signOutConfirmation` · `.deleteConfirmation` · `.deleteCompleted`.
    한 번에 하나만 뜬다(모디파이어를 두 개 걸면 A를 내리는 애니메이션과 B를 올리는 애니메이션이 겹친다)
  - 로그아웃·탈퇴 모두 **진행 중에는 드로어를 유지하고 버튼만 비활성으로** 만든다.
    먼저 닫으면 응답이 올 때까지 화면에 아무 변화가 없고, 탈퇴는 중간에 빈 화면이 보인다
  - 진행 중에는 뒤로가기도 막는다 — 나가면 TCA가 이 화면의 이펙트를 취소해
    성공도 실패도 오지 않는다
  - `isDrawerDismissable` — 딤 탭·드래그로 내릴 수 있는지. 완료 드로어와 진행 중에는 `false`
- `struct SettingView` — `init(store:)`. `NavigationStack`을 소유하고 하위 화면 셋을 destination으로 그린다
- `struct ThemeView` · `struct NotificationSettingView` · `struct AccountView` — 각각 `init(store:)`.
  `SettingView`가 직접 그리므로 App이 만들 일은 없지만, 데모앱 프리뷰·검증을 위해 `public`으로 연다
- `AppTheme.themeColor` (`Sources/Support/`) — `AppTheme` → 강조 색 매핑 6쌍.
  Domain은 UI를 모르고 DS는 Domain을 모르므로 둘 다 아는 이 레이어가 갖는다.
  앱 루트가 이 색으로 `CHALLATheme`을 만들어 `\.challaTheme`에 주입한다
- `SharedKey.appTheme` (`Sources/Support/SharedKeys.swift`) — 테마 저장 키.
  설정 화면·테마 화면·앱 루트가 이 하나를 함께 읽는다. 저장 키 문자열은 이 파일에만 둔다

## 설정 저장은 누가 하나

**앱 전체가 쓰는 설정은 `@Shared`가 저장한다(테마). 이 화면 안에서 끝나는 설정은 자식이 저장한다(알림).**

- 테마는 설정 밖의 화면도 전부 써야 해서, 값을 넘겨주는 대신 저장소를 직접 읽는 `@Shared`로 둔다.
  읽는 곳이 늘어도 전달 경로를 새로 만들 필요가 없다
- `@Shared`는 쓰는 즉시 저장되므로 "고르자마자 뒤로가기"에서 값이 유실되지 않는다.
  저장 이펙트가 없어 이펙트 취소를 신경 쓸 일도 없다
- 알림 설정은 이 화면 밖에서 쓰지 않아 UseCase 그대로 둔다 — 자식이 직접 저장한다

## 내부 결과 액션 이름 규칙

**실패 경로가 있으면 `~Response(Result<_, SettingError>)`, 없으면 `~Loaded`.**
성공/실패가 `Void`라 `Result`를 못 쓰는 경우만 `~Succeeded`/`~Failed`로 나눈다
(`AccountFeature` — `Void`는 `Equatable`이 아니다).

## 네비게이션 소유권 제약

`SettingView`가 `NavigationStack`을 소유한다. 따라서 **App은 이 뷰를 다른 `NavigationStack` 안으로
push 하면 안 된다** — 중첩 `NavigationStack`은 SwiftUI에서 동작이 깨진다.
뷰 교체(`AppView`의 현재 방식) · `fullScreenCover` · 탭 중 하나로 띄운다.

### 내부 구성 (`Sources/Components/`)

- `SettingProfileHeader` — 아바타 + 닉네임 + 편집 버튼 (설정 메인, 가로 배치)
- `ProfileAvatar` — 회색 원 + 실루엣. 설정 메인과 계정 관리가 공유한다.
  크기(68)를 파라미터로 열지 않았다 — 쓰는 곳 둘 다 같은 값이고 실루엣 아이콘이 지름과 함께
  움직여야 해서 지름만 바꾸게 열면 비율이 깨진다
- `AccountProfileSummary` (`Sources/Account/Components/`) — 아바타 + 닉네임 (계정 관리, 세로 중앙 배치).
  `SettingProfileHeader`와 값은 같지만 배치가 달라 합치지 않고 아바타만 공유한다
- 셋 다 디자인 시스템에 올리지 않았다. 재사용처가 설정 안뿐인데 DS에 넣으면 검수앱 갤러리에
  Variant를 나열할 의무가 붙는다 (`.claude/rules/design-system.md`). 다른 화면에서도
  같은 블록이 필요해지면 그때 승격한다

## 시안 대비 알려진 차이

- **이메일을 표시하지 않는다** — 시안에는 닉네임 아래 `hap****@naver.com` 형태로 있지만
  서버가 이메일을 내려주지 않는다 (`GET /api/v1/users/me` 응답은 `id · nickname · profileImageUrl`뿐).
  마스킹 주체가 서버인지 클라이언트인지도 정해지지 않았다. 서버 계약에 추가되면 되살린다

- **행 leading 아이콘 색** — Zeplin `List / Arrow` 컴포넌트 정의는 `Label.neutral`(#AEAFB4)인데
  설정 화면 인스턴스는 `Label.alternative`(#74767B)다. 검증이 화면 기준이라 화면을 따르고
  `CHALLAListRow`의 `iconColor` 오버라이드로 처리했다. **디자이너 확정 필요**
- **탑 내비게이션에 타이틀이 없다** — `CHALLATopNavigation.sub(title: "")`로 처리했다.
  DS에 타이틀 없는 variant를 추가할지는 디자이너 확인 후 판단
- **아바타 이미지를 아직 그리지 않는다** — `SettingProfile.avatarURL`을 받아두지만 화면은 항상
  기본 아바타(회색 실루엣)를 그린다. 이미지 로딩 모듈(#25 `CHALLAImageKit`)이 들어온 뒤 연결한다
- **토글 ON 색** — 시안(`ref_notification.png`)은 밝은 회색이지만 켜짐 배경은 `themeColor`로 그린다.
  테마 색이 맞다고 확정됐다 (2026-08-01).
- **계정 관리 하단 `탈퇴하기` 버튼 색** — 시안은 흐린 회색인데 `CHALLATextButton(variant: .transparent)`의
  글자색은 `Label.normal`(#F7F7F8)이라 더 밝다. `role: .destructive`는 빨강이고 `.disabled(true)`는
  탭이 막혀 둘 다 맞지 않는다. transparent variant의 약한 강조 글자색은 **DS 별도 이슈**로 남긴다
- **알림 권한 배너를 `CHALLAListSection` + `CHALLAListRow`로 그린다** — 시안의 배너는 리스트 카드가
  아니라 별도 `info` 컴포넌트다(배경 `Background.level3` · 높이 56 · 글자 14/16 · 좌 안여백 20).
  리스트 카드로 그리면 배경 `level1` · 높이 72 · 글자 16/20 · 좌 안여백 24가 된다.
  새 DS 컴포넌트를 만들지 않는 이번 범위의 결정이고, **DS에 `info` 배너 컴포넌트 추가**가 필요하다
- **테마 화면 바닥의 테마색 번짐** — 시안(`ref_theme.png`)에만 있는 장식이라 `ThemeView`가 직접 그린다.
  Figma 수치(390×254 타원 · 블러 300)를 그대로 옮기면 시안보다 훨씬 옅게 나온다 —
  타원 바닥이 한 점으로 좁아져 화면 맨 아랫줄에 원래 색이 거의 없고 큰 블러가 그마저 퍼뜨린다.
  그래서 *결과*에 맞춰 타원을 가로로 1.25배 늘리고 세로 중심을 화면 바닥선에 두었다(블러 60).
  실측 바닥 중앙 rgb(36,40,15) / 좌우 끝 rgb(32,35,16) — 시안 rgb(36,39,16) / rgb(32,36,16).
  다른 화면에도 같은 배경이 필요해지면 DS로 승격할 후보다
- **스와이프 백 제스처가 없다** — 세 화면 모두 `CHALLATopNavigation`을 직접 그려
  destination에 `.toolbar(.hidden, for: .navigationBar)`를 건다. 그 부작용으로 시스템 제스처가 사라진다.
  되살리려면 `interactivePopGestureRecognizer` 대리자를 손대야 해서 DS/App 차원의 별도 결정이 필요하다
- **로그아웃 확인 드로어 문구는 임의 작성본이다** — 시안에 로그아웃 행 탭 이후가 없다.
  되돌리려면 재로그인이 필요해 확인 단계를 넣었다. 문구 확정 필요 (`AccountFeature`의 TODO)
- **찰나 응원하기 · 피드백 보내기를 눌러도 아직 아무 일이 없다** — App ID와 구글폼 주소가 없어
  `SettingExternalLinks.liveValue`의 두 값이 `nil`이다. 플레이스홀더를 넣으면 존재하지 않는 페이지가
  실제로 열리므로 값이 정해질 때까지 열지 않는다 (해당 파일의 TODO)
- **접근성 글꼴은 `accessibility1`까지만 대응한다** — 시안이 픽셀 고정 명세라 행 높이(52·74)와
  프로필 블록(100)이 상수인데 `challaFont`는 Dynamic Type을 따라 커진다. 그 이상에서 글자가
  잘리므로 네 화면 루트에 `.dynamicTypeSize(...accessibility1)` 상한을 건다
  (`SettingLayout.maxDynamicTypeSize`). 유동 높이 대응은 DS 차원의 별도 결정이다

## 알려진 트레이드오프

**프로필 조회가 실패하면 헤더만 빈 채로 남는다.** 테마·알림·계정 관리는 그대로 동작한다 —
프로필과 테마를 따로 읽으므로 원격 실패가 로컬 값을 끌고 가지 않는다.
계정 관리 화면의 닉네임은 부모 프로필을 시드로 받아 함께 비어 있고, 그 화면 안에
복구 경로는 없다 (로딩·실패 중 하위 화면 진입 정책은 별도 이슈).

**프로필 조회에 실패하면 화면 안에서 재시도할 수 없다.** 얼럿 버튼이 "확인" 하나뿐이고,
`onAppear`가 `profile == nil`에서만 동작하므로 화면을 벗어났다 다시 들어와야 다시 시도된다.
재시도 버튼을 넣을지는 얼럿 문구 정책과 함께 정할 사안이다 (`SettingFeature.swift`의 TODO 참고).

## 의존 관계

- **이 모듈이 의존**: `SettingDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `SettingFeatureDemo` (추후 `CHALLAApp`)

## 테스트 실행

```bash
xcodebuild -workspace CHALLA.xcworkspace -scheme SettingFeature \
  -destination 'platform=iOS Simulator,name=<시뮬레이터>' test
```

## 데모앱

```bash
xcrun simctl launch booted com.challa.settingfeature.demo --screen setting --state default
xcrun simctl launch booted com.challa.settingfeature.demo --screen theme --theme raspberry
xcrun simctl launch booted com.challa.settingfeature.demo --screen notification --state permissionOff --serviceNotification on
xcrun simctl launch booted com.challa.settingfeature.demo --screen account --state drawerSignOut
```

- `--screen` — `setting` · `theme` · `notification` · `account`. 하위 화면은 `path`에 미리 쌓아 띄운다
- `--state` — 화면별로 `setting`: `default`·`loading`·`error` / `notification`: `permissionOff`·`permissionOn` /
  `account`: `default`·`error`·`drawerSignOut`·`drawerConfirm`·`drawerCompleted` / `theme`: `default`뿐.
  (모든 화면의 합집합 enum이고 `--screen`과 짝이 맞지 않는 값은 무시된다.
  `loading`·`error`는 프로필에만 걸린다 — 설정 화면에서 실패할 수 있는 값이 그것뿐이다)
- `--theme` — `lemonade` · `raspberry` · `orange` · `cider` · `blueberry` · `acaiBowl`
- `--serviceNotification` — `on` · `off`. 서비스 알림 토글의 초기값 (시스템 권한과 별개다)

`--theme`·`--serviceNotification`은 저장값보다 우선한다 — 두 값 모두 실제 `UserDefaults`에서
읽으므로, 인자가 없으면 이전 실행에서 남은 값이 화면을 바꿔 같은 명령이 다른 결과를 낸다.

알림 권한과 설정 앱 열기는 **항상 스텁**이다 — 시뮬레이터 권한 상태에 따라 배너가 흔들리면
시안 대조가 불가능하고, 실제로 설정 앱이 열리면 캡처 흐름이 끊긴다.
시안 검증(`zeplin-ui-verification`)이 이 인자로 각 상태를 캡처한다.
