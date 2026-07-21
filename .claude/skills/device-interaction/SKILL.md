---
name: device-interaction
description: "device 또는 simulator에서 스크린샷, UI hierarchy, 터치 interaction을 통해 iOS 앱 동작을 확인합니다."
---
# Device Interaction

TRIGGER when: 사용자가 앱이 device에서 동작하는지 verify/test/check 해달라고 요청할 때, device 검증이 필요한 UI에 영향을 주는 feature를 구현한 후, 사용자가 "동작하나요", "이거 테스트해줘", "device에서 확인해줘"라고 말할 때, 사용자가 UI가 예상대로 동작하지 않는다고 보고할 때, 터치/interaction 문제를 디버그해야 할 때.
DO NOT TRIGGER when: 사용자가 unit test에 대해서만 질문할 때, device testing 없이 build만 요청할 때, device testing 없이 code review만 할 때, simulator 설정에 대한 질문일 때, UI에 영향을 주지 않는 변경(예: comment, refactor, UI가 아닌 로직)일 때.

---

# Main Agent를 위한 안내

**이 skill은 SUBAGENT skill입니다.** device 검증이 필요할 때 Agent tool을 통해 호출하세요.

```
Agent tool:
- subagent_type: "general-purpose"
- description: "Verify login feature works"
- prompt: "Using the device-interaction skill, verify that the login feature works correctly on session <device-interaction-session>. Launch the app, capture screenshot and UI hierarchy, check that the login button is visible and tappable, and report if the implementation is working correctly."
```

**UI에 영향을 주는 feature를 구현한 후에는, 이 skill을 호출해 구현이 device에서 잘 동작하는지 확인하세요.**

## Session Lifecycle

```
DeviceInteractionStartSession (do this early, runs in the background)
  → DeviceInteractionInstallAndRun (after each code change; includes building)
    → DeviceEventSynthesize (interact + observe, repeatable)
  → DeviceInteractionEndSession (when done — keeping sessions open is resource-heavy)
```

## DeviceInteractionStartSession tool

### Device 탐색

새로운 device interaction session을 열 때, device를 선택하려면 device identifier를 전달하거나, 현재 destination을 사용하려면 생략하세요. 일치하지 않는 값을 전달하면 사용 가능한 target 목록을 얻을 수 있습니다.

## DeviceInteractionInstallAndRun tool

### 선택적 Parameters

- `commandLineArguments` — 앱 실행 시 전달되는 argument입니다. scheme의 기존 argument를 유지하려면 `$(inherited)`를 token으로 사용하세요 (예: 끝에 추가 argument를 더하려면 `["$(inherited)", "--reset-state"]`).
- `environmentVariables` — 앱의 environment에 실행 시 설정되는 key/value pair입니다. scheme의 기존 environment variable을 유지하려면 `"$(inherited)"`를 key로 사용하세요 (예: `{"$(inherited)": "", "DEBUG_MODE": "1"}`).

두 parameter를 모두 생략하면 scheme의 argument와 environment가 변경되지 않습니다.

**scheme을 직접 편집하기보다 이 parameter들을 사용하세요.** 이는 해당 run에만 적용되며 사용자의 configuration에 지속적인 영향을 주지 않습니다.

---

# Subagent를 위한 안내

**ALWAYS** code로 인해 발생했을 수 있는 UI 문제를 보고하세요: 텍스트가 겹치거나 읽을 수 없는 경우, 이미지/텍스트가 예기치 않게 잘린 경우, 잘못된 색상 등.

## DeviceEventSynthesize tool

이 tool을 사용하면 device의 interaction을 수행하고 state를 관찰할 수 있습니다.

## Hierarchy 파일 읽기

hierarchy 파일에는 각 element별로 계산된 center 위치가 포함되어 있습니다:

```
UIView {{100, 200}, {50, 30}}, center: {125.0, 215.0}
  UIButton "Login" {{110, 205}, {30, 20}}, center: {125.0, 215.0}
```

- `{100, 200}` - origin 위치
- `{50, 30}` - width와 height
- `center: {125.0, 215.0}` - 계산된 center 지점 (탭하기에 가장 적합)

**터치 event에는 항상 center 좌표를 사용하세요.**

## Interaction Command 문법

`interactionCommand` parameter는 command 문법을 받습니다:

| Command | 설명 |
|---|---|
| `t <x> <y> [duration]` | 좌표에서 탭 (선택적으로 hold duration 지정 가능) |
| `d <x> <y>` | 더블 탭 |
| `t <x1> <y1> f <x2> <y2> [duration]` | (x1,y1)에서 (x2,y2)로 스와이프 |
| `b h/p/u/d [duration]` | 하드웨어 button: h=Home, p=Power, u=VolUp, d=VolDown |
| `sender keyboard kbd <text>` | 텍스트 입력; **chain의 마지막 command여야 함** — `kbd ` 뒤의 모든 내용은 그대로 사용됩니다 (여러 개의 공백도 유지됨). 특수 문자에는 `\u{XXXX}` Unicode escape를 사용하세요: `\u{000A}` (return/newline), `\u{0009}` (tab) |
| `w duration` | 아무 작업 없이 duration만큼 대기 |
| `orientation faceDown/faceUp/landscapeLeft/landscapeRight/portrait/portraitUpsideDown` | device orientation 설정 |

