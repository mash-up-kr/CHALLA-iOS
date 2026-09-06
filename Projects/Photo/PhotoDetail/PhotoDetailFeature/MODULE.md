# PhotoDetailFeature

## 책임

방의 사진 조회, 리액션 생성·삭제, 사진 저장, 사진 메시지 전송을 담당하는 TCA Feature다.
PhotoDomain과 ChatDomain의 UseCase를 주입받으며, 화면 닫기는 App에 위임한다.

## 공개 API

- `PhotoDetailFeature.State`: 방 정보, 인화 여부, 사진 목록과 선택 사진, 저장·메시지 전송 상태, 드로어·토스트·얼럿.
- `reactionsLoaded` / `reactionsLoading`: 사진별 리액션 조회 캐시와 진행 상태.
- `reactionsUpdating`: 변경 요청과 후속 조회가 진행 중인 사진. 같은 사진의 추가 생성·삭제를 제한한다.
- `reactionsNeedRefresh`: 변경 후 서버 상태를 다시 확인해야 하는 사진. 조회 실패 시에도 유지한다.
- `Drawer.deleteReaction(photoID:reactionID:)`: 내 스티커 삭제 확인.
- `ReactionBurst`: 리액션 애니메이션의 ID와 종류.
- `Action.view`: 화면 진입, 사진 이동, 저장, 리액션 생성·삭제, 메시지 입력·전송.
- `Action.delegate.closeRequested`: App에 화면 닫기를 요청한다.
- `PhotoDetailView.init(store:)`: 화면에 Store를 주입한다.
- `StickerLayout.placements(for:)`: 사진 ID와 스티커 표시 ID로 위치·각도를 계산한다.
- `StickerPlacement`: 사진 크기에 대한 좌표 비율과 회전 각도.

## 동작 규칙

- 진입 시 사진 목록을 받고, 선택한 사진의 리액션만 조회한다. 조회 결과는 사진별로 캐시한다.
- 인화 전 사진은 블러 처리하며 다운로드 버튼을 숨긴다.
- 사용자별로 같은 종류의 리액션 중복 생성을 막는다. 스티커는 개수 제한 없이 표시하고 리액션 바는 가로로 스크롤한다.
- 생성·삭제는 화면에 먼저 반영하고 요청 실패 시 복구한다.
- 같은 사진의 변경 요청은 직렬 처리한다. 삭제 후에는 재조회까지 추가 변경을 제한한다.
- 초기 조회 중 생성하면 이전 조회를 취소하고, 생성 요청이 끝난 후 다시 조회한다.
- 생성 성공 응답에 채팅 ID가 없으면 재조회한다. 조회 실패 후에는 스티커·리액션 재탭 또는 사진 재선택으로 재시도한다.
- 스티커의 표시 ID는 생성 응답과 재조회 후에도 유지한다. 삭제에는 별도 채팅 ID를 사용한다.
- 내 스티커는 확인 드로어를 거쳐 삭제한다. 다른 사용자의 스티커는 안내 토스트를 표시한다.
- 메시지는 선택한 사진에 전송하며 입력창을 비운다. 성공 시 2초 동안 완료 토스트를 표시한다.
- 저장 중에는 중복 요청을 막고 스피너를 표시한다. 사진첩 권한 거부 시 설정 이동 버튼을 제공한다.
- 목록 조회 실패는 얼럿에서 재시도할 수 있다.

## 의존성

- ComposableArchitecture, PhotoDomain, ChatDomain, CHALLADesignSystem.
- 실행 앱의 CompositionRoot가 UseCase 구현을 주입한다.

## 테스트

```bash
mise exec -- tuist test PhotoDetailFeature
```

- PhotoDetailPhotoTests: 목록 조회, 실패·재시도, 사진 선택.
- PhotoDetailReactionTests: 생성·롤백, 초기 조회 취소, 누락된 채팅 ID 복구.
- PhotoDetailReactionDeleteTests: 삭제 확인·복구, 변경 요청과 후속 조회 직렬화.
- StickerLayoutTests: 위치 범위, 생성 응답·재조회·삭제 후 위치 유지.
- PhotoDetailMessageTests, PhotoDetailSaveTests: 메시지 전송과 사진 저장 결과.
