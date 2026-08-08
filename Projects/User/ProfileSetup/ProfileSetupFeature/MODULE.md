# ProfileSetupFeature

## 레이어와 책임

**Feature 레이어**. 프로필 **설정과 편집**을 한 모듈이 `mode`로 처리한다.
닉네임 입력·검증(`UserDomain.NicknameRule` 호출)·프로필 사진 선택·제출·환영 연출을 담당하고,
완료 후 화면 전환은 `delegate`로 App에 위임한다(아키텍처 규칙 3).

`docs/ARCHITECTURE.md`에 `ProfileEditFeature`가 계획으로 적혀 있지만 별도 모듈로 만들지 않았다 —
화면 구성이 거의 같아 쪼개면 컴포넌트를 공유 모듈로 빼거나 복제해야 한다.
모듈명은 `ProfileSetupFeature`를 유지한다 (리네임이 Tuist 헬퍼·데모앱·경로까지 번진다).

`UserData`를 import 하지 않는다(규칙 2). 라이브 구현 등록은 실행 앱의 `CompositionRoot`가 담당한다.
사진 접근 권한은 Core 레이어의 `PhotoLibrary` 모듈을 `@Dependency`로 주입받는다(규칙 4).

## 공개 API

### ProfileSetupFeature (`@Reducer`)

#### State (`@ObservableState`)
- `mode: Mode = .setup` — `.setup`(최초 설정) / `.edit`(편집)
- `nickname: String = ""` — 입력값
- `imageData: Data?` — 새로 고른 프로필 이미지
- `remoteImageURL: URL?` — 서버에 저장된 이미지 URL (편집 진입 시 부모가 시드).
  **표시용이자 저장용이다** — 사진을 안 건드렸을 때 이 URL을 되돌려 보내야 서버가 기존 사진을 지우지 않는다
- `isPhotoRemoved: Bool = false` — 사진 삭제를 눌렀는지.
  `imageData == nil` 하나로는 "안 건드림"과 "지움"이 구분되지 않는다
- `isPhotoMenuPresented: Bool = false` — 사진 메뉴 드로어 표시 여부
- `isPhotoPickerPresented: Bool = false` — 시스템 사진 피커 표시 여부 (권한 승인 후에만 켠다)
- `photoPickerItem: PhotosPickerItem?` — 피커가 돌려준 선택 항목. 읽어들인 뒤 리듀서가 nil로 되돌린다
- `isNicknameFocused: Bool = false` — 뷰의 @FocusState와 .bind로 동기화
- `phase: Phase = .editing` — 상태 기계 (`editing` / `submitting` / `welcome`)
- `toast: ToastState?` — 표시 중인 토스트
- `savedProfile: UserProfile?` — 제출 성공 결과

**파생값 (computed)**
- `isSubmittable: Bool` — `NicknameRule.validate(nickname) == nil`
- `nicknameViolation: NicknameRule.Violation?` — != nil → 필드 빨간 테두리.
  **값에서 파생**하므로 입력과 함께 실시간으로 풀린다(저장 프로퍼티가 아니다).
  빈 값(`.empty`)은 오류로 칠하지 않는다 — 아직 안 쓴 것이지 잘못 쓴 것이 아니다
- `isCTAVisible: Bool` — `phase != .welcome` (편집·제출 중에는 빈 값이어도 자리를 지킨다)
- `isCTAEnabled: Bool` — `phase == .editing && isSubmittable`
- `isCTALoading: Bool` — `phase == .submitting`
- `isFieldEditable: Bool` — `phase == .editing`
- `showsCameraBadge: Bool` — `phase != .welcome`
- `canRemovePhoto: Bool` — 새로 고른 사진이 있거나, 서버 사진이 아직 지워지지 않았을 때
- `avatarImageURL: URL?` — 아바타에 그릴 서버 이미지. 지웠으면 nil
- `imageChange: ProfileImageChange` — 저장 시 서버에 전달할 사진 처리 방식.
  새 사진 > 삭제 > 원본 유지 순으로 판단한다
- `showsBackButton: Bool` — 편집 모드의 편집 단계에서만 `true`
- `showsWelcome: Bool` — 환영 연출은 최초 설정에만 있다

