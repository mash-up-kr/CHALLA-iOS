import ComposableArchitecture
import Foundation
import PhotoLibrary
import PhotosUI // PhotosPickerItem — 피커가 고른 항목을 State가 들고 있다가 리듀서가 Data로 읽는다
import RoomDomain
import SwiftUI // PhotosPickerItem은 SwiftUI 오버레이에 있어 PhotosUI만으로는 보이지 않는다

@Reducer
public struct RoomCoverEditFeature {

    @ObservableState
    public struct State: Equatable, Sendable {
        public let roomID: Room.ID
        public let title: String
        public let memberCount: Int
        public var options: RoomCoverOptions = .empty
        public var cover: RoomCover
        public var savedCover: RoomCover
        /// 방금 고른 사진 바이트. 있으면 `cover.imageURL` 대신 이것을 그린다 — 업로드한 사진을 다시 내려받지 않는다.
        public var localImageData: Data?
        /// 칩 선택. 스티커가 있으면 그 색과 같고, 없을 때는 다음 스티커에 칠할 색이다.
        public var selectedColor: RoomCoverColor?
        public var isUploadingPhoto = false
        /// 뒤로가기로 시작한 저장이 진행 중. 화면 입력과 뒤로가기가 막힌다.
        public var isSaving = false
        public var isPhotoPickerPresented = false
        public var photoPickerItem: PhotosPickerItem?
        public var toast: String?
        @Presents public var alert: AlertState<Action.Alert>?

        public var canClear: Bool {
            localImageData != nil || !cover.isEmpty
        }

        public var hasChanges: Bool {
            cover != savedCover
        }

        public init(roomID: Room.ID, title: String, memberCount: Int, cover: RoomCover) {
            self.roomID = roomID
            self.title = title
            self.memberCount = memberCount
            self.cover = cover
            self.savedCover = cover
            self.selectedColor = cover.sticker?.color
        }
    }

    public enum Action: BindableAction, ViewAction, Sendable {
        case view(View)
        case binding(BindingAction<State>)
        case optionsResponse(Result<RoomCoverOptions, RoomError>)
        case photoAuthorizationResponse(PhotoLibraryAuthorization)
        case photoEncoded(Data?)
        case photoUploaded(Result<URL, RoomError>)
        /// 성공값은 저장을 요청한 시점의 `cover` — 응답이 오기 전에 편집값이 바뀌어도 `savedCover`는 서버와 같게 남는다.
        case saveResponse(Result<RoomCover, RoomError>)
        case toastTimerFired
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum View: Sendable {
            case task
            case backButtonTapped
            case cameraButtonTapped
            case clearButtonTapped
            case colorTapped(RoomCoverColor)
            case stickerTapped(RoomCoverStickerOption)
        }

