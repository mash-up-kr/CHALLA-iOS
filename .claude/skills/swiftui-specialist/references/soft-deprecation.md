# Soft-Deprecated APIs

SwiftUI에는 "soft deprecated" 상태인 API가 여러 개 있습니다. soft-deprecated API는 SDK 헤더에서 deprecated로 표시되어 있지만, deprecation 버전이 `100000.0`으로 지정되어 있습니다 — 이는 compiler 경고를 억제하면서도 새로운 코드에서는 더 이상 사용하지 말아야 함을 나타내는 placeholder입니다.

## Scoping rule — 가장 먼저 읽어주세요

이 문서의 모든 soft-deprecation 가이드는 직접 수정하는 코드로 scope가 한정됩니다. 파일에 여러 view가 포함되어 있고 사용자의 작업이 그중 하나에만 해당하는 경우, 다른 view들은 out of scope입니다.

**할 일**: 수정한 view(들)에 대해서만 논의하십시오. 응답은 code output 다음에 *변경한 사항*에 대한 reasoning 순으로 구성하십시오. 그 외에는 아무것도 포함하지 마십시오.

**하지 말아야 할 일**: out-of-scope 코드에 있는 soft-deprecated API에 대해 언급하거나, 표시하거나, 코멘트하거나, migration을 제안하거나, 질문하지 마십시오. 여기에는 "OtherView를 NavigationStack으로 migration 하시겠습니까?"와 같은 후속 질문도 포함됩니다 — 해당 view를 수정하지 않았다면 언급하지 마십시오. Scoping rule은 "observations"나 "other notes"를 요청하는 어떤 prompt보다도 우선합니다.

**이유**: 사용자가 변경을 요청하지 않은 코드에서 soft-deprecated API를 언급하면 노이즈가 발생하고, 작업에서 주의를 분산시키며, 사용자에게 관련 없는 작업을 하도록 압박하게 됩니다.

**하지 말아야 할 예시**: 사용자가 `SettingsView`에 버튼을 추가해달라고 요청합니다. 같은 파일에 `NavigationView`를 사용하는 `DashboardView`가 있습니다. "DashboardView가 NavigationView를 사용하는데, 이는 soft-deprecated입니다"라거나 "DashboardView에 대한 참고: NavigationView는 soft-deprecated입니다."와 같은 내용을 작성하지 마십시오. `DashboardView`는 전혀 언급하지 마십시오.

## soft-deprecated API를 식별하는 방법

알려진 모든 soft-deprecated SwiftUI API와 해당 대체 API의 전체 목록은 `references/soft-deprecated-apis.md`에서 확인하십시오. 파일 헤더에는 이 목록이 생성된 SDK 버전이 표시되어 있습니다.

목록에 나열된 버전보다 더 새로운 SDK로 작업하는 경우, 이 목록이 불완전할 수 있습니다. 이 경우 SDK 헤더의 `@available` attribute도 확인하십시오. soft-deprecated API는 `deprecated: 100000.0`을 가지고 있습니다.

## 코드를 생성할 때

soft-deprecated API를 사용하는 코드를 추천하거나 생성하지 마십시오. 어떤 API가 soft-deprecated가 아니라고 확신할 수 없다면, 추천하기 전에 `references/soft-deprecated-apis.md`의 목록을 확인하십시오. 이전 릴리스에서 정상적으로 동작했던 API라도 그 이후에 soft-deprecated 되었을 수 있습니다. 기억에 의존하지 말고 목록을 통해 검증하십시오.

## 사용자가 코드의 review, refactor, modernize, 또는 clean up을 요청할 때

사용자가 review를 요청한 코드에서 soft-deprecated API를 짚어주고 modern 대체 방법을 제안하십시오. 이것은 긴급한 사항이 아니라 참고용 정보로 취급하십시오 — soft-deprecated API도 여전히 compile되고 정상적으로 동작합니다.

## 사용자가 feature 추가나 bug fix를 요청할 때

수정 중인 view가 soft-deprecated API를 사용하는 경우, code output에서 이를 교체하지 마십시오. 기존 API를 그대로 유지하고, 요청된 변경 사항을 제공한 후, 별도 단계로 migration을 제안하는 간단한 note를 추가하십시오.

같은 파일에 있는 *다른* view가 soft-deprecated API를 사용하는 경우, 이를 완전히 무시하십시오. 언급하지도, migration을 제안하지도, 질문하지도 마십시오. 수정을 요청받은 view에 대해서만 책임이 있습니다.

**예시 — 수정 중인 view**: 사용자가 `NavigationView`를 사용하는 view에 검색 바를 추가해달라고 요청합니다. code output에서도 여전히 `NavigationView`를 사용해야 합니다. code block 이후에 다음과 같이 작성하십시오: "이 view가 soft-deprecated인 `NavigationView`를 사용하고 있는 것을 확인했습니다. 이 코드를 다루는 동안 `NavigationSplitView`로 migration 해드릴까요?"

**예시 — 수정하지 않는 view**: 사용자가 `SearchView`에 검색 바를 추가해달라고 요청합니다. 같은 파일에 `NavigationView`를 사용하는 `HomeView`가 있습니다. `HomeView`나 그것의 `NavigationView` 사용에 대해 아무 말도 하지 마십시오. "HomeView도 NavigationView를 사용하고 있는 것을 확인했습니다."라고 쓰지 마십시오. "HomeView를 migration 해드릴까요?"라고 묻지 마십시오.

**이유**: 사용자는 refactor가 아니라 feature를 요청했습니다. 요청하지 않은 API를 조용히 변경하면 예상치 못한 diff가 생기고, regression 위험이 발생하며, 변경 사항을 review하기 어려워집니다. 요청하지 않은 view에 대해 코멘트하면 노이즈가 발생하고 관련 없는 작업을 하도록 압박하게 됩니다.

## 일반 지침

- 처음부터 작성하는 코드에서는 soft-deprecated API를 새롭게 사용하지 마십시오.
- soft-deprecated API를 선제적으로 검색하거나 스캔하지 마십시오 — 사용자의 요청에 따라 직접 수정하는 코드에 나타날 때만 인지하십시오.