**예시:**
- `"t 100 200"` - (100, 200)에서 탭
- `"d 200 300"` - (200, 300)에서 더블 탭
- `"t 200 600 f 200 200 0.3"` - 위로 스와이프 (아래 content로 스크롤)
- `"t 200 200 f 200 600 0.3"` - 아래로 스와이프 (위 content로 스크롤)
- `"b h"` - home button 누르기
- `"b h b h"` - home button을 두 번 눌러 app switcher로 이동
- `"b h w 0 b h"` - device wake 및 unlock (passcode가 없는 device만 가능)
- `"sender keyboard kbd hello world"` - 공백이 포함된 텍스트 입력
- `"sender keyboard kbd hello   world"` - 여러 개의 공백을 유지하며 텍스트 입력
- `"sender keyboard kbd submit\u{000A}"` - 텍스트 입력 후 Return/submit 누르기
- `"w 0.3"` - 0.3초 대기
- `"orientation landscapeLeft"` - device를 landscape로 회전

## 표준 Subagent 워크플로우

interaction을 수행하기 전에는 항상 hierarchy를 캡처하고 읽으세요 (스크린샷도 함께). interaction 후에는 다시 캡처해서 결과를 확인하세요. toggle나 switch와 같은 복잡한 컴포넌트의 경우, `Switch`나 `Slider`와 같은 nested element를 살펴보세요 — 근처의 element가 실제 control에 해당할 수 있습니다. 완료되면 main agent에게 findings를 보고하세요.

- interaction 없이 캡처만 하려면, 빈 interactionCommand로 DeviceEventSynthesize를 사용하세요.
- 스크린샷만으로 위치를 추측하지 마세요 — 항상 hierarchy의 center 좌표를 사용하세요.
- 확신이 없거나 썸네일 해상도가 충분하지 않다면, 원본 크기 스크린샷을 분석하세요.

## 타이밍과 재시도

- **앱 실행**: session을 시작한 후, 앱이 로드되는 데 몇 초 걸릴 수 있습니다. interact하기 전에 hierarchy를 캡처해서 의미 있는 UI element가 있는지 확인하세요. hierarchy가 대부분 비어 있거나 launch screen을 보여준다면, 진행하기 전에 다시 캡처하세요.
- **interaction 후**: 탭이나 스와이프가 예상한 변화를 만들어내지 않으면, hierarchy를 다시 캡처하고 interaction을 한 번 재시도하세요 (element가 애니메이션 중에 이동했을 수 있습니다). 한 번 재시도한 후에도 여전히 실패한다면, 무한정 재시도하지 말고 실패를 보고하세요.
- **로딩 state**: hierarchy에 스피너나 로딩 indicator가 표시된다면, 잠시 기다린 후 다시 캡처하세요. 아직 로딩 중인 element와는 interact하지 마세요.

## 성공 vs 실패 판단

검증할 때는 다음 카테고리를 구분하세요:

- **기능적 버그** (항상 보고): element가 탭에 반응하지 않음, navigation이 잘못된 화면으로 이동, 크래시, data가 표시되지 않음, 예상된 UI element 누락.
- **시각/레이아웃 버그** (항상 보고): 텍스트 겹침, label 잘림, element가 화면 밖에 렌더링됨, 잘못된 색상, alignment 깨짐.
- **일시적 state** (버그로 보고하지 말 것): 로딩 스피너, 짧은 애니메이션, 키보드가 나타나거나 사라지는 것. transition이 끝난 후 다시 캡처하세요.
- **예상치 못한 종료** (항상 보고): 크래시, 앱 종료. 식별하려면 process id를 추적하고 process의 standard output을 캡처하세요.
- **예상된 동작** (버그로 보고하지 말 것): placeholder 텍스트가 있는 빈 state, form이 미완성일 때 비활성화된 button, permission dialog.

## Error 처리

- 앱이 보이지 않는다면, 느린 device 때문일 수 있으니 한 번 재시도하세요.
- 탭 target이 불명확하다면, 정확한 center 좌표를 위해 hierarchy data를 다시 읽으세요.
- 문제를 해결하려면 runtime 로그를 확인할 수 있습니다. 타이밍 버그가 의심된다면, 관련 code에 임시로 `print` statement를 추가하면 문제를 진단하는 데 도움이 될 수 있다고 main agent에게 제안하세요.
- 세부 사항과 제안과 함께 main agent에게 문제를 다시 보고하세요.
