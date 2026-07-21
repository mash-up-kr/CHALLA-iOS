# CHALLA 아키텍처

CHALLA iOS 프로젝트의 모듈 구조와 의존성 규칙을 정리한 문서입니다.
Tuist 기반 모듈화 + 개발자 3명 협업을 전제로 설계되었습니다.

> **v1.1** — Network를 Core에서 분리(Data 전용 레이어), 트리에 (폴더)/(모듈)/(앱) 표기 도입,
> 앱·데모앱을 메인 트리에 통합. 시각 도식: [docs/architecture.html](./architecture.html)

---

## 설계 원칙

- **Feature는 화면 단위로 잘게** 유지 → 3명이 화면별로 나눠 작업, Git 충돌 최소화
- **Domain · Data는 aggregate(방) 단위로 1벌** → 엔티티 중복 제거
- **Feature → Domain ← Data** 단방향 의존
- **Feature는 Data를 직접 import 하지 않음** → `@Dependency`로 주입 (구현체 등록은 DIContainer 폴더)
- **Feature끼리 직접 참조 금지** → 네비게이션은 App이 조립

### 왜 이렇게 나눴나 (핵심 의사결정)

모듈을 잘게 유지하면 협업 병렬성은 좋지만, `Room`/`Participant`/`FilmStatus` 같은
엔티티가 여러 Domain에 중복되는 문제가 생김.
→ **Feature는 화면별로 그대로 두고, Domain·Data만 방(Room) 단위로 합치는** 방식으로 해결.
`RoomRepository` 인터페이스를 여러 모듈이 나눠 구현하면 오히려 어색하므로,
Data는 aggregate 단위로 묶는 것이 자연스럽다.

---

## 모듈 구조

표기: **(폴더)** = 그룹용 디렉터리(프로젝트 아님) · **(모듈)** = Tuist 프로젝트(프레임워크 타깃) · **(앱)** = 실행 가능한 앱 타깃

