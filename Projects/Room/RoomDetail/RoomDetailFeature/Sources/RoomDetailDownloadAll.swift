import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain

// MARK: - 전체 다운로드

public extension RoomDetailFeature {

    enum Drawer: Equatable, Sendable {
        case leaveWhileDownloading
    }

    /// 토스트 문구와 표시 위치.
    struct Toast: Equatable, Sendable {

        public enum Placement: Equatable, Sendable {
            /// 참여자 바 아래의 초대 코드 복사 안내.
            case top
            /// 하단 버튼 위의 다운로드 결과 안내.
            case bottom
        }

        public let message: String
        public let placement: Placement

        public init(_ message: String, placement: Placement) {
            self.message = message
            self.placement = placement
        }
    }

    /// 재다운로드를 허용하기 위해 완료 후 `idle`로 돌아간다.
    enum DownloadAllState: Equatable, Sendable {
        case idle
        case running(completed: Int, total: Int)

        var isRunning: Bool {
            if case .running = self {
                return true
            }
            return false
        }
    }
}

extension RoomDetailFeature {

    func startDownloadAll(_ state: inout State) -> Effect<Action> {
        guard !state.downloadAll.isRunning, !state.photos.isEmpty else { return .none }

        let photos = state.photos
        state.downloadAll = .running(completed: 0, total: photos.count)

        return .run { [saveAllPhotosUseCase] send in
            for await event in saveAllPhotosUseCase.run(photos) {
                await send(.saveAllEvent(event))
            }
        }
        .cancellable(id: CancelID.downloadAll, cancelInFlight: true)
    }

    static func photoLibraryAlert(error: PhotoError) -> AlertState<Action.Alert> {
        AlertState {
            TextState("사진을 저장하지 못했어요")
        } actions: {
            ButtonState(action: .openSettingsTapped) { TextState("설정으로 이동") }
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            TextState(error.userMessage)
        }
    }

    /// 사진 목록은 PhotoDomain 소관이라 방 조회와 별개로 실패할 수 있다 — 에러도 PhotoError로 온다.
    func fetchPhotos(id: Room.ID) -> Effect<Action> {
        .run { [fetchRoomPhotosUseCase] send in
            do {
                // 그리드는 리액션을 그리지 않으므로 목록만 받는다 (리액션은 사진 상세에서 지연 조회).
                let photos = try await fetchRoomPhotosUseCase.run(id)
                await send(.photosResponse(.success(photos)))
            } catch let error as PhotoError {
                await send(.photosResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.photosResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.photos, cancelInFlight: true)
    }
}
