# AppDomain

## 레이어와 책임

**Domain 레이어**. 앱 자체(버전 정책 등) aggregate의 규칙과 인터페이스를 둔다.
화면(Feature) 하나에 속하지 않는 "앱 전체" 관심사라 `App` 그룹 아래에 있다.

현재 내용물은 버전 체크 하나다 — 실행 직후 서버에 현재 버전을 물어
강제 업데이트 여부를 판정한다.

## 공개 API

- `enum AppUpdateRequirement` — `notRequired` / `forced(storeURL: URL?)`.
  `recommended`(권장 업데이트)가 없는 이유는 타입 주석 참고 (정책·시안 부재 — 죽은 코드 방지)
- `protocol AppVersionRepository` — `checkUpdateRequirement(currentVersion:)`.
  실패를 도메인 오류로 정규화하지 않는다 — 호출부(AppFeature)가 모든 실패를
  `.notRequired`로 접는 **fail-open**이라 사용자에게 보일 오류 문구가 없다
- `struct CheckAppUpdateUseCase` (`@DependencyClient`) —
  `live(repository:currentVersion:)`. 현재 버전은 조립 시점에 Bundle에서 읽어 넘긴다
  (Domain은 Bundle을 모른다)

## 의존성

- **이 모듈이 의존**: `Dependencies`·`DependenciesMacros` (swift-dependencies)
- **이 모듈에 의존**: `AppData`(구현) · `CHALLAApp`(조립·사용)

## 테스트 실행 방법

```bash
mise exec -- tuist test AppDomain
```

Swift Testing 기반 순수 유닛테스트(시뮬레이터 불필요).

- `CheckAppUpdateUseCaseLiveTests` — 조립 시점 버전 전달, 실패 무정규화 통과