```
Projects/
├─ App/                              (폴더) 앱 실행 · 전체 흐름 조립
│  ├─ CHALLAApp                      (앱)   실배포앱 — 모든 Feature 조립
│  ├─ AppFeature                     (모듈) 로그인/프로필/메인 진입 분기 + 루트 네비게이션
│  ├─ AppView                        (모듈) 최상위 SwiftUI View
│  └─ DependencyAssembly             (모듈) DIContainer 실행
│
├─ DIContainer/                      (폴더) 의존성 조립 전용
│  ├─ LiveDependency                 (모듈) 실제 구현체 등록
│  ├─ TestDependency                 (모듈) 테스트용 Mock 등록
│  └─ PreviewDependency              (모듈) 프리뷰용 더미 등록
│
├─ Auth/                             (폴더) 인증
│  ├─ OnboardingFeature              (모듈) 온보딩 화면
│  ├─ LoginFeature                   (모듈) 로그인 화면 (카카오/애플)
│  │   └─ Demo/                      (앱)   피처 데모앱 — Mock 주입 · 로컬 실행 전용
│  │                                        ※ 모든 XxxFeature가 같은 패턴으로 Demo/를 가질 수 있음
│  ├─ AuthDomain                     (모듈) AuthToken · 로그인 규칙 · AuthRepository(interface)
│  └─ AuthData                       (모듈) 소셜 SDK · 로그인 API · TokenProvider 구현(Keychain 사용)
│
├─ User/                             (폴더) 유저 · 프로필
│  ├─ ProfileSetupFeature            (모듈) 최초 프로필 설정 화면
│  ├─ ProfileEditFeature             (모듈) 프로필 수정 화면
│  ├─ UserDomain                     (모듈) User · Profile · UserRepository(interface)
│  └─ UserData                       (모듈) 유저 조회/수정 API 구현
│
├─ Home/                             (폴더) 홈  (Domain/Data 없음)
│  └─ HomeFeature                    (모듈) 방 목록 · Empty · 생성/입장/상세 진입
│                                          └ RoomDomain.fetchRooms 재사용
│
├─ Room/   ⭐                        (폴더) 도메인/데이터 통합 · Feature는 화면별 유지
│  ├─ RoomDomain                     (모듈) ★ 방 도메인 공용 — Feature 5개가 공유
│  │   ├─ Entities/                        Room · Participant · InviteCode · RoomID
│  │   │   └─ FilmStatus                   촬영중 · 인화대기 · 완료  ← Film 도메인 흡수
│  │   ├─ RoomRepository                   인터페이스 1개
│  │   └─ UseCases/                        FetchRooms · Create · Join · Invite · Detail · DevelopFilm · Setting
│  ├─ RoomData                       (모듈) RoomRepository 구현 1개 + DTO 매핑
│  ├─ RoomCreateFeature              (모듈) 방 이름 · 색상 · 필름 장수 설정
│  ├─ RoomJoinFeature                (모듈) 초대코드 입력 · 입장
│  ├─ RoomInviteFeature              (모듈) 초대코드 표시 · 공유
│  ├─ RoomDetailFeature              (모듈) 방 상세 · 참여자 · 남은 장수
│  │                                        ├ 인화대기/완료 = 이 화면의 "상태"  ← FilmWaiting/Completed 흡수
│  │                                        └ 결과 사진 목록 = 이 화면의 그리드   ← PhotoResult 흡수
│  └─ RoomSettingFeature             (모듈) 방 이름 수정 · 나가기 · 삭제
│
├─ Camera/                           (폴더) 촬영  (Domain/Data 없음)
│  └─ CameraFeature                  (모듈) 셔터 · 플래시 · 전후면 · 장수 카운트
│                                          ├ 장수 제한   → RoomDomain
│                                          ├ 업로드 큐   → PhotoData (PhotoDomain UseCase 경유)
│                                          └ 촬영 장치   → Core/Camera
│
├─ Photo/                            (폴더) 사진 결과
│  ├─ PhotoDetailFeature             (모듈) 사진 상세 · 리액션 · 다운로드
│  │                                        └ 결과 목록은 RoomDetailFeature로 흡수
│  ├─ PhotoDomain                    (모듈) Photo · Reaction · PhotoRepository(interface)
│  └─ PhotoData                      (모듈) 사진 조회/업로드/리액션 API 구현
│
├─ Setting/                          (폴더) 앱 설정
│  ├─ SettingFeature                 (모듈) 약관 · 피드백 · 로그아웃 · 회원탈퇴 · 테마
│  ├─ SettingDomain                  (모듈) 설정 항목 · 계정 관리 규칙
│  └─ SettingData                    (모듈) 피드백 전송 · 회원탈퇴 API 구현
│
├─ Network/  ★신규                   (폴더) 서버 통신 — Core에서 분리 (Data 전용 레이어)
│  └─ CHALLANetwork                  (모듈) Endpoint · HTTPClient · Interceptor
│                                          ├ NetworkError → AppError 매핑
│                                          └ TokenProvider(protocol) 정의 — 구현은 AuthData
│                                    # 모듈명 "Network"는 Apple Network.framework와 충돌 → CHALLA 접두
│
├─ Core/                             (폴더) OS/디바이스 래핑 인프라 (Network 제외)
│  ├─ Keychain                       (모듈) 범용 보안 저장소 — 토큰은 손님 중 하나
│  ├─ Camera                         (모듈) AVFoundation 래핑
│  ├─ Permission                     (모듈) 카메라/사진첩/푸시 권한
│  ├─ FileStorage                    (모듈) 임시 파일 · 캐시
│  ├─ Logger                         (모듈) os.log 래핑 — Core여도 전 레이어 공용
│  └─ Share                          (모듈) iOS 공유하기
│
├─ UI/                               (폴더)
│  ├─ CHALLADesignSystem             (모듈) 순수 SwiftUI UI 모듈 (Feature import 금지)
│  │                                        → 자세한 내용은 DESIGN_SYSTEM.md 참고
│  └─ CHALLADesignSystemApp          (앱)   검수앱 — DS 카탈로그 · TestFlight 별도 배포
│
└─ Shared/                           (폴더) UI 없는 순수 공통 코드 — import Foundation만
   ├─ HGFoundation                   (모듈) Extension · EntityID · AppError · Validator
   └─ HGResources                    (모듈) 공통 리소스 접근 헬퍼

Tuist/
└─ Package.swift                     # 외부 패키지 (모듈 아님) — TCA · Firebase · Kingfisher · KakaoSDK …
```

---

## 원본 구조 대비 바뀐 점

