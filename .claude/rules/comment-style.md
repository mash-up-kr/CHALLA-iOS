---
paths: Projects/UI/**/*.swift
---

# 주석 컨벤션 (디자인 시스템)

목표: 주석만 훑어도 파일 구조와 설계 판단이 한눈에 들어오게 한다.
새로 발명한 규칙이 아니라 FilmCard · PrintCard · ProfileBar에서 정착된 패턴을 그대로 옮긴 것이다.

## 한 줄 판단 기준

**"코드만 읽어서는 알 수 없는 정보인가?"** — 아니면 쓰지 않는다.

- 코드가 하는 일의 재서술 금지 (`// 버튼을 그린다` 류)
- 학습용 해설 금지 (API 사용법 강의는 주석이 아니라 문서의 몫)
- 이름으로 자명한 값은 주석을 생략한다 — 주석은 의무가 아니다 (예: `barPadding`)

## 언어·어투

- 한국어, "~한다" 평어 종결. 비유·조어 금지, 번역투 금지.
- 영어는 API 이름 인용과 고유명사(Figma, HIG, VoiceOver)만.

## 역할 분리

- `///` doc comment = **공개 계약** — 무엇인가, 어떤 정책인가. 타입 · init · 프로퍼티 · metric 상수에 단다.
- `//` 인라인 = **구현 이유** — 왜 SwiftUI에서 이렇게 해야 하는가 (함정 · 순서 의존 · 비직관 동작)만.

```swift
// 좋은 인라인 — 코드로 알 수 없는 순서 의존을 설명 (CHALLATextButton)
// 배경 모디파이어보다 앞에 있어야 배경·터치 영역이 함께 늘어난다
.frame(maxWidth: isFullWidth ? .infinity : nil)

// 나쁜 인라인 — 코드 재서술
.frame(height: size.height) // 높이를 설정한다
```

## 파일 구조

- Xcode 헤더 배너(`// Created by ...`) 금지. `import` → 빈 줄 → 타입 doc으로 시작한다.
- 파일 최상단에 MARK를 두지 않는다 (첫 선언의 타입 doc이 파일 소개를 겸한다).
- 타입 doc 구성: 첫 줄 한 문장 요약 → (정책이 여럿이면) 불릿 목록 → (public View 컴포넌트만) ` ```swift ` 사용 예 블록.

## MARK 섹션 — 구조 기준 차등

- **필수**: public View 컴포넌트 파일, 그리고 100줄 이상 파일.
- **생략 가능**: 소형 enum · 값 타입 · 내부 지원 타입 (ButtonRole, DrawerAction, ButtonBackground 등).

표준 시퀀스 (해당 없는 섹션은 건너뛴다):

```swift
// MARK: - 공개 타입          ← Variant 등 동반 public 타입이 있으면
// MARK: - 표기 규칙          ← 표시 문자열 가공 규칙이 있으면
// MARK: - 프로퍼티와 init
// MARK: - Body
// MARK: - <고유 섹션>        ← private 서브뷰·계산 덩어리. 뷰 계층 덩어리 이름으로 (예: 레이어, 낱장 스택)
// MARK: - Figma 실측값       ← 파일 하단 private enum XxxMetric 앞
```

- metric enum 섹션명은 항상 `Figma 실측값`으로 통일한다 (`수치` 등 다른 이름 금지).
- 대형 metric enum 내부의 서브그룹은 하이픈 없는 `// MARK: 이름`을 쓴다 (예: ProfileBar의 `// MARK: 바`).
- 명시적 init이 없는 타입은 `프로퍼티와 init` 대신 `// MARK: - 프로퍼티`로 줄인다.
- 파일 하단 extension으로 여는 API 진입점은 API 이름을 MARK로 단다 (예: `// MARK: - Color(hex:)`, `// MARK: - challaDrawer`).

## 프로퍼티 · 계산속성 · 메서드

- 첫 줄은 명사형 짧은 요약, 근거가 필요하면 이어서 "~한다" 문장으로.

```swift
/// 가로:세로 필름 비율. 세로를 직접 받지 않고 항상 가로 ÷ 이 값으로 계산해
/// 어떤 폭에서도 필름 모양이 깨지지 않게 한다. (Figma 실측 82 × 109.33 = 3:4)
public static let aspectRatio: CGFloat = 3.0 / 4.0
```

- enum 케이스는 `케이스명 — 설명` 대시 패턴.

```swift
/// 촬영 전 — 사진이 없는 빈 슬롯. dashed 테두리만 그린다.
case beforeCapture
```

- public View 컴포넌트의 init은 `- Parameters:` 필수, 전 파라미터를 나열한다 (누락이 실수인지 의도인지 구분되지 않으므로).
  설명에는 판단 근거까지 담는다 — nil의 의미, 기본값과 다르게 줄 때가 언제인지.
- 값 타입 · 토큰의 단순 init은 `- Parameters:` 생략 가능.
- `- Returns:` · `- Note:` · `- Important:` 는 쓰지 않는다.

## 관용구

- 미확정 값: **`시안 육안 근사값 — 디자이너 검수로 확정한다`** — TODO/FIXME 대신 이 문구를 쓴다.

## 장황함 기준

- 줄 수가 아니라 **정보 밀도**로 판단한다. 모든 줄이 코드로 알 수 없는 설계 근거면 5줄 doc도 유지하고
  (예: FilmCard `fillPhoto`의 blur 처리 설명), 재서술이면 1줄도 지운다.
- 설계 판단 기록은 보존 대상이다 (예: DrawerPresentation의 "네이티브 .sheet를 쓰지 않는 이유").

## 갤러리 앱 (CHALLADesignSystemApp)

- 파일 헤더 doc은 고정 포맷: `<그룹> > <이름> 검수 화면.` + 검수 범위 한 줄.

```swift
/// Component > Button 검수 화면.
/// variant × size × 활성/비활성 조합을 전수 나열한다 (Figma textButton·iconButton 18조합씩).
```

- MARK · 상세 doc은 선택 — DS 본체보다 가볍게 유지한다.
