@testable import RoomDetailFeature
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import Testing

@MainActor
@Suite("RoomDetailFeature — 전체 다운로드")
struct RoomDetailDownloadAllTests {

    private nonisolated static let printedRoom = Room(
        id: Room.previewShooting.id,
        title: Room.previewShooting.title,
        status: .printed,
        totalPhotoCount: 24,
        remainedPhotoCount: 0,
        createdAt: Room.previewShooting.createdAt,
        expiresAt: Room.previewShooting.expiresAt
    )

    private nonisolated static func photo(_ id: String) -> Photo {
        Photo(
            id: id,
            imageURL: URL(string: "https://img.example.com/\(id).jpg") ?? URL(fileURLWithPath: "/"),
            author: PhotoAuthor(id: "u1", nickname: "찰나둥이"),
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private static func makeStore(
        events: @escaping @Sendable ([Photo]) -> AsyncStream<SaveAllPhotosEvent>
    ) -> TestStoreOf<RoomDetailFeature> {
        var state = RoomDetailFeature.State(room: printedRoom)
        state.photos = [photo("1"), photo("2")]

        return TestStore(initialState: state) {
            RoomDetailFeature()
        } withDependencies: {
            $0.saveAllPhotosUseCase = SaveAllPhotosUseCase(run: events)
            $0.continuousClock = ImmediateClock()
        }
    }

    private nonisolated static func stream(_ events: [SaveAllPhotosEvent]) -> AsyncStream<SaveAllPhotosEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    @Test("전부 저장하면 진행 수를 갱신하고 완료를 알린다")
    func savesEveryPhoto() async {
        let store = Self.makeStore { photos in
            #expect(photos.count == 2)
            return Self.stream([
                .progress(completed: 1, saved: 1, total: 2),
                .progress(completed: 2, saved: 2, total: 2),
                .finished(saved: 2, failed: 0, total: 2)
            ])
        }

        await store.send(.view(.downloadAllTapped)) {
            $0.downloadAll = .running(completed: 0, total: 2)
        }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 1, total: 2) }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 2, total: 2) }
        await store.receive(\.saveAllEvent) {
            $0.downloadAll = .idle
            $0.toast = RoomDetailFeature.Toast("사진 2장을 저장했어요", placement: .bottom)
        }
        await store.receive(\.toastDismissed) { $0.toast = nil }
    }

    @Test("일부만 저장되면 몇 장인지 알리고 버튼을 다시 누를 수 있게 둔다")
    func reportsPartialFailure() async {
        let store = Self.makeStore { _ in
            Self.stream([
                .progress(completed: 1, saved: 1, total: 2),
                .progress(completed: 2, saved: 1, total: 2),
                .finished(saved: 1, failed: 1, total: 2)
            ])
        }

        await store.send(.view(.downloadAllTapped)) {
            $0.downloadAll = .running(completed: 0, total: 2)
        }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 1, total: 2) }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 2, total: 2) }
        await store.receive(\.saveAllEvent) {
            $0.downloadAll = .idle
            $0.toast = RoomDetailFeature.Toast("2장 중 1장을 저장했어요", placement: .bottom)
        }
        await store.receive(\.toastDismissed) { $0.toast = nil }
    }

    @Test("사진첩 권한이 없으면 설정으로 보내는 얼럿을 띄운다")
    func showsSettingsAlertWhenPermissionDenied() async {
        let store = Self.makeStore { _ in
            Self.stream([.aborted(.permissionDenied)])
        }

        await store.send(.view(.downloadAllTapped)) {
            $0.downloadAll = .running(completed: 0, total: 2)
        }
        await store.receive(\.saveAllEvent) {
            $0.downloadAll = .idle
            $0.alert = AlertState {
                TextState("사진을 저장하지 못했어요")
            } actions: {
                ButtonState(action: .openSettingsTapped) { TextState("설정으로 이동") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.permissionDenied.userMessage)
            }
        }
    }

    @Test("저장 중 뒤로가기를 누르면 멈출지 드로어로 먼저 묻는다")
    func asksBeforeLeavingWhileDownloading() async {
        let store = Self.makeStore { _ in
            Self.stream([.progress(completed: 1, saved: 1, total: 2)])
        }

        await store.send(.view(.downloadAllTapped)) {
            $0.downloadAll = .running(completed: 0, total: 2)
        }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 1, total: 2) }

        await store.send(.view(.backButtonTapped)) {
            $0.drawer = .leaveWhileDownloading
        }

        await store.send(.view(.leaveWhileDownloadingConfirmed)) {
            $0.drawer = nil
            $0.downloadAll = .idle
        }
        await store.receive(\.delegate.closeTapped)
    }

    @Test("저장 중이 아니면 뒤로가기가 바로 닫는다")
    func leavesImmediatelyWhenIdle() async {
        let store = Self.makeStore { _ in Self.stream([]) }

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeTapped)
    }

    @Test("받는 중에는 다시 눌러도 새로 시작하지 않는다")
    func ignoresTapWhileRunning() async {
        let store = Self.makeStore { _ in
            Self.stream([.progress(completed: 1, saved: 1, total: 2)])
        }

        await store.send(.view(.downloadAllTapped)) {
            $0.downloadAll = .running(completed: 0, total: 2)
        }
        await store.receive(\.saveAllEvent) { $0.downloadAll = .running(completed: 1, total: 2) }
        await store.send(.view(.downloadAllTapped))
    }
}