**nested**
- `enum Phase: Equatable, Sendable` — `.editing` / `.submitting` / `.welcome`
- `enum Mode: Equatable, Sendable` — `.setup` / `.edit`
- `struct ToastState: Equatable, Sendable` — `message: String`

#### Action

- `case binding(BindingAction<State>)` — `nickname` · `isNicknameFocused` 양방향 바인딩
- `enum ViewAction` — 사용자 이벤트
  - `task` — 화면 진입(`.task`) → 닉네임 필드에 포커스를 잡아 바로 키보드 입력을 받는다.
    편집 단계이고 드로어·사진 피커가 떠 있지 않을 때만 동작한다
    (환영 화면은 읽기 전용, 오버레이가 떠 있으면 키보드가 그 위를 덮는다)
  - `profileImageButtonTapped` — 아바타 탭 → 사진 메뉴 드로어 열기
  - `photoMenuDismissed` — 드로어 '닫기' 버튼
  - `albumSelectTapped` — '앨범에서 선택' → 권한 요청
  - `photoRemoveTapped` — '프로필 사진 삭제'
  - `nicknameSubmitted` — 키보드 return
  - `backgroundTapped` — 빈 곳 탭
  - `startButtonTapped` — CTA 탭
  - `backButtonTapped` — 편집 모드의 뒤로가기. 제출 중에는 막는다
    (나가면 이펙트가 취소돼 성공도 실패도 오지 않는다)
- `case view(ViewAction)`
- `enum Delegate: Equatable, Sendable` — parent(App)와의 통신 채널
  - `setupCompleted(UserProfile)` — 최초 설정 완료. 환영 화면 종료 = 다음 화면으로 진행해도 좋다는 신호
  - `editCompleted(UserProfile)` — 편집 저장 완료. 환영 연출을 거치지 않고 바로 올린다
  - `cancelled` — 편집을 버리고 나갔다
- `case delegate(Delegate)`
- `case submitResponse(Result<UserProfile, UserError>)` — 서버 응답
- `case photoAuthorizationResponse(PhotoLibraryAuthorization)` — 사진 권한 요청 결과
- `case photoLoadResponse(Data?)` — 고른 사진을 읽어들인 결과 (nil이면 실패)
- `case toastDismissed` — 토스트 자동 소멸
- `case welcomeFinished` — 환영 화면 자동 종료

#### 동작 규칙
- **필드 테두리와 CTA 활성 여부는 입력값에서 파생한다** — 토스트 타이머와 무관하게 입력 즉시 바뀐다
- 토스트가 2초 뒤 사라져도 값이 여전히 초과면 빨간 테두리·비활성은 유지된다 (안내만 거둘 뿐)
- 값이 규칙을 만족하는 순간 토스트도 즉시 사라진다(타이머 취소)
- 빈 값이면 CTA 비활성 (단 빈 값은 빨간 테두리로 칠하지 않는다)
- CTA는 진입 직후부터 계속 보이고, 빈 값이면 비활성으로 둔다 (환영 화면에서만 감춘다).
  시안 `…de01`은 초기 상태에 CTA가 없지만, 다음 단계가 보이지 않는다는 판단으로 항상 노출하기로 정했다
- 제출 중 중복 탭은 가드와 `cancelInFlight`로 무시
- 환영 화면 2초 후 자동으로 delegate 발화
- 아바타 탭은 `phase == .editing`일 때만 사진 메뉴를 연다 (제출 중·환영 중에는 사진을 바꿀 수 없다)
- 사진 메뉴는 등록된 사진이 있을 때만 '프로필 사진 삭제'를 낸다 (`canRemovePhoto`)
- '앨범에서 선택'은 드로어를 먼저 닫고 권한을 요청한다 — 승인(`authorized`·`limited`)이면 피커, 아니면 안내 토스트
- 드로어는 딤 위에 얹히는 오버레이라 뒤 화면이 그대로 남는다 (`.challaDrawer`)

### ProfileSetupView (`@ViewAction`)

