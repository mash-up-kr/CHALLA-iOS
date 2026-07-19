---
paths: Projects/**
---

# 아키텍처 의존성 규칙

상세 배경: `docs/ARCHITECTURE.md` (레이어: App / DIContainer / Feature / Domain / Data / Network / Core / UI / Shared)

## 6대 규칙 (위반 코드를 쓰지도, 승인하지도 말 것)

1. `Feature → Domain ← Data` — Data가 Domain의 Repository 인터페이스를 구현한다.
2. Feature는 Data를 import 하지 않는다 — `@Dependency`로 주입받고, 구현체 등록(liveValue/testValue/previewValue)은 DIContainer 폴더에서 한다.
   (예외: 피처 데모앱 `Demo/`는 앱 조립 지점이므로 Mock/실 Data 주입 가능)
3. Feature끼리 직접 참조하지 않는다 — 화면 전환·조립은 App(AppFeature)이 담당한다.
4. Core · Shared는 누구나 import 가능하다.
5. `CHALLADesignSystem`은 Feature를 import 하지 않는다 (맨 아래 UI 레이어).
6. `CHALLANetwork`는 Data만 import 한다 — Feature·Domain은 서버의 존재를 모른다.

## 위반 상황별 올바른 해법

- Feature에서 Data의 타입/API가 필요하다 → Domain에 인터페이스(UseCase·Repository)를 추가하고 Feature는 `@Dependency`로 그것만 꺼내 쓴다. 구현은 Data에, liveValue 등록은 DIContainer 폴더에.
- Feature A에서 Feature B의 화면을 열고 싶다 → A가 B를 import 하지 말고, App 레이어의 네비게이션 조립에 위임.
- Domain에서 네트워크 호출이 필요하다 → Domain에는 인터페이스만. 실제 호출은 Data가 CHALLANetwork로 수행.

## 새 모듈이 생길 때

- 레이어 판별 한 줄 규칙: **시뮬레이터 없이 유닛테스트가 돌면 Shared, OS를 만지면 Core, 서버를 만지면 Network.**
- 모듈 간 의존 선언은 `Tuist/ProjectDescriptionHelpers/Dependency/DependencyInfo.swift`에 헬퍼를 추가해 호출부에서 명시한다.
- Domain·Data는 화면 단위가 아니라 aggregate(방) 단위로 1벌만 만든다 (예: RoomDomain 하나가 Room 관련 5개 Feature를 지탱).
