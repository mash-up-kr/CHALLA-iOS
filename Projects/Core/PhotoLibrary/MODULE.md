# PhotoLibrary

## 레이어와 책임

**Core 레이어**. Photos 프레임워크를 감싸 기기 사진첩에 이미지를 추가한다.
권한 요청(`.addOnly`)과 저장이 전부이며, 사진을 읽거나 목록을 훑는 기능은 없다.

도메인 프로토콜(`PhotoDomain.PhotoLibraryWriting`)을 여기서 채택하지 않는다 —
`Keychain`이 `TokenStore`를 모르는 것과 같은 이유로, Core는 OS만 감싸고 도메인 인터페이스에
맞추는 어댑터는 Data(또는 앱 조립 지점)가 만든다. `PhotoData`가 생기기 전까지는
`PhotoDetailFeatureDemo`의 `CompositionRoot`가 그 어댑터를 들고 있다.

## 공개 API

| API | 설명 |
| :-- | :-- |
| `PhotoLibraryStore` | `save(imageData:)` — 권한 요청까지 포함한 저장. `PHPhotoLibrary.requestAuthorization(for: .addOnly)` → `PHAssetCreationRequest`로 원본 바이트를 그대로 추가한다 (UIImage로 만들면 메타데이터가 날아가고 재인코딩된다) |
| `PhotoLibraryError` | `permissionDenied` · `saveFailed` |

쓰는 쪽은 Info.plist에 `NSPhotoLibraryAddUsageDescription`이 있어야 한다 — 없으면 권한 요청 순간 앱이 죽는다.

## 의존성

- **이 모듈이 의존**: 없음 (Photos는 시스템 프레임워크)
- **이 모듈에 의존**: `PhotoDetailFeatureDemo` (앞으로 `CHALLAApp` · `PhotoData`)

## 테스트 실행 방법

테스트 타깃이 없다. 이 모듈의 코드는 전부 권한 팝업과 시스템 사진첩 상태에 의존해서
유닛테스트로 고정할 만한 순수 로직이 없다 — 동작 확인은 데모앱을 시뮬레이터에서 실행해
다운로드 버튼 → 권한 팝업 → 사진 앱에 저장됐는지까지 눈으로 본다.
