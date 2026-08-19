import ComposableArchitecture
import Foundation
import PhotoDomain
import UIKit

/// 사진 상세 화면
@Reducer
public struct PhotoDetailFeature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {

        public let roomID: Int64
        /// 탑 내비게이션 타이틀.
        public let roomTitle: String
        /// 리액션을 남기는 주체.
        public let currentUserID: String

        public var photos: IdentifiedArrayOf<Photo> = [] {
            // 리액션이 바뀌면 스티커 자리를 다시 배정한다(남은 자리는 유지).
            didSet { stickerSlots = StickerLayout.assignSlots(for: photos, previous: stickerSlots) }
        }

        public var selectedPhotoID: Photo.ID?
        public var isLoading = false
        public var isSaving = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// 응답 대기 중인 리액션. 같은 리액션을 다시 눌러도 요청이 중복되지 않게 막는다.
        public var inFlightReactions: Set<ReactionRequest> = []

        /// 리액션별 스티커 자리. 떼도 남은 자리가 안 바뀌게 저장해 둔다.
        public var stickerSlots: [String: Int] = [:]

        /// 진입할 때 펼쳐 보여줄 사진.
        private let initialPhotoID: Photo.ID?

        public var selectedPhoto: Photo? {
            selectedPhotoID.flatMap { photos[id: $0] }
        }

        public init(
            roomID: Int64,
            roomTitle: String,
            currentUserID: String,
            initialPhotoID: Photo.ID? = nil
        ) {
            self.roomID = roomID
            self.roomTitle = roomTitle
            self.currentUserID = currentUserID
            self.initialPhotoID = initialPhotoID
        }

