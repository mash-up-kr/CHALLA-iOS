import CHALLADesignSystem
import Foundation
import ProfileSetupFeature
import UIKit
import UserDomain

/// 실행 인자(`--screen` / `--state`)를 초기 State + Mock 결과로 조립한다.
/// 시뮬레이터를 탭으로 조작할 수 없으므로, 시안에 정의된 상태를 전부 인자로 띄울 수 있게 한다
/// (`zeplin-ui-verification` 스킬이 이 규약을 쓴다).
struct DemoScenario {

    enum Screen: String {
        case profileSetup
    }

    /// 공용 어휘(default/loading/empty/error)에 이 화면 고유 상태를 더한다.
    enum ScreenState: String {
        case `default`
        case empty
        case filled
        case error
        case completed
        case loading
        case welcome
        case submitError
        /// 사진 메뉴 드로어 — 등록된 사진이 없어 삭제 버튼이 없는 상태.
        case photoMenu
        /// 사진 메뉴 드로어 — 등록된 사진이 있어 삭제 버튼까지 나오는 상태.
        case photoMenuWithImage
    }

    let screen: Screen
    let initialState: ProfileSetupFeature.State
    let outcome: CompositionRoot.Outcome

    init(arguments: [String]) {
        screen = Self.argumentValue("--screen", in: arguments)
            .flatMap(Screen.init(rawValue:)) ?? .profileSetup
        let screenState = Self.argumentValue("--state", in: arguments)
            .flatMap(ScreenState.init(rawValue:)) ?? .default

        (initialState, outcome) = Self.makeScenario(for: screenState)
    }

    // MARK: - 상태 조립

    private static let sampleNickname = "나는야멋쟁이토마토"
    /// maxLength(10)를 한 자 넘긴 값 — error 상태 재현용.
    private static let overflowNickname = "나는야멋쟁이토마토임다"

    /// 사용자가 앨범에서 사진을 고른 뒤 상태를 재현하기 위한 대역 이미지.
    ///
    /// **기본 이미지가 아니다** — 사진을 고르지 않았으면 `imageData`는 nil이고,
    /// 아바타는 파일이 아니라 코드로 그린 실루엣(`ProfileAvatarSource.placeholder`)을 보여준다.
    /// 사진이 있어야만 뜨는 상태(드로어의 '프로필 사진 삭제')를 인자로 띄우려고 여기서만 쓴다.
    private static var pickedImageData: Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { context in
            UIColor(CHALLAColor.Primary.yellow).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }.pngData()
    }

    private static func makeScenario(
        for screenState: ScreenState
    ) -> (ProfileSetupFeature.State, CompositionRoot.Outcome) {
        var state = ProfileSetupFeature.State()

        switch screenState {
        case .default:
            break // 이 상태로 띄우면 전체 플로우를 손으로 조작할 수 있다

        case .empty:
            state.isNicknameFocused = true

        case .filled:
            state.nickname = sampleNickname
            state.isNicknameFocused = true

        case .error:
            // 액션을 거치지 않아 소멸 타이머가 돌지 않는다 — 캡처가 안정적이다.
            // 빨간 테두리·CTA 비활성은 초과된 값에서 파생되므로 따로 심지 않는다.
            state.nickname = overflowNickname
            state.toast = .init(
                message: NicknameRule.Violation.tooLong(limit: NicknameRule.maxLength).userMessage
            )
            state.isNicknameFocused = true

        case .completed:
            state.nickname = sampleNickname

        case .loading:
            state.nickname = sampleNickname
            state.phase = .submitting // 이펙트가 없으므로 dots가 계속 유지된다

        case .welcome:
            state.nickname = sampleNickname
            state.phase = .welcome // 타이머 미가동 → delegate가 나가지 않고 화면 유지
            state.savedProfile = UserProfile(id: 1, nickname: sampleNickname)

        case .submitError:
            state.nickname = sampleNickname
            state.toast = .init(message: UserError.network.userMessage)
            return (state, .failure(.network))

        case .photoMenu:
            state.nickname = sampleNickname
            state.isPhotoMenuPresented = true

        case .photoMenuWithImage:
            state.nickname = sampleNickname
            state.imageData = pickedImageData
            state.isPhotoMenuPresented = true
        }

        return (state, .success)
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
    }
}
