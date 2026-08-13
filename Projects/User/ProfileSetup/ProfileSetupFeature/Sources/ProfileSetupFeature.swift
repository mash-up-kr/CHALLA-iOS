import ComposableArchitecture
import Foundation
import PhotoLibrary
import PhotosUI // PhotosPickerItem — 피커가 고른 항목을 State가 들고 있다가 리듀서가 Data로 읽는다
import SwiftUI
import UserDomain

/// 프로필 설정 화면의 TCA Feature.
///
/// 닉네임 입력·검증(`UserDomain.NicknameRule` 호출)·프로필 사진 선택·프로필 제출·환영 연출을 담당하고,
/// 완료 후 화면 전환은 `delegate(.setupCompleted)`로 App에 위임한다.
@Reducer
public struct ProfileSetupFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {

        /// 최초 설정인지 편집인지. 문구·뒤로가기·환영 연출이 갈린다.
        public var mode: Mode = .setup

        public var nickname: String = ""
        /// 새로 고른 프로필 이미지. nil이면 아직 안 골랐거나 지운 상태다.
        public var imageData: Data?

        /// 서버에 저장돼 있는 프로필 이미지 URL (편집 모드 진입 시 부모가 시드).
        ///
        /// 표시용이기도 하지만 **저장에 필수다** — 사진을 건드리지 않았을 때 이 URL을
        /// 그대로 되돌려 보내야 서버가 기존 사진을 지우지 않는다 (`ProfileImageChange` 참고).
        public var remoteImageURL: URL?

        /// 사진 삭제를 눌렀는지. `imageData == nil` 하나로는 "안 건드림"과 구분되지 않는다.
        public var isPhotoRemoved = false
        /// 프로필 사진 메뉴 드로어 표시 여부.
        public var isPhotoMenuPresented = false
        /// 시스템 사진 피커 표시 여부 — 권한을 받은 뒤에만 켠다.
        public var isPhotoPickerPresented = false
        /// 피커가 돌려준 선택 항목. 리듀서가 Data로 읽어들인 뒤 nil로 되돌린다.
        public var photoPickerItem: PhotosPickerItem?
        /// 뷰의 @FocusState와 `.bind`로 동기화.
        public var isNicknameFocused = false
        public var phase: Phase = .editing
        public var toast: ToastState?
        /// 제출 성공 결과 (환영 헤드라인·delegate 페이로드).
        public var savedProfile: UserProfile?

        public enum Phase: Equatable, Sendable { case editing, submitting, welcome }

        public enum Mode: Equatable, Sendable { case setup, edit }

        public struct ToastState: Equatable, Sendable {
            public var message: String

            public init(message: String) {
                self.message = message
            }
        }

