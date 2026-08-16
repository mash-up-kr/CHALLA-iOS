# RoomDetailFeature

## 레이어와 책임

**Feature 레이어**. 방 상세 화면 — 방 정보 헤더, 참여자 아바타와 초대 코드 팝오버,
사진 슬롯 그리드, 인화 카운트다운을 그린다 (이슈 #57, 시안 4장 기준).

`RoomDomain`의 UseCase만 주입받고(규칙 2), 화면 전환(뒤로가기·촬영·채팅·사진 상세)은
전부 `delegate`로 App에 알린다(규칙 3).

> 구현 진행 중 — 리듀서·뷰가 채워지면 이 문서를 함께 갱신한다.

## 공개 API

- (예정) `RoomDetailFeature` — 리듀서. `State(room:)`으로 홈에서 받은 `Room`을 품고
  시작하며, 초대 코드·참여자는 진입 후 조회한다
- (예정) `RoomDetailView`

## 의존성

- **이 모듈이 의존**: `RoomDomain` · `ComposableArchitecture` · `CHALLADesignSystem`
- **이 모듈에 의존**: `CHALLAApp`(조립) · `RoomDetailFeatureDemo`(데모)

## 테스트 실행 방법

```bash
mise exec -- tuist test RoomDetailFeature
```
