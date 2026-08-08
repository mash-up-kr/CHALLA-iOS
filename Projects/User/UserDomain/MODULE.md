# UserDomain

## 레이어와 책임

**Domain 레이어**. 유저 프로필 설정에 관한 순수 도메인 모듈이다 — 엔티티(값 타입), 순수 규칙(정책), 인터페이스(protocol),
Feature-facing UseCase를 정의한다. 서버·저장소의 존재를 모르며(import는 `Foundation` + `Dependencies`/`DependenciesMacros`뿐),
인터페이스의 구현은 전부 `UserData`가 맡는다(아키텍처 규칙 1: `Feature → Domain ← Data`).

**의존 주입 설계**: UseCase는 `@DependencyClient` + `TestDependencyKey`로 선언하고 **`liveValue`를
의도적으로 두지 않는다**. 라이브 구현을 채우려면 구체 어댑터(`DefaultUserRepository` 등)를 생성해야 하고,
그러려면 Data를 import해 규칙 2가 깨지기 때문이다. 반면 **오케스트레이션 로직(닉네임 검증 → 이미지 업로드 → 저장)은 이 Domain에 둔다** —
`SetupProfileUseCase.live(repository:uploader:)`가 의존성을 **인터페이스로만** 받아 순서를 조립한다(구체 타입 무의존).
`.live(...)`는 `testValue`·`previewValue`와 같은 `TestDependencyKey` extension에 둔다.
`UserData`의 public 어댑터를 만들어 이 팩토리에 넘기고 주입하는 일만 합성 루트(`CHALLAApp`·`ProfileSetupFeatureDemo`의 `CompositionRoot`)가 담당한다.

**동시성**: 모든 공개 타입은 값 타입 + `Sendable`이다 (`@unchecked` 미사용). Swift 6 strict concurrency에서 경고 없이 컴파일된다.

## 공개 API

폴더는 한 종류만 담는다 — `Entities/`는 엔티티, `Policy/`는 도메인 규칙, `Errors/`는 오류, `Models/`는 특정 경계 전용 입출력 구조, `Interface/`는 protocol, `UseCases/`는 유스케이스.

### Entities (`Sources/Entities/`)
여러 유스케이스·인터페이스가 공유하는 핵심 업무 데이터. 서버 응답이 바뀌어도 흔들리지 않는 것만 둔다.

- `struct UserProfile` — `id` · `nickname?` · `imageURL?`
  - `nickname`은 optional이다 — 서버는 프로필 최초 설정 전까지 닉네임을 내려주지 않는다
  - `isProfileCompleted: Bool` — `nickname != nil`. **앱 진입 시 첫 화면(프로필 설정 / 홈)을 고르는 유일한 기준**이며,
    로그인 응답의 `isNew`는 이 판별에 쓰지 않는다 (로그인 후 프로필 설정을 이탈해도 다음 실행에서 다시 잡아야 한다)

### Policy (`Sources/Policy/`)
입력 검증·정규화 규칙 — 서버·저장소와 무관한 순수 로직. Feature는 판단하지 않고 호출만 한다.

- `enum NicknameRule` — `maxLength = 10`
  - 서버(`UpdateProfileRequest`)는 1–20자를 허용하지만 **앱은 시안 기준 10자로 더 좁게 잡는다** (의도된 차이).
    서버 값에 맞춰 넓히지 말 것
  - `static func sanitize(_:String) -> String` — 입력 즉시 정리. **개행을 제거하고 나머지 입력은 그대로 보존한다** —
    값이 온전해야 `validate`가 "지금 이 값이 규칙을 어기는지"를 판정할 수 있고, 필드 테두리·제출 버튼이
    타이머가 아니라 입력값을 따라 실시간으로 바뀐다
  - `static func validate(_:String) -> Violation?` — 제출 가능 여부(nil이면 유효, 공백만은 `.empty`, 초과는 `.tooLong(limit:)`).
    길이는 grapheme cluster 수로 세며 공백도 1자다
  - `static func normalized(_:String) -> String` — 서버 전송용 정규화(앞뒤 공백 제거)
  - `enum Violation` — `.empty` · `.tooLong(limit:)` + `userMessage` (토스트 문구, maxLength와 함께 움직임)

### Errors (`Sources/Errors/`)
- `enum UserError` — `.invalidNickname(Violation)` · `.network` · `.unauthorized` · `.server(message:)` · `.unknown`
  - `userMessage` — 토스트용 최소 문구 (임의 작성본, 기획 확정 시 일괄 교체 예정)

### Models (`Sources/Models/`)
경계 하나만을 위한 입출력 구조.

- `struct ProfileDraft` — `nickname` (이미 normalized된 값) · `imageData?` (nil이면 기본 아바타 유지)

### Interface (`Sources/Interface/` — 구현: `UserData`)
protocol만 둔다.

- `protocol UserRepository` — 실패는 모두 `UserError`로 정규화해 던진다
  - `fetchMyProfile() async throws -> UserProfile` — 내 프로필 조회
  - `updateProfile(nickname:imageURL:) async throws -> UserProfile` — 프로필 설정·수정.
    이미지는 이미 올라간 공개 URL로 받는다 (바이트를 다루지 않는다)
  - `deleteAccount() async throws` — 회원 탈퇴 (해당 화면이 아직 없어 UseCase는 두지 않았다)
- `protocol ProfileImageUploader` — `upload(_:Data) async throws -> URL`.
  스토리지에 직접 올리는 다단계 절차라 저장소와 분리했다

### UseCases (`@DependencyClient` — liveValue 없음, 라이브 팩토리는 `.live(...)`)

- `SetupProfileUseCase` (`\.setupProfileUseCase`) — 닉네임 방어 검증 → 이미지 업로드 → 저장 순서를 조립한다.
  **업로드가 실패하면 저장으로 넘어가지 않는다** (사진 없는 프로필이 저장되면 사용자가 성공으로 오해한다)
  - `static func live(repository:uploader:) -> SetupProfileUseCase` — 의존성을 인터페이스로 받는 라이브 조립
  - `static let testValue` — unimplemented
  - `static let previewValue` — 닉네임만 받아 즉시 UserProfile 반환
- `FetchMyProfileUseCase` (`\.fetchMyProfileUseCase`) — 내 프로필 조회. 앱은 실행할 때마다 이걸 호출해 첫 화면을 정한다
  - `static func live(repository:any UserRepository) -> FetchMyProfileUseCase`
  - `static let testValue` — unimplemented
  - `static let previewValue` — 닉네임이 채워진 UserProfile 반환

## 의존성

- **이 모듈이 의존**: `Dependencies` · `DependenciesMacros`
- **이 모듈에 의존**: `ProfileSetupFeature`·`CHALLAApp`(UseCase 키를 `@Dependency`로 주입받아 사용) · `UserData`(protocol 구현체 제공)

## 계획 (미구현)

- 회원 탈퇴 UseCase — 탈퇴 화면 착수 시 추가 (`UserRepository.deleteAccount()`는 이미 구현돼 있다)

## 테스트 실행 방법

```bash
mise exec -- tuist test UserDomain
```

Swift Testing 기반 (시뮬레이터 불필요한 순수 유닛테스트).
