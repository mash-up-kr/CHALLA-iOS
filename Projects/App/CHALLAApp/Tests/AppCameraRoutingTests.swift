@testable import CHALLAApp
import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain
import ShootEntry
import Testing
import UserDomain

/// `@MainActor` 밖에 둔다 — 진입 재료를 액터 경계 너머에서 읽는다.
private enum CameraFixture {
    static let profile = UserProfile(
        id: 1,
        nickname: "찰나",
        imageURL: URL(string: "https://cdn.example.com/me.jpg")
    )
    static let card = RoomCard.previewShooting
    /// 진입 버튼이 준비를 마치고 넘기는 재료. App은 내용을 보지 않고 그대로 카메라에 옮겨 담는다.
    static let cameraEntry = CameraEntry(
        roomID: card.id,
        rooms: [
            ShootableRoom(id: card.id, title: card.room.title, remainedPhotoCount: 6, totalPhotoCount: 24)
        ],
        filters: CameraFilter.previewFilters
    )
}

/// 카메라는 덮었다 걷히는 화면이라, 닫을 때 들어온 곳으로 되돌아가는 것까지가 App의 몫이다.
@MainActor
@Suite("AppFeature — 카메라 진입·이탈")
struct AppCameraRoutingTests {

    private static func store(initialState: AppFeature.State) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        }
    }

    @Test("방 상세에서 촬영 준비가 끝나면 그 방이 선택된 카메라로 들어간다")
    func opensCameraFromRoomDetail() async {
        let store = Self.store(
            initialState: .roomDetail(
                AppFeature.RoomDetailScreen(profile: CameraFixture.profile, room: CameraFixture.card.room)
            )
        )

        await store.send(.roomDetail(.delegate(.cameraRequested(CameraFixture.cameraEntry)))) {
            $0 = .camera(
                AppFeature.CameraScreen(
                    profile: CameraFixture.profile,
                    entry: CameraFixture.cameraEntry,
                    origin: .roomDetail(CameraFixture.card.room)
                )
            )
        }
    }

    /// 방에서 나가지 않고 카메라만 덮었다 걷히는 흐름이라 홈이 아니라 그 방으로 돌아간다.
    @Test("방 상세에서 들어간 카메라를 닫으면 방 상세를 새로 만들어 돌아간다")
    func returnsToRoomDetailFromCamera() async {
        let store = Self.store(
            initialState: .camera(
                AppFeature.CameraScreen(
                    profile: CameraFixture.profile,
                    entry: CameraFixture.cameraEntry,
                    origin: .roomDetail(CameraFixture.card.room)
                )
            )
        )

        await store.send(.camera(.camera(.delegate(.closeRequested)))) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(profile: CameraFixture.profile, room: CameraFixture.card.room)
            )
        }
    }

    @Test("홈에서 들어간 카메라를 닫으면 홈으로 돌아간다")
    func returnsHomeFromCamera() async {
        let store = Self.store(
            initialState: .camera(
                AppFeature.CameraScreen(
                    profile: CameraFixture.profile,
                    entry: CameraFixture.cameraEntry,
                    origin: .home
                )
            )
        )

        await store.send(.camera(.camera(.delegate(.closeRequested)))) {
            $0 = .home(AppFeature.HomeScreen(profile: CameraFixture.profile))
        }
    }

    /// 촬영을 마치면 닫기와 달리 찍은 방의 상세로 들어간다 — 방금 넣은 사진을 강조한 채로.
    @Test("촬영이 끝나면 찍은 방의 상세로 넘어가고 방금 올린 사진을 강조한다")
    func movesToRoomDetailAfterCapture() async {
        let store = Self.store(
            initialState: .camera(
                AppFeature.CameraScreen(
                    profile: CameraFixture.profile,
                    entry: CameraFixture.cameraEntry,
                    origin: .roomDetail(CameraFixture.card.room)
                )
            )
        )

        await store.send(.camera(.camera(.delegate(.captureFinished(roomID: CameraFixture.card.id))))) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: CameraFixture.profile,
                    room: CameraFixture.card.room,
                    highlightsNewestPhoto: true
                )
            )
        }
    }

    @Test("홈에서 들어갔어도 촬영이 끝나면 맡아둔 목록에서 방을 찾아 상세로 넘어간다")
    func movesToRoomDetailAfterCaptureFromHome() async {
        let store = Self.store(
            initialState: .camera(
                AppFeature.CameraScreen(
                    profile: CameraFixture.profile,
                    entry: CameraFixture.cameraEntry,
                    origin: .home,
                    homeCards: [CameraFixture.card]
                )
            )
        )

        await store.send(.camera(.camera(.delegate(.captureFinished(roomID: CameraFixture.card.id))))) {
            $0 = .roomDetail(
                AppFeature.RoomDetailScreen(
                    profile: CameraFixture.profile,
                    room: CameraFixture.card.room,
                    homeCards: [CameraFixture.card],
                    highlightsNewestPhoto: true
                )
            )
        }
    }
}