        public enum Alert: Equatable, Sendable {
            case retryTapped
            case discardTapped
        }

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case closeTapped
        }
    }

    public init() {}

    @Dependency(\.fetchRoomCoverOptionsUseCase) var fetchRoomCoverOptionsUseCase
    @Dependency(\.uploadRoomCoverImageUseCase) var uploadRoomCoverImageUseCase
    @Dependency(\.updateRoomCoverUseCase) var updateRoomCoverUseCase
    @Dependency(\.photoLibraryPermission) var photoLibraryPermission
    @Dependency(\.coverImageEncoder) var coverImageEncoder
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case toast, photoLoad, photoUpload }

    private enum Const {
        static let toastDuration: Duration = .seconds(2)
        static let optionsLoadFailedMessage = "커버 옵션을 불러오지 못했어요"
        static let photoPermissionDeniedMessage = "설정에서 사진 접근을 허용해 주세요"
        static let photoLoadFailedMessage = "사진을 불러오지 못했어요"
        static let photoUploadFailedMessage = "사진을 올리지 못했어요"
        static let photoUploadingMessage = "사진을 올리는 중이에요. 잠시만 기다려 주세요"
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.photoPickerItem) { _, item in
                Reduce { _, _ in
                    guard let item else { return .none }
                    return .run { [coverImageEncoder] send in
                        let data = try? await item.loadTransferable(type: Data.self)
                        await send(.photoEncoded(data.flatMap { try? coverImageEncoder.encode($0) }))
                    }
                    .cancellable(id: CancelID.photoLoad, cancelInFlight: true)
                }
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(.task):
                return .run { [fetchRoomCoverOptionsUseCase] send in
                    do {
                        try await send(.optionsResponse(.success(fetchRoomCoverOptionsUseCase.run())))
                    } catch {
                        await send(.optionsResponse(.failure(error as? RoomError ?? .unknown)))
                    }
                }

            case let .optionsResponse(.success(options)):
                state.options = options
                if state.selectedColor == nil {
                    state.selectedColor = state.cover.sticker?.color ?? options.colors.first
                }
                return .none

            case .optionsResponse(.failure):
                state.toast = Const.optionsLoadFailedMessage
                return toastTimer()

            case .view(.backButtonTapped):
                // 업로드 중에 나가면 이펙트가 취소돼 URL이 유실된다 — 끝날 때까지 기다리게 한다.
                guard !state.isUploadingPhoto else {
                    state.toast = Const.photoUploadingMessage
                    return toastTimer()
                }
                guard !state.isSaving else { return .none }
                guard state.hasChanges else { return .send(.delegate(.closeTapped)) }
                return save(&state)

            case .alert(.presented(.retryTapped)):
                return save(&state)

            case .alert(.presented(.discardTapped)):
                state.cover = state.savedCover
                state.localImageData = nil
                return .send(.delegate(.closeTapped))

            case let .saveResponse(.success(cover)):
                state.isSaving = false
                state.savedCover = cover
                return .send(.delegate(.closeTapped))

            case .saveResponse(.failure):
                state.isSaving = false
                // TODO: 얼럿 제목·버튼 문구는 임의 작성본 — 기획 정책 확정 시 교체할 것.
                state.alert = AlertState {
                    TextState("커버를 저장하지 못했어요")
                } actions: {
                    ButtonState(action: .retryTapped) { TextState("다시 시도") }
                    ButtonState(action: .discardTapped) { TextState("저장 안 함") }
                }
                return .none

            case .view(.cameraButtonTapped):
                return .run { [photoLibraryPermission] send in
                    await send(.photoAuthorizationResponse(photoLibraryPermission.request(.readWrite)))
                }

            case let .photoAuthorizationResponse(authorization):
                guard authorization.allowsPicking else {
                    state.toast = Const.photoPermissionDeniedMessage
                    return toastTimer()
                }
                state.isPhotoPickerPresented = true
                return .none

            case let .photoEncoded(data):
                state.photoPickerItem = nil // 같은 사진을 다시 골라도 onChange가 다시 걸리도록
                guard let data else {
                    state.toast = Const.photoLoadFailedMessage
                    return toastTimer()
                }
                state.localImageData = data
                state.isUploadingPhoto = true
                // 업로드는 고른 즉시 한다 — 뒤로가기 저장 한 번에 URL까지 실으려면 그때 이미 URL이 있어야 한다.
                return .run { [uploadRoomCoverImageUseCase] send in
                    do {
                        try await send(.photoUploaded(.success(uploadRoomCoverImageUseCase.run(data))))
                    } catch {
                        await send(.photoUploaded(.failure(error as? RoomError ?? .unknown)))
                    }
                }
                .cancellable(id: CancelID.photoUpload, cancelInFlight: true)

            case let .photoUploaded(.success(url)):
                state.isUploadingPhoto = false
                state.cover.imageURL = url
                return .none

            case .photoUploaded(.failure):
                state.isUploadingPhoto = false
                state.localImageData = nil
                state.toast = Const.photoUploadFailedMessage
                return toastTimer()

            case .view(.clearButtonTapped):
                guard state.canClear else { return .none }
                state.localImageData = nil
                state.isUploadingPhoto = false
                state.cover.imageURL = nil
                state.cover.sticker = nil
                // 올리던 사진은 버린다 — 업로드가 끝나 URL을 실으면 방금 지운 사진이 되살아난다.
                return .cancel(id: CancelID.photoUpload)

            case let .view(.colorTapped(color)):
                state.selectedColor = color
                // 스티커가 없으면 서버에 실을 색이 없다 — 다음 스티커에 칠할 색으로만 남긴다
                guard let sticker = state.cover.sticker, sticker.color.id != color.id else { return .none }
                state.cover.sticker = sticker.recolored(color)
                return .none

            case let .view(.stickerTapped(sticker)):
                if state.cover.sticker?.id == sticker.id {
                    state.cover.sticker = nil
                } else {
                    guard let color = state.selectedColor ?? state.options.colors.first else { return .none }
                    state.cover.sticker = sticker.sticker(color: color)
                }
                return .none

            case .toastTimerFired:
                state.toast = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func save(_ state: inout State) -> Effect<Action> {
        state.isSaving = true
        let roomID = state.roomID
        let cover = state.cover
        let draft = RoomCoverDraft(cover: cover)
        return .run { [updateRoomCoverUseCase] send in
            do {
                try await updateRoomCoverUseCase.run(roomID, draft)
                await send(.saveResponse(.success(cover)))
            } catch {
                await send(.saveResponse(.failure(error as? RoomError ?? .unknown)))
            }
        }
    }

    private func toastTimer() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: Const.toastDuration)
            await send(.toastTimerFired)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }
}
