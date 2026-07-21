---
paths: Projects/**/*.swift
---

# 디자인 시스템 사용 규칙

상세 배경: `docs/DESIGN_SYSTEM.md`

## 토큰만 사용

- Feature 등 다른 모듈에서 `Color(hex:)`, `Font.custom` 원시 호출 금지 → `CHALLAColor.xxx`, `CHALLATypography.xxx` 토큰만 사용한다.
- 원시 호출이 허용되는 유일한 위치: `Projects/UI/CHALLADesignSystem/Sources/Foundation/` 내부.
- 색상·폰트·간격 하드코딩을 발견하면 토큰 추가를 먼저 제안한다 (토큰이 없다고 하드코딩하지 말 것).

## 디자인 시스템 모듈 순수성

- `CHALLADesignSystem`은 순수 SwiftUI 모듈로 유지한다 — Feature import 금지, 서비스 로직 금지.
- 검수 카탈로그 화면(갤러리)은 `CHALLADesignSystemApp`에 만든다. DS 모듈 안에 검수 전용 코드를 섞지 않는다.
  (개발용 `#Preview`는 DS 모듈 안에 둬도 됨)
- 새 컴포넌트/토큰을 추가하면 검수앱 갤러리에 해당 Variant(상태 조합)를 수동으로 나열한다 — 누락 시 디자이너 검수가 불가능해진다.