| 변경 | 이유 |
| :-- | :-- |
| `Room*Domain` 5개 → `RoomDomain` 1개 | 엔티티를 한 모듈에서 공용, 중복 차단 |
| `Room*Data` 5개 → `RoomData` 1개 | `RoomRepository`를 한 곳에서 구현 |
| `FilmDomain` 삭제 → `Room.filmStatus` 흡수 | 인화 상태는 방의 상태 |
| `HomeDomain/Data`, `CameraDomain/Data` 삭제 | Home은 `RoomDomain.fetchRooms` 재사용 / Camera는 Room·Photo·Core 재사용 |
| Feature 모듈은 전부 그대로 | 화면 단위 유지 → 협업 병렬성 확보 |
| `Core/Network` → `Network/CHALLANetwork` 분리 (v1.1) | 변경 빈도가 Core와 다름 · Data 전용 · Keychain/Logger 의존으로 생기는 Core 내부 의존 제거 |

---

## 레이어 의존성

```
        ┌──────────────────────────────────────────────┐
        │  App (CHALLAApp · AppFeature) — 조립 · 진입 분기 │
        └───────────────────────┬──────────────────────┘
                                │ import
     ┌──────────────┬───────────┼───────────┬──────────────┐
     ▼              ▼           ▼           ▼              ▼
 HomeFeature   RoomXxxFeature  CameraFeature  PhotoXxxFeature  ...
     │              │              │              │
     └──────────────┴──────┬───────┴──────────────┘
                          │ import (인터페이스만)
              ┌───────────▼───────────────────────────────┐
              │  *Domain (Entity · UseCase · Repository)     │
              └───────────▲───────────────────────────────┘
                          │ implements
              ┌───────────┴───────────────────────────────┐
              │  *Data (RepositoryImpl · DTO · Mapper)       │  ← Feature는 import 금지
              └───────────┬───────────────────────────────┘
                          │ import (Data 전용)
              ┌───────────▼───────────────────────────────┐
              │  Network (CHALLANetwork)                     │  ← Feature·Domain은 import 금지
              └───────────┬───────────────────────────────┘
                          │
              ┌───────────▼────────────┐
              │  Core · Shared (모두 공유)  │
              └────────────────────────┘
```

### 규칙 요약

1. `Feature → Domain ← Data` (Data가 Domain 인터페이스를 구현)
2. Feature는 Data를 import 하지 않음 (`@Dependency`가 주입 — 등록은 DIContainer 폴더)
3. Feature끼리 직접 참조 금지 (네비게이션은 App이 조립)
4. Core · Shared는 누구나 import 가능
5. `CHALLADesignSystem`은 Feature를 import 하지 않음 (맨 아래 UI 레이어)
6. `CHALLANetwork`는 Data만 import — Feature·Domain은 서버의 존재를 모름

---

## Core vs Shared vs Network 판별 기준

한 줄 규칙: **시뮬레이터 없이 유닛테스트가 돌아가면 Shared, OS를 만지면 Core, 서버를 만지면 Network.**

### 사이드 이펙트(side effect)란?

함수가 "입력을 받아 결과값을 계산해 돌려주는 것" 이외에 **바깥세상(OS·기기·서버)을 읽거나 바꾸는 것**.

```swift
// 사이드 이펙트 ✕ (순수) — 같은 입력이면 항상 같은 출력 · 바깥세상을 안 건드림 → Shared
Validator.isValidNickname("정욱")   // true/false 계산이 전부

// 사이드 이펙트 있음 — 호출하면 앱 바깥의 상태가 바뀌거나, 바깥 상태에 따라 결과가 달라짐 → Core
keychain.save(token)               // 기기 보안 저장소에 기록이 남음 (앱 삭제 후에도 남을 수 있음)
logger.info("로그인 성공")          // 시스템 로그에 남음
camera.capture()                   // 하드웨어 작동 · 파일 생성
```

순수 코드는 어디서든 테스트되고 누가 import해도 무해하므로 맨 아래(Shared)에 모으고,
사이드 이펙트는 Core·Network에 격리해 **"바깥세상을 만지는 일은 전부 여기"** 라는 것을 구조로 드러낸다.

> **"Core"라는 이름에 대해** — Clean Architecture 문헌에서는 순수한 Domain을 "core(중심)"라 부르고
> 사이드 이펙트를 가장 바깥 링에 둔다(Functional Core, Imperative Shell). 반면 iOS 진영은
> CoreData·CoreLocation처럼 **Core = 저수준 기술 래핑**이라는 Apple 관례를 따르며, 이 문서의 Core도 그 의미다.
> 이름만 다를 뿐 배치 원칙(순수 규칙은 Domain에, 사이드 이펙트는 가장자리에 격리)은 양쪽이 동일하다.