프로필 설정 화면 조립. 배경 → (환영 시) 글로우 → 내비 + 폼 순의 ZStack에 토스트를 상단 overlay로 얹는다.
뷰는 상태 렌더링과 `send(...)` 전달만 한다 — 입력 정리·토스트·CTA 판단은 전부 리듀서 책임.

- `init(store: StoreOf<ProfileSetupFeature>)`

### Components (internal)

store를 모르는 재사용 파라미터 뷰들.

#### ProfileFormView

프로필 폼 (헤드라인 + 카드 + CTA) — store를 모르는 파라미터 뷰.

- `init(headline:avatar:showsCameraBadge:nickname:focus:fieldMode:cta:onAvatarTap:)`

**세로 배치**: CTA 슬롯은 항상 바닥에 고정하고, 그 위(헤드라인 + 카드)만 스크롤 영역이다.
여유가 있으면 `minHeight`로 종전처럼 가운데 정렬이고, 모자랄 때만 스크롤된다.
작은 화면(iPhone SE)에서 키보드가 올라오면 콘텐츠가 남는 높이를 약 100pt 넘겨 **CTA가 화면 밖으로 밀려나던 문제**를 막는다.
넘칠 때는 `defaultScrollAnchor(.bottom)`으로 장식인 헤드라인 쪽이 잘리고 입력 카드는 온전히 남는다.

#### ProfileFormModels

- `struct ProfileFormHeadline` — `highlighted: String?` (lime 강조 첫 줄) · `text: String` (나머지 줄, 개행 가능)
- `enum ProfileAvatarSource` — `.placeholder` / `.local(Data)` / `.remote(URL)`.
  `.remote`는 편집 모드에서 서버에 저장된 사진을 그릴 때 쓴다
- `enum ProfileNicknameFieldMode` — `.editable` / `.invalid` / `.readOnly`
- `struct ProfileFormCTA` — `title: String` · `isEnabled: Bool` · `isLoading: Bool` · `action: () -> Void`

#### ProfileAvatarView, ProfileNicknameField, WelcomeGlowView

각각 아바타, 닉네임 입력 필드, 환영 배경 글로우를 담당하는 컴포넌트.

토스트는 이 모듈에 두지 않는다 — 디자인 시스템의 `CHALLAToast`를 쓰고, 표시 시간(2초)과 위치(내비 아래 70)만 여기서 정한다.

## 의존성

- **이 모듈이 의존**: `UserDomain` · `PhotoLibrary` · `ComposableArchitecture` · `CHALLADesignSystem` · `PhotosUI`(시스템)
- **이 모듈에 의존**: `ProfileSetupFeatureDemo`(데모앱) · `CHALLAApp`(예정, 추후 App 조립 시)

> 이 Feature를 담는 앱 타깃은 `Info.plist`에 `NSPhotoLibraryUsageDescription`이 있어야 한다 — 없으면 권한 요청 시점에 크래시한다.

## 계획 (미구현)

- **`Components/`를 공유 모듈로 빼지 않았다** — 편집을 별도 모듈로 만들었다면 `Projects/User/ProfileFormUI/`로
  승격할 계획이었지만, 같은 모듈에 `mode`로 넣어 소비자가 하나뿐이라 뺄 이유가 없다.
  세 번째 화면이 같은 폼을 필요로 하면 그때 승격한다
  (store를 모르므로 파일 이동 + `public` 선언만으로 충분. 규칙 3·5 위반 없음)

## 테스트 실행 방법

```bash
mise exec -- tuist test ProfileSetupFeature
```

Swift Testing 기반. TestStore를 활용한 리듀서 상태 변화·이펙트 검증. 관심사별 3개 스위트로 나눠 둔다:

- `ProfileSetupFeatureTests` — 화면 진입 포커스 · 닉네임 입력/검증/토스트 · CTA 가드
- `ProfileSetupPhotoTests` — 사진 메뉴 · 권한 · 피커 결과 반영
- `ProfileSetupSubmitTests` — 제출 · 환영 연출 · delegate 발화 · 오류

TestStore 조립과 닉네임 길이 상수는 `Tests/Support/ProfileSetupTestSupport.swift`가 공유한다.
