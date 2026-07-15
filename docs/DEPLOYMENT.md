# CHALLA 배포 전략

> **초안** — CI/CD 실 구현이 이슈 #8에서 진행 중이므로, #8 머지 시 이 문서를 실제 구현 기준으로 현행화한다.

## 앱 2개 = 완전히 별개의 배포

이 저장소는 실행 앱이 두 개이며, App Store Connect 입장에서 **서로 무관한 별개 앱**이다.

| | 실배포앱 | 디자인 시스템 검수앱 |
| :-- | :-- | :-- |
| 타깃/스킴 | `CHALLAApp` | `CHALLADesignSystemApp` |
| 번들 ID | `com.challa.app` | `com.challa.designsystem` |
| 표시 이름 | CHALLA | CHALLA 디자인 시스템 |
| 배포 대상 | 실사용자 | 디자이너 (TestFlight 내부 그룹) |
| 배포 주기 | 정식 릴리즈 단위 — 신중하게 | DS 변경 시마다 — 자주, 가볍게 |
| 배포 트리거(목표) | 릴리즈 태그 등 명시적 행위 | DS 코드 변경 PR이 main에 머지되면 자동 |

- 번들 ID는 초기 세팅부터 분리해뒀다 (CI/CD 붙일 때 안 꼬이게).
- 폴더 위치와 배포는 무관 — 검수앱이 `Projects/UI/` 아래 있어도 스킴만 Archive하면 독립 배포된다.

## 파이프라인 (이슈 #8 기준)

```
로컬:   pre-commit 훅 (staged 파일 포맷/린트)
PR:     GitHub Actions CI — lint → tuist generate → tuist test
머지 후: Xcode Cloud 배포 — ci_post_clone.sh (팀 ID 주입 · 빌드 번호 자동 증가)
```

- CI(품질 검사)는 GitHub Actions, 배포는 Xcode Cloud로 역할을 나눈다.
- 빌드 번호는 `CI_BUILD_NUMBER` 기반 자동 증가 — 수동 +1 커밋을 만들지 않는다.
- 세부 스크립트·워크플로우 구성은 #8 브랜치(`Scripts/`, `ci_scripts/`, `.github/workflows/`)가 원본.

## 수동 배포 (자동화 전 임시 절차)

검수앱을 수동으로 올려야 할 때:

1. `mise exec -- tuist generate` → Xcode에서 열기
2. 스킴 `CHALLADesignSystemApp`, 타깃 `Any iOS Device` 선택
3. Product > Archive → Organizer > Distribute App > App Store Connect > Upload
4. App Store Connect > TestFlight > 디자이너 그룹에 배포

### 사전 준비 (최초 1회)

- App Store Connect에 두 번들 ID로 각각 앱 등록
- `DEVELOPMENT_TEAM`은 `Configs/Shared.xcconfig`(gitignore)로 주입 — template 복사 후 값 채우기
- 앱 아이콘 1024pt (TestFlight 필수)

## 남은 결정 사항 (팀 논의)

- [ ] 실배포앱(`CHALLAApp`)의 배포 트리거 확정 — 릴리즈 태그? 수동 승인? (검수앱과 달리 신중해야 함)
- [ ] DS 변경 감지 path 필터 범위 — `Projects/UI/**`만 볼지, 폰트/애셋 리소스 변경도 포함할지
- [ ] TestFlight 그룹 구성 — 디자이너 외 QA 그룹 필요 여부
