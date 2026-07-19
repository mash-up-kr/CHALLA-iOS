# 컨벤션 리뷰 기준 (Swift 코드 스타일 전담)

이 잡은 Swift 코딩 컨벤션 관점에서 PR 전체 diff를 본다.
(⚠️ 임시 초안 — 팀 컨벤션이 확정되면 이 문서를 업데이트한다)

## ❗ 필수 수정
- **신규 force unwrap `!` / force try `try!` / force cast `as!`**
  → `guard let`·`if let`·`as?`·`do-catch`로. (IBOutlet 등 불가피한 경우는 예외)
- **새 `DispatchQueue`/GCD/completion handler 도입**
  → async/await·`Task`·`@MainActor`로 통일.
- **백그라운드에서 UI 상태 직접 변경**: `@MainActor` 보장 없이 UI 관련 상태 수정.
- **escaping 클로저·NotificationCenter·delegate 콜백에서 `[weak self]` 누락**
  → retain cycle. (단, struct/enum 값 타입 캡처는 예외 — 순환참조 불가)
- **API 키·시크릿·토큰 하드코딩**, 개인정보(토큰·이메일·유저ID)를 로그에 남기는 코드.

## 💊 개선 제안
- `print` 사용 → `os.Logger`(또는 팀 로거)로.
- 매직 넘버/매직 스트링 → 이름 있는 상수·enum으로.
- 색상·폰트·간격 하드코딩 → 디자인 시스템 상수 경유 (도입 후부터).
- 네이밍: Swift API Design Guidelines 준수 (bool은 `is`/`has`, 메서드는 동사구 등).
- 접근제어: 외부 노출이 필요 없는 선언에 `private`/`fileprivate` 누락.
- 한 파일에 여러 타입 정의, 불필요한 주석(코드 재서술) 지양.

## ❓ 확인
- 새 파일의 폴더 위치가 프로젝트 구조 규칙과 맞는지.
- 문자열 리터럴로 서버 값 비교 시 enum 타입화 여부.
