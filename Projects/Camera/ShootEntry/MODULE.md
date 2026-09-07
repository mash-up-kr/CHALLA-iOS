# ShootEntry

## 레이어와 책임

**Feature와 Domain 사이의 공용 모듈**(Shared 성격 — 누구나 import 할 수 있다).
카메라 화면에 들어가기 전에 갖춰야 할 것을 한 벌로 받아 오고, 그 결과를 담는 묶음을 정의한다.

카메라 화면은 아무것도 스스로 조회하지 않는다(`CameraFeature/MODULE.md`). 그래서 진입 버튼이
방 목록·필터 목록·필터 LUT·카메라 권한·사진첩 저장 권한을 먼저 갖추고, 전부 성공했을 때만 넘어간다.
그 진입 버튼이 **홈의 촬영 뱃지**와 **방 상세의 사진 찍기** 두 곳이라, 두 피처가 같은 준비를 하도록
여기 한 벌만 두었다 — 피처끼리는 서로를 import 할 수 없다(규칙 3).

Domain에 두지 못하는 이유: 방(RoomDomain)과 필터·권한(PhotoDomain) 두 도메인을 함께 쓰는데
두 Domain 모듈은 서로를 모른다. Domain 하나가 다른 Domain을 끌어들이는 대신 위에 얇게 얹었다.

## 공개 API

- `struct CameraEntry` — 카메라 화면을 띄우는 재료(누른 방 id + 촬영 가능 방 목록 + 필터 목록).
  LUT는 이 묶음에 담지 않는다 — `CameraFilterCatalog`에 이미 등록돼 있다
- `enum ShootPreparationError` — 준비 실패
  (`.cameraPermissionDenied` · `.photoLibraryPermissionDenied` · `.loadFailed(message:)`)
  - `alert(openSettings:)` — 실패 안내 얼럿. 문구는 한 벌이고, 얼럿 액션 타입은 화면마다 달라
    설정 열기 액션만 받아 끼운다
- `struct ShootPreparation` — 준비 실행기
  - `init()` — 지금 의존성 컨텍스트에서 UseCase를 꺼내 온다. **리듀서가 이펙트를 만들기 전에** 만든다
  - `run(roomID:)` — 준비 결과(`Result<CameraEntry, ShootPreparationError>`). 취소되면 `CancellationError`

## 준비 규칙

- 조회(방 목록 · 필터 목록 → LUT)와 권한 요청을 **동시에** 건다 —
  권한 팝업이 떠 있는 동안에도 조회가 나가서, 사용자가 허용을 누를 때쯤이면 목록이 이미 와 있다
- 권한은 **카메라 → 사진첩(`.addOnly`) 순서로 이어서** 묻는다. 시스템 팝업은 한 번에 하나만 뜨고,
  카메라가 거절되면 사진첩은 묻지 않는다. 사진첩까지 막는 이유는 촬영본이 사진첩에 저장된 뒤
  업로드로 이어지기 때문이다 — 저장 권한 없이 들어가면 셔터를 누르는 족족 실패한다
- **권한 거절이 조회 실패보다 앞선다** — 둘 다 어긋나도 사용자가 먼저 할 일은 권한 허용이다
- LUT를 여기서 함께 받는 이유: 카메라 화면에서 받으면 필터 띠가 한동안 반쪽으로 뜬다.
  하나라도 실패하면 진입을 막는다 — 그 필터만 색이 안 먹는 화면은 고장으로 보인다

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `PhotoDomain` · `PhotoLibrary` · `ComposableArchitecture`(AlertState)
- **이 모듈에 의존**: `HomeFeature` · `RoomDetailFeature` · `CHALLAApp`(진입 요청으로 받는 `CameraEntry`)

## 알려진 임시 구현

- 얼럿 제목·버튼 문구는 임의 작성본이다 (기획 가이드 대기)

## 테스트 실행 방법

```bash
mise exec -- tuist test ShootEntry
```

화면이 없는 순수 로직이라 시뮬레이터 없이 돈다. 성공 결과, 권한 거절 2종, 사진첩 제한 허용 통과,
카메라 거절 시 사진첩을 묻지 않는지, 조회·LUT 실패 문구, 권한 거절 우선순위를 검증한다.