| 레이어 | 성격 | import 가능 대상 | 소속 모듈 |
| :-- | :-- | :-- | :-- |
| Shared | 순수 코드 · 사이드 이펙트 ✕ · `import Foundation`만 | 없음 | HGFoundation · HGResources |
| Core | OS/디바이스 접점 · 사이드 이펙트 있음 | Shared | Keychain · Camera · Permission · FileStorage · Logger · Share |
| Network | 서버 접점 · **Data 전용** | Core · Shared | CHALLANetwork |

- **Core와 Shared는 둘 다 전 레이어 공용**이다(규칙 4). 차이는 접근 범위가 아니라 코드 성격.
  Logger가 Core인 이유는 `os.log`(사이드 이펙트) 때문이고, Core여도 누구나 쓸 수 있으므로 실사용엔 차이가 없다.
- **Keychain은 Network의 부속이 아니라 범용 보안 저장소**다. 토큰은 저장되는 손님 중 하나이며,
  토큰의 저장/삭제 주체는 로그인 흐름을 아는 `AuthData`다.
- **토큰 흐름** — Network는 키체인의 존재를 모른다. 테스트 시 가짜 TokenProvider만 주입하면 된다:

  ```
  Network  ──"토큰 줘"──▶  TokenProvider (protocol, Network가 정의)
                                ▲ 구현
  AuthData ── Keychain(Core)에 저장/삭제 ──┘   (@Dependency 등록으로 연결)
  ```

---

## 주의할 모듈 경계 (설계상 애매한 지점)

1. **Camera → Photo 업로드 경계**
   `CameraFeature`는 `PhotoData`를 직접 못 쓰므로(규칙 2), `PhotoDomain`의
   UploadUseCase를 통해 업로드한다. Camera가 Photo의 UseCase에 의존하는 형태.

2. **RoomDetail이 무거워짐**
   참여자 + 남은 장수 + 인화 상태 + 결과 사진 그리드를 모두 흡수 →
   `RoomDetailFeature`가 가장 큼. 필요 시 내부에서 child reducer로 분리.

---

## 앱 · 데모앱 배치 전략

실행 가능한 앱(`.app`)은 성격에 따라 위치를 나눈다. 규칙 한 줄:
**실배포앱은 `App/`, 데모/검수앱은 대상 모듈 옆에.**

| 앱 종류 | 위치 | 설명 |
| :-- | :-- | :-- |
| **실배포앱** (`CHALLAApp`) | `Projects/App/` | 최종 프로덕트. 모든 Feature를 조립한 독립 앱 |
| **디자인시스템 검수앱** (`CHALLADesignSystemApp`) | `Projects/UI/` (DesignSystem 옆) | 디자인시스템 전용 카탈로그. DS에 종속되므로 같은 세트로 묶음 |
| **피처 데모앱** (`XxxFeatureDemo`) | 각 피처 모듈 안 `Demo/` | 해당 피처만 단독 실행/검증. Mock 데이터로 구동 |

```
Projects/
├─ App/
│  └─ CHALLAApp/                    # 실배포앱 (실서비스)
├─ UI/
│  ├─ CHALLADesignSystem/           # 디자인시스템 모듈
│  └─ CHALLADesignSystemApp/        # 검수앱 (DS 옆에 세트로) — TestFlight 별도 배포
└─ Room/
   └─ RoomFeature/
      ├─ Sources/                   # 피처 구현
      └─ Demo/                      # 피처 데모앱 (이 피처만 단독 실행)
         ├─ Sources/
         └─ Resources/
```

### 데모앱 원칙
- **위치**: 데모는 "대상 모듈에 붙인다". 피처 데모 → 그 피처 폴더 안 `Demo/`.
- **정의**: 데모앱은 그 모듈이 의존하는 실제 코드 + 필요한 Data(Mock 주입용)만 의존한다.
  Feature는 자기 Data를 직접 import 하지 않지만(규칙 2), **데모앱만은 예외로**
  Mock/실 Data를 주입해 단독 실행할 수 있게 한다. (앱 조립 지점이므로)
- **배포**: 데모앱은 원칙적으로 로컬 실행/검증용. 배포가 필요한 것은 검수앱(`CHALLADesignSystemApp`)이다.

### 배포 독립성
폴더 위치와 배포는 무관하다. 배포는 **타깃 + 번들ID** 기준이므로,
`CHALLADesignSystemApp`이 `UI/` 아래에 있어도 해당 스킴만 Archive하면 독립 배포된다.
자세한 배포 절차는 `DESIGN_SYSTEM.md`의 "검수앱 TestFlight 배포" 참고.