        public init(
            mode: Mode = .setup,
            nickname: String = "",
            imageData: Data? = nil,
            remoteImageURL: URL? = nil
        ) {
            self.mode = mode
            self.nickname = nickname
            self.imageData = imageData
            self.remoteImageURL = remoteImageURL
        }
    }

    // MARK: - Action

    //
    // State의 파생값은 파일 아래 `extension ProfileSetupFeature.State`에 모아 뒀다.

    public enum Action: BindableAction, ViewAction, Sendable {

        /// nickname · isNicknameFocused 양방향 바인딩 (BindingReducer가 처리).
        case binding(BindingAction<State>)

        public enum ViewAction: Sendable {
            /// 화면 진입 — 바로 닉네임을 입력할 수 있게 포커스를 잡는다.
            case task
            /// 아바타 탭 — 사진 메뉴 드로어를 연다.
            case profileImageButtonTapped
            case photoMenuDismissed
            case albumSelectTapped
            case photoRemoveTapped
            case nicknameSubmitted
            case backgroundTapped
            case startButtonTapped
            /// 편집 모드의 뒤로가기 — 변경을 버리고 돌아간다.
            case backButtonTapped
        }

        case view(ViewAction)

        /// parent(App)와의 유일한 통신 채널.
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            /// 최초 설정 완료 — 환영 화면 종료 = 다음 화면으로 진행해도 좋다는 신호.
            case setupCompleted(UserProfile)
            /// 편집 저장 완료. 환영 연출 없이 곧바로 올린다.
            case editCompleted(UserProfile)
            /// 편집을 버리고 나갔다.
            case cancelled
        }

        case delegate(Delegate)

        case submitResponse(Result<UserProfile, UserError>)
        case photoAuthorizationResponse(PhotoLibraryAuthorization)
        /// 피커가 고른 항목을 읽어들인 결과. nil이면 읽기 실패.
        case photoLoadResponse(Data?)
        case toastDismissed
        case welcomeFinished
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.setupProfileUseCase) var setupProfileUseCase
    @Dependency(\.photoLibraryPermission) var photoLibraryPermission
    @Dependency(\.continuousClock) var clock

    // MARK: - Reducer

    private enum CancelID { case toast, submit, welcome, photoLoad }

    private enum Const {
        // TODO: 노출 시간은 기획 미확정 — 확정 시 교체할 것.
        static let toastDuration: Duration = .seconds(2)
        static let welcomeDuration: Duration = .seconds(2)
        // TODO: 아래 두 문구는 시안에 없어 임의로 적었다 — 기획 확정 시 교체할 것.
        static let photoPermissionDeniedMessage = "설정에서 사진 접근을 허용해 주세요"
        static let photoLoadFailedMessage = "사진을 불러오지 못했어요"
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
            // 값이 실제로 바뀐 바인딩 쓰기에만 반응한다 — TextField가 포커스 시
            // 같은 값을 되쓰는 echo write에 토스트 타이머가 헛돌지 않도록.
            .onChange(of: \.nickname) { _, _ in
                Reduce { state, _ in
                    state.nickname = NicknameRule.sanitize(state.nickname)
                    // 필드 테두리·CTA는 nicknameViolation·isSubmittable이 값에서 파생하므로
                    // 여기서 손댈 게 없다. 이 블록이 다루는 건 안내 토스트뿐이다.
                    guard let violation = state.nicknameViolation else {
                        state.toast = nil // 값이 규칙을 만족하면 안내도 즉시 거둔다
                        return .cancel(id: CancelID.toast)
                    }
                    state.toast = State.ToastState(message: violation.userMessage)
                    return toastTimer()
                }
            }
            // 피커가 항목을 넣어주면(또는 리듀서가 nil로 되돌리면) 여기서 Data 읽기를 건다.
            .onChange(of: \.photoPickerItem) { _, item in
                Reduce { _, _ in
                    guard let item else { return .none }
                    return .run { send in
                        await send(.photoLoadResponse(try? item.loadTransferable(type: Data.self)))
                    }
                    .cancellable(id: CancelID.photoLoad, cancelInFlight: true)
                }
            }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(.task):
                // 드로어·피커가 떠 있으면 입력 차례가 아니다 — 키보드가 그 위로 올라오면 겹친다.
                guard state.isFieldEditable,
                      !state.isPhotoMenuPresented,
                      !state.isPhotoPickerPresented
                else { return .none }
                state.isNicknameFocused = true
                return .none

            case .view(.profileImageButtonTapped):
                // 제출 중·환영 중에는 사진을 바꿀 수 없다 (필드도 같은 기준으로 잠긴다).
                guard state.phase == .editing else { return .none }
                state.isNicknameFocused = false
                state.isPhotoMenuPresented = true
                return .none

            case .view(.photoMenuDismissed):
                state.isPhotoMenuPresented = false
                return .none

            case .view(.albumSelectTapped):
                // 권한 팝업이 드로어 위에 겹치지 않도록 먼저 내린다.
                state.isPhotoMenuPresented = false
                return .run { [photoLibraryPermission] send in
                    await send(.photoAuthorizationResponse(photoLibraryPermission.request()))
                }

            case .view(.photoRemoveTapped):
                state.isPhotoMenuPresented = false
                state.imageData = nil
                // 편집 모드에서는 서버에 있던 사진도 지우겠다는 뜻이다.
                // 이 플래그가 없으면 "안 건드림"으로 읽혀 기존 사진이 남는다.
                state.isPhotoRemoved = true
                return .none

            case let .photoAuthorizationResponse(authorization):
                guard authorization.allowsPicking else {
                    state.toast = State.ToastState(message: Const.photoPermissionDeniedMessage)
                    return toastTimer()
                }
                state.isPhotoPickerPresented = true
                return .none

            case let .photoLoadResponse(data):
                state.photoPickerItem = nil // 같은 사진을 다시 골라도 onChange가 다시 걸리도록
                guard let data else {
                    state.toast = State.ToastState(message: Const.photoLoadFailedMessage)
                    return toastTimer()
                }
                state.imageData = data
                // 새로 골랐으니 직전의 삭제 의사는 무효다.
                state.isPhotoRemoved = false
                return .none

            case .view(.nicknameSubmitted):
                state.isNicknameFocused = false
                return .none

            case .view(.backgroundTapped):
                state.isNicknameFocused = false
                return .none

            case .view(.startButtonTapped):
                guard state.isCTAEnabled else { return .none }
                state.phase = .submitting
                state.isNicknameFocused = false
                state.toast = nil // 가드를 통과했으니 남아 있을 건 제출 실패 토스트뿐
                let draft = ProfileDraft(
                    nickname: NicknameRule.normalized(state.nickname),
                    image: state.imageChange
                )
                return .merge(
                    .cancel(id: CancelID.toast),
                    submit(draft)
                )

            case .view(.backButtonTapped):
                // 제출 중에는 막는다 — 나가면 이펙트가 취소돼 성공도 실패도 오지 않는다.
                guard state.phase == .editing else { return .none }
                return .send(.delegate(.cancelled))

            case let .submitResponse(.success(profile)):
                state.savedProfile = profile
                state.nickname = profile.nickname ?? state.nickname // 서버 정규화 반영
                // 편집은 환영 연출을 거치지 않고 바로 부모에게 넘긴다.
                guard state.mode == .setup else {
                    return .send(.delegate(.editCompleted(profile)))
                }
                state.phase = .welcome
                return .run { [clock] send in
                    try await clock.sleep(for: Const.welcomeDuration)
                    await send(.welcomeFinished)
                }
                .cancellable(id: CancelID.welcome)

            case let .submitResponse(.failure(error)):
                state.phase = .editing
                state.toast = State.ToastState(message: error.userMessage)
                return toastTimer()

            case .toastDismissed:
                // 토스트만 거둔다 — 필드 테두리는 값이 고쳐질 때 풀린다(파생값).
                state.toast = nil
                return .none

            case .welcomeFinished:
                guard let profile = state.savedProfile else { return .none }
                return .send(.delegate(.setupCompleted(profile)))

            case .delegate:
                return .none
            }
        }
    }

    // MARK: - Effects

    private func toastTimer() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }

    /// useCase가 던지는 오류는 라이브 구현이 전부 `UserError`로 정규화하므로,
    /// 그 외 오류는 방어적으로 `.unknown`으로 감싼다.
    private func submit(_ draft: ProfileDraft) -> Effect<Action> {
        .run { [setupProfileUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let profile = try await setupProfileUseCase.run(draft)
                await send(.submitResponse(.success(profile)))
            } catch let error as UserError {
                await send(.submitResponse(.failure(error)))
            } catch is CancellationError {
                // 이펙트 취소(예: 화면 이탈) — 무시
            } catch {
                await send(.submitResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.submit, cancelInFlight: true)
    }
}

// MARK: - State 파생값

/// 저장 프로퍼티에서 계산되는 값들. 본체가 아니라 여기 있는 이유는 `ProfileSetupFeature`의
/// 타입 본문 길이 제한(swiftlint `type_body_length`) 때문이다.
public extension ProfileSetupFeature.State {

    var isSubmittable: Bool {
        NicknameRule.validate(nickname) == nil
    }

    /// != nil → 필드 빨간 테두리. 값에서 파생하므로 입력과 함께 실시간으로 풀린다.
    /// 빈 값(`.empty`)은 오류로 칠하지 않는다 — 아직 안 쓴 것이지 잘못 쓴 것이 아니다.
    var nicknameViolation: NicknameRule.Violation? {
        guard case .tooLong = NicknameRule.validate(nickname) else { return nil }
        return .tooLong(limit: NicknameRule.maxLength)
    }

    /// 환영 화면에서만 감춘다 — 편집·제출 중에는 빈 값이어도 자리를 지키고 비활성으로 보인다.
    var isCTAVisible: Bool {
        phase != .welcome
    }

    var isCTAEnabled: Bool {
        phase == .editing && isSubmittable
    }

    var isCTALoading: Bool {
        phase == .submitting
    }

    var isFieldEditable: Bool {
        phase == .editing
    }

    var showsCameraBadge: Bool {
        phase != .welcome
    }

    /// 등록된 사진이 없으면 드로어에 삭제 버튼을 내지 않는다.
    /// 편집 모드에서는 서버에 있던 사진도 지울 대상이다.
    var canRemovePhoto: Bool {
        imageData != nil || (remoteImageURL != nil && !isPhotoRemoved)
    }

    /// 아바타에 그릴 서버 이미지. 지웠으면 nil이라 실루엣으로 돌아간다.
    var avatarImageURL: URL? {
        isPhotoRemoved ? nil : remoteImageURL
    }

    /// 저장할 때 서버에 전달할 사진 처리 방식. 새 사진 > 삭제 > 원본 유지 순으로 판단한다.
    var imageChange: ProfileImageChange {
        if let imageData {
            return .replaced(imageData)
        }
        if isPhotoRemoved {
            return .removed
        }
        return .unchanged(remoteImageURL)
    }

    /// 편집 모드는 되돌아갈 화면이 있어 상단에 뒤로가기 버튼을 둔다.
    var showsBackButton: Bool {
        mode == .edit && phase == .editing
    }

    /// 환영 연출은 최초 설정에만 있다 — 편집은 저장하고 바로 설정 화면으로 돌아간다.
    var showsWelcome: Bool {
        mode == .setup && phase == .welcome
    }
}
