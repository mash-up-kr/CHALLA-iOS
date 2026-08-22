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

        public var photos: IdentifiedArrayOf<Photo> = [] {
            // 리액션이 바뀌면 스티커 자리를 다시 배정한다(남은 자리는 유지).
            didSet { stickerSlots = StickerLayout.assignSlots(for: photos, previous: stickerSlots) }
        }

        public var selectedPhotoID: Photo.ID?
        public var isLoading = false
        public var isSaving = false
        @Presents public var alert: AlertState<Action.Alert>?

        /// 방금 남긴 리액션 — 뷰가 이모지 쏟아지는 애니메이션을 재생한다. id가 바뀔 때마다 새로 튄다.
        public var reactionBurst: ReactionBurst?

        /// 유저별 스티커 자리. 떼도 남은 자리가 안 바뀌게 저장해 둔다.
        public var stickerSlots: [String: Int] = [:]

        /// 리액션을 이미 받아 온 사진 — 다시 펼쳐도 재요청하지 않는다(캐시).
        public var reactionsLoaded: Set<Photo.ID> = []
        /// 리액션을 받는 중인 사진 — 같은 사진에 중복 요청을 막는다.
        public var reactionsLoading: Set<Photo.ID> = []

        /// 진입할 때 펼쳐 보여줄 사진.
        private let initialPhotoID: Photo.ID?

        public var selectedPhoto: Photo? {
            selectedPhotoID.flatMap { photos[id: $0] }
        }

        public init(
            roomID: Int64,
            roomTitle: String,
            currentUserID: String,
            isPrinted: Bool = true,
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

        /// 서버가 리액션을 받아들였다. 화면은 이미 낙관적으로 그려 둔 상태라 할 일이 없다.
        case reactionSucceeded
        /// 리액션 전송 실패. 낙관적으로 붙였던 그 종류를 되돌린다(스티커였으면 스티커도 함께).
        case reactionFailed(photoID: String, userID: String, kind: ReactionKind, PhotoError)

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
    @Dependency(\.fetchPhotoReactionsUseCase) var fetchPhotoReactionsUseCase
    @Dependency(\.setPhotoReactionUseCase) var setPhotoReactionUseCase
    @Dependency(\.savePhotoUseCase) var savePhotoUseCase
    @Dependency(\.openURL) var openURL
    @Dependency(\.uuid) var uuid

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
                if let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.applyingReactions(reactions)
                }
                return .none

            case let .reactionsResponse(photoID, .failure):
                // 리액션은 비필수라 실패해도 얼럿 없이 둔다. 로드 표시만 풀어 다음에 다시 펼치면 재시도한다.
                state.reactionsLoading.remove(photoID)
                return .none

            case .reactionSucceeded:
                // 서버가 갱신 사진을 주지 않으므로 재조회 없이 낙관적 상태를 그대로 확정한다.
                return .none

            case let .reactionFailed(photoID, userID, kind, error):
                // 낙관적으로 붙인 그 종류를 되돌린다(그게 스티커였으면 스티커도 함께 빠진다).
                if let photo = state.photos[id: photoID] {
                    state.photos[id: photoID] = photo.removingReaction(kind, by: userID)
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

    /// 펼친 사진 한 장의 리액션을 지연 조회한다. 목록엔 리액션이 없어 사진을 펼칠 때만 그 한 장을 받는다 —
    /// 이미 받았거나(`reactionsLoaded`) 받는 중(`reactionsLoading`)이면 건너뛴다(안 본 사진은 요청하지 않음).
    private func loadReactions(_ state: inout State, photoID: Photo.ID?) -> Effect<Action> {
        guard
            let photoID,
            state.photos[id: photoID] != nil,
            !state.reactionsLoaded.contains(photoID),
            !state.reactionsLoading.contains(photoID)
        else { return .none }

        state.reactionsLoading.insert(photoID)

        return .run { [fetchPhotoReactionsUseCase] send in
            do {
                let reactions = try await fetchPhotoReactionsUseCase.run(photoID)
                await send(.reactionsResponse(photoID: photoID, .success(reactions)))
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.reactionsResponse(photoID: photoID, .failure(failure)))
            }
        }
    }

    /// 이모지는 인당 무제한으로 남긴다(정책 #71). 매번 이모지 쏟아지는 애니메이션을 튀우고,
    /// 그 유저의 **첫 이모지일 때만** 스티커를 낙관적으로 붙인다(나머지는 채팅 히스토리로만 쌓인다).
    /// 서버가 갱신 사진을 주지 않으므로 재조회하지 않고, 실패하면 방금 붙인 스티커만 되돌린다.
    private func setReaction(_ state: inout State, kind: ReactionKind) -> Effect<Action> {
        guard let photo = state.selectedPhoto else { return .none }

        let userID = state.currentUserID
        let roomID = state.roomID
        let photoID = photo.id

        // 이미 이 종류로 리액션했으면 재탭은 아무 것도 하지 않는다 (애니메이션·전송·띠 변화 없음).
        // TODO: 리액션 해제 API가 생기면, 이 경우 삭제(토글 off)로 연결한다.
        guard !photo.hasReacted(kind, by: userID) else { return .none }

        // 낙관 반영: 종류는 칩 띠에 쌓이고, 그 유저의 첫 이모지면 사진 위 스티커로도 붙는다.
        state.photos[id: photoID] = photo.addingReaction(kind, by: userID)
        state.reactionBurst = ReactionBurst(id: uuid(), kind: kind)
        // 이 사진은 이제 낙관 상태가 정답이다 — 진행 중이던 지연 조회 결과가 덮어쓰지 못하게 로딩을 풀고 로드 완료로 표시한다.
        state.reactionsLoading.remove(photoID)
        state.reactionsLoaded.insert(photoID)

        return .run { [setPhotoReactionUseCase] send in
            do {
                try await setPhotoReactionUseCase.run(roomID, photoID, kind, true)
                await send(.reactionSucceeded)
            } catch {
                guard let failure = Self.failure(error) else { return }
                await send(.reactionFailed(photoID: photoID, userID: userID, kind: kind, failure))
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
