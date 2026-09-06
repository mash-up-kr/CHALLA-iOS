import ChatDomain
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
        /// 인화 완료 여부. 아직이면 방 상세처럼 사진을 blur로 가린다(인화 대기 연출).
        public let isPrinted: Bool

        public var photos: IdentifiedArrayOf<Photo> = []

        public var selectedPhotoID: Photo.ID?
        public var isLoading = false
        public var isSaving = false
        /// 이 사진에 보낼 채팅 메시지 입력값.
        public var messageDraft = ""
        /// 메시지를 보내는 중 — 중복 전송을 막는다.
        public var isSendingMessage = false
        /// nil이면 토스트를 숨긴다.
        public var toast: String?
        /// 확인 드로어. nil이면 닫힘.
        public var drawer: Drawer?
        @Presents public var alert: AlertState<Action.Alert>?

        /// 방금 남긴 리액션 — 뷰가 이모지 쏟아지는 애니메이션을 재생한다. id가 바뀔 때마다 새로 튄다.
        public var reactionBurst: ReactionBurst?

        /// 리액션을 이미 받아 온 사진 — 다시 펼쳐도 재요청하지 않는다(캐시).
        public var reactionsLoaded: Set<Photo.ID> = []
        /// 리액션을 받는 중인 사진 — 같은 사진에 중복 요청을 막는다.
        public var reactionsLoading: Set<Photo.ID> = []
        /// 변경 요청과 후속 조회가 끝날 때까지 같은 사진의 추가 변경을 막는다.
        public var reactionsUpdating: Set<Photo.ID> = []
        public var reactionsNeedRefresh: Set<Photo.ID> = []

        /// 진입할 때 펼쳐 보여줄 사진.
        private let initialPhotoID: Photo.ID?

        public var selectedPhoto: Photo? {
            selectedPhotoID.flatMap { photos[id: $0] }
        }

        public init(
            roomID: Int64,
            roomTitle: String,
            currentUserID: String,
            isPrinted: Bool,
            initialPhotoID: Photo.ID? = nil
        ) {
            self.roomID = roomID
            self.roomTitle = roomTitle
            self.currentUserID = currentUserID
            self.isPrinted = isPrinted
            self.initialPhotoID = initialPhotoID
        }

        /// 목록을 교체하고 볼 사진을 정한다. 보던 사진이 없어졌으면 첫 사진으로 바꾼다.
        mutating func apply(photos: [Photo]) {
            self.photos = IdentifiedArray(uniqueElements: photos)
            let preferred = selectedPhotoID ?? initialPhotoID
            selectedPhotoID = preferred.flatMap { self.photos[id: $0]?.id } ?? photos.first?.id
        }
    }

    /// 삭제 확인 드로어.
    public enum Drawer: Equatable, Sendable {
        /// 내 스티커를 지울지 묻는다.
        case deleteReaction(photoID: String, reactionID: String)
    }

    /// 이모지 쏟아지는 애니메이션 한 번. 같은 종류를 연달아 눌러도 새로 튀도록 매번 새 `id`를 받는다.
    public struct ReactionBurst: Equatable, Sendable, Identifiable {
        public let id: UUID
        public let kind: ReactionKind

        public init(id: UUID, kind: ReactionKind) {
            self.id = id
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
            case messageChanged(String)
            case sendMessageTapped
            case stickerTapped(reactionID: String)
            case deleteReactionConfirmed
            case drawerDismissed
        }

        case view(ViewAction)

        /// App에만 알린다. 화면을 닫는 것은 App이 한다 (규칙 3).
        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeRequested
        }

        case delegate(Delegate)

        case photosResponse(Result<[Photo], PhotoError>)

        /// 펼친 사진의 리액션을 지연 조회한 결과. 실패해도 얼럿 없이 둔다(리액션은 비필수) — 다음에 다시 펼치면 재시도.
        case reactionsResponse(photoID: Photo.ID, Result<PhotoReactions, PhotoError>)

        /// 생성 결과의 채팅 ID는 삭제에 사용한다.
        case reactionSucceeded(photoID: String, reactionID: String, chatID: Int64?)
        /// 리액션 전송 실패. 낙관적으로 붙였던 스티커를 뗀다.
        case reactionFailed(photoID: String, reactionID: String, PhotoError)

        /// 삭제 실패 시 복구할 리액션을 함께 전달한다.
        case reactionDeleted(photoID: String, restoring: PhotoReaction, Result<Void, PhotoError>)

        case saveSucceeded
        case saveFailed(PhotoError)

        /// 이 사진에 채팅 메시지를 보낸 결과. 성공하면 입력창을 비운 상태를 확정한다(메시지는 채팅 화면에서 확인).
        case messageSent(Result<Void, ChatError>)

        case toastDismissed

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
    @Dependency(\.fetchPhotoReactionsUseCase) var fetchPhotoReactionsUseCase
    @Dependency(\.setPhotoReactionUseCase) var setPhotoReactionUseCase
    @Dependency(\.deletePhotoReactionUseCase) var deletePhotoReactionUseCase
    @Dependency(\.sendChatUseCase) var sendChatUseCase
    @Dependency(\.savePhotoUseCase) var savePhotoUseCase
    @Dependency(\.openURL) var openURL
    @Dependency(\.uuid) var uuid
    @Dependency(\.continuousClock) var clock

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
                return loadReactions(&state, photoID: id)

            case let .view(.adjacentPhotoRequested(offset)):
                guard
                    let currentID = state.selectedPhotoID,
                    let currentIndex = state.photos.index(id: currentID)
                else { return .none }
                let targetIndex = currentIndex + offset
                guard state.photos.indices.contains(targetIndex) else { return .none }
                let targetID = state.photos[targetIndex].id
                state.selectedPhotoID = targetID
                return loadReactions(&state, photoID: targetID)

            case let .view(.messageChanged(text)):
                state.messageDraft = text
                return .none

            case .view(.sendMessageTapped):
                return sendMessage(&state)

            case let .view(.stickerTapped(reactionID)):
                return stickerTapped(&state, reactionID: reactionID)

            case .view(.deleteReactionConfirmed):
                guard case let .deleteReaction(photoID, reactionID) = state.drawer else { return .none }
                state.drawer = nil
                return deleteReaction(&state, photoID: photoID, reactionID: reactionID)

            case .view(.drawerDismissed):
                state.drawer = nil
                return .none

            case let .photosResponse(.success(photos)):
                state.isLoading = false
                state.apply(photos: photos)
                // 목록엔 리액션이 없다 — 펼쳐진 사진 한 장만 리액션을 지연 조회한다.
                return loadReactions(&state, photoID: state.selectedPhotoID)

            case let .photosResponse(.failure(error)):
                state.isLoading = false
                state.alert = Self.errorAlert(title: "사진을 불러오지 못했어요", error: error, canRetry: true)
                return .none

            case let .reactionsResponse(photoID, .success(reactions)):
                // 조회 사이 사용자가 이 사진에 리액션했으면(로딩이 이미 풀림) 낙관 상태를 서버 값으로 덮지 않는다.
                guard state.reactionsLoading.contains(photoID) else { return .none }
                state.reactionsLoading.remove(photoID)
                state.reactionsLoaded.insert(photoID)
                state.reactionsUpdating.remove(photoID)
                state.reactionsNeedRefresh.remove(photoID)
                if let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.applyingReactions(reactions)
                }
                return .none

            case let .reactionsResponse(photoID, .failure):
                // 리액션은 비필수라 실패해도 얼럿 없이 둔다. 로드 표시만 풀어 다음에 다시 펼치면 재시도한다.
                state.reactionsLoading.remove(photoID)
                let wasUpdating = state.reactionsUpdating.remove(photoID) != nil

                // 변경 뒤 확인 조회가 실패하면 reactionsNeedRefresh가 남아, 다음 탭도 이 조회로 흘러간다.
                // 알리지 않으면 이모지를 눌러도 아무 일도 없는 것처럼 보인다.
                if wasUpdating || state.reactionsNeedRefresh.contains(photoID) {
                    return showToast(&state, Const.retryLaterToast)
                }
                return .none

            case let .reactionSucceeded(photoID, reactionID, chatID):
                if let chatID, let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.attachingChatID(chatID, to: reactionID)
                }
                if chatID == nil || state.reactionsNeedRefresh.contains(photoID) {
                    return refreshReactions(&state, photoID: photoID)
                }
                state.reactionsUpdating.remove(photoID)
                return .none

            case let .reactionDeleted(photoID, _, .success):
                return refreshReactions(&state, photoID: photoID)

            case let .reactionDeleted(photoID, restoring, .failure(error)):
                state.reactionsUpdating.remove(photoID)
                if let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.addingReaction(restoring)
                }
                state.alert = Self.errorAlert(title: "이모지를 삭제하지 못했어요", error: error, canRetry: false)
                return .none

            case let .reactionFailed(photoID, reactionID, error):
                state.reactionsUpdating.remove(photoID)
                // 낙관적으로 붙인 스티커를 뗀다.
                if let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.removingReaction(id: reactionID)
                }
                state.alert = Self.errorAlert(title: "리액션을 남기지 못했어요", error: error, canRetry: false)
                if state.reactionsNeedRefresh.contains(photoID) {
                    return refreshReactions(&state, photoID: photoID)
                }
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

            case .messageSent(.success):
                state.isSendingMessage = false
                return showToast(&state, Const.messageSentToast)

            case .toastDismissed:
                state.toast = nil
                return .none

            case let .messageSent(.failure(error)):
                state.isSendingMessage = false
                state.alert = AlertState {
                    TextState("메시지를 보내지 못했어요")
                } actions: {
                    ButtonState(role: .cancel) { TextState("확인") }
                } message: {
                    TextState(error.userMessage)
                }
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
}