        /// 목록을 교체하고 볼 사진을 정한다. 보던 사진이 없어졌으면 첫 사진으로 바꾼다.
        mutating func apply(photos: [Photo]) {
            self.photos = IdentifiedArray(uniqueElements: photos)
            let preferred = selectedPhotoID ?? initialPhotoID
            selectedPhotoID = preferred.flatMap { self.photos[id: $0]?.id } ?? photos.first?.id
        }
    }

    /// 리액션 요청을 구분하는 값. 사진과 종류가 다르면 별개 요청으로 다룬다.
    public struct ReactionRequest: Hashable, Sendable {
        public let photoID: String
        public let kind: ReactionKind

        public init(photoID: String, kind: ReactionKind) {
            self.photoID = photoID
            self.kind = kind
        }
    }

    // MARK: - Action

    public enum Action: ViewAction, Sendable {

        /// UI에서만 트리거되는 액션 (`@ViewAction` 뷰가 `send(...)`로 호출).
        public enum ViewAction: Sendable {
            case onAppear
            case backButtonTapped
            case downloadButtonTapped
            case reactionTapped(ReactionKind)
            case photoSelected(Photo.ID?)
            /// VoiceOver에서 좌우 스와이프 대신 쓰는 사진 이동.
            case adjacentPhotoRequested(offset: Int)
        }

        case view(ViewAction)

        /// App에만 알린다. 화면을 닫는 것은 App이 한다 (규칙 3).
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeRequested
        }

        case delegate(Delegate)

        case photosResponse(Result<[Photo], PhotoError>)

        case reactionSucceeded(ReactionRequest, Photo)
        /// 화면에 먼저 그렸던 `appliedIsOn`을 반대로 되돌린다.
        case reactionFailed(ReactionRequest, PhotoError, appliedIsOn: Bool)

        case saveSucceeded
        case saveFailed(PhotoError)

        public enum Alert: Equatable, Sendable {
            case retryButtonTapped
            case openSettingsButtonTapped
        }

        case alert(PresentationAction<Alert>)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Dependencies

    @Dependency(\.fetchRoomPhotosUseCase) var fetchRoomPhotosUseCase
    @Dependency(\.setPhotoReactionUseCase) var setPhotoReactionUseCase
    @Dependency(\.savePhotoUseCase) var savePhotoUseCase
    @Dependency(\.openURL) var openURL

    // MARK: - Reducer

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.onAppear):
                return loadPhotos(&state)

            case .view(.backButtonTapped):
                return .send(.delegate(.closeRequested))

            case .view(.downloadButtonTapped):
                return savePhoto(&state)

            case let .view(.reactionTapped(kind)):
                return setReaction(&state, kind: kind)

            case let .view(.photoSelected(id)):
                guard let id, state.photos[id: id] != nil else { return .none }
                state.selectedPhotoID = id
                return .none

            case let .view(.adjacentPhotoRequested(offset)):
                guard
                    let currentID = state.selectedPhotoID,
                    let currentIndex = state.photos.index(id: currentID)
                else { return .none }
                let targetIndex = currentIndex + offset
                guard state.photos.indices.contains(targetIndex) else { return .none }
                state.selectedPhotoID = state.photos[targetIndex].id
                return .none

            case let .photosResponse(.success(photos)):
                state.isLoading = false
                state.apply(photos: photos)
                return .none

            case let .photosResponse(.failure(error)):
                state.isLoading = false
                state.alert = Self.errorAlert(title: "사진을 불러오지 못했어요", error: error, canRetry: true)
                return .none

            case let .reactionSucceeded(request, serverPhoto):
                state.inFlightReactions.remove(request)
                guard let current = state.photos[id: serverPhoto.id] else { return .none }
                var merged = serverPhoto
                for pending in state.inFlightReactions where pending.photoID == serverPhoto.id {
                    let isOn = current.hasReaction(pending.kind, by: state.currentUserID)
                    merged = merged.settingReaction(pending.kind, by: state.currentUserID, isOn: isOn)
                }
                state.photos[id: serverPhoto.id] = merged
                return .none

            case let .reactionFailed(request, error, appliedIsOn):
                state.inFlightReactions.remove(request)
                if let photo = state.photos[id: request.photoID] {
                    state.photos[id: request.photoID] = photo.settingReaction(
                        request.kind,
                        by: state.currentUserID,
                        isOn: !appliedIsOn
                    )
                }
                state.alert = Self.errorAlert(title: "리액션을 남기지 못했어요", error: error, canRetry: false)
                return .none

            case .saveSucceeded:
                state.isSaving = false
                // TODO: 시안에 저장 완료 표현이 없어 임의로 얼럿을 쓴다 — 토스트 시안이 나오면 교체한다.
                state.alert = AlertState {
                    TextState("사진을 저장했어요")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                }
                return .none

            case let .saveFailed(error):
                state.isSaving = false
                state.alert = Self.errorAlert(title: "사진을 저장하지 못했어요", error: error, canRetry: false)
                return .none

            case .alert(.presented(.retryButtonTapped)):
                return loadPhotos(&state)

            case .alert(.presented(.openSettingsButtonTapped)):
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return .none }
                return .run { [openURL] _ in
                    await openURL(settingsURL)
                }

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // MARK: - Effects

    private func loadPhotos(_ state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        let roomID = state.roomID

        return .run { [fetchRoomPhotosUseCase] send in // 비-Sendable self 대신 의존성 값만 캡처
            do {
                let photos = try await fetchRoomPhotosUseCase.run(roomID)
                await send(.photosResponse(.success(photos)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.photosResponse(.failure(failure)))
            }
        }
    }

    /// 서버 응답을 기다리지 않고 화면을 먼저 바꾼다. 실패하면 그 값만 되돌린다.
    ///
    /// 진행 중인 요청은 취소하지 않고 무시한다. 취소하면 TCA가 그 응답을 버려서 되돌릴 수 없고,
    /// 서버에 없는 리액션이 화면에 남기 때문이다.
    private func setReaction(_ state: inout State, kind: ReactionKind) -> Effect<Action> {
        guard let photo = state.selectedPhoto else { return .none }

        let request = ReactionRequest(photoID: photo.id, kind: kind)
        guard !state.inFlightReactions.contains(request) else { return .none }

        let isOn = !photo.hasReaction(kind, by: state.currentUserID)
        state.inFlightReactions.insert(request)
        state.photos[id: photo.id] = photo.settingReaction(kind, by: state.currentUserID, isOn: isOn)

        return .run { [setPhotoReactionUseCase] send in
            do {
                let updated = try await setPhotoReactionUseCase.run(request.photoID, request.kind, isOn)
                await send(.reactionSucceeded(request, updated))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.reactionFailed(request, failure, appliedIsOn: isOn))
            }
        }
    }

    private func savePhoto(_ state: inout State) -> Effect<Action> {
        guard !state.isSaving, let photo = state.selectedPhoto else { return .none }
        state.isSaving = true

        return .run { [savePhotoUseCase] send in
            do {
                try await savePhotoUseCase.run(photo)
                await send(.saveSucceeded)
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.saveFailed(failure))
            }
        }
    }

    /// 화면을 벗어나 취소된 경우 nil을 반환한다(알릴 대상이 없다). 나머지는 PhotoError로 바꾼다.
    private static func failure(_ error: any Error) -> PhotoError? {
        if error is CancellationError {
            return nil
        }
        return error as? PhotoError ?? .unknown
    }

    // MARK: - 얼럿

    private static func errorAlert(
        title: String,
        error: PhotoError,
        canRetry: Bool
    ) -> AlertState<Action.Alert> {
        AlertState {
            TextState(title)
        } actions: {
            if canRetry {
                ButtonState(action: .retryButtonTapped) { TextState("다시 시도") }
            }
            if error == .permissionDenied {
                ButtonState(action: .openSettingsButtonTapped) { TextState("설정으로 이동") }
            }
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }
}