// MARK: - Effects

extension PhotoDetailFeature {

    /// 확장 파일(`PhotoDetailReactions`)도 쓰므로 private으로 좁히지 않는다.
    enum CancelID: Hashable { case toast, reactions(Photo.ID) }

    enum Const {
        /// 노출 시간은 방 상세 토스트와 같은 값을 쓴다.
        static let toastDuration: Duration = .seconds(2)
        static let messageSentToast = "메시지를 보냈어요"
        static let othersReactionToast = "내가 남긴 이모지만 지울 수 있어요"
        static let retryLaterToast = "잠시 후 다시 시도해 주세요"
    }

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

    /// 펼친 사진에 채팅 메시지를 보낸다. 빈 입력·전송 중 재탭은 무시하고, 낙관적으로 입력창을 비운다.
    /// 메시지 목록은 채팅 화면에서 보므로 여기선 표시하지 않는다.
    private func sendMessage(_ state: inout State) -> Effect<Action> {
        let content = state.messageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !state.isSendingMessage, let photo = state.selectedPhoto else { return .none }
        guard let photoID = Int64(photo.id) else { return .none }

        state.isSendingMessage = true
        state.messageDraft = ""
        let roomID = state.roomID

        return .run { [sendChatUseCase] send in
            do {
                try await sendChatUseCase.run(roomID, photoID, content)
                await send(.messageSent(.success(())))
            } catch is CancellationError {
                return
            } catch {
                await send(.messageSent(.failure((error as? ChatError) ?? .unknown)))
            }
        }
    }

    /// 새 토스트가 표시되면 이전 타이머를 취소한다.
    func showToast(_ state: inout State, _ message: String) -> Effect<Action> {
        state.toast = message

        return .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }

    /// 화면을 벗어나 취소된 경우 nil을 반환한다(알릴 대상이 없다). 나머지는 PhotoError로 바꾼다.
    /// 확장 파일(`PhotoDetailReactions`)도 쓰므로 private으로 좁히지 않는다.
    static func failure(_ error: any Error) -> PhotoError? {
        if error is CancellationError {
            return nil
        }
        return error as? PhotoError ?? .unknown
    }

    // MARK: - 얼럿

    static func errorAlert(
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
