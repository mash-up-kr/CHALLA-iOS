import CameraFeature
import ComposableArchitecture
import PhotoDomain
import RoomDomain
import SwiftUI

/// 카메라 화면으로 들어가는 길목. 실앱의 진입 버튼(홈·방 상세)이 하는 일을 데모에서 대신한다 —
/// 방·필터 목록을 먼저 받아 두고, 둘 다 성공했을 때만 카메라 화면을 띄운다.
/// 하나라도 실패하면 카메라로 넘어가지 않고 이 자리에서 알린다.
struct CameraEntryView: View {

    let scenario: DemoScenario

    /// 실기기 카메라 세션. 리듀서와 프리뷰가 같은 세션을 봐야 해서 진입 화면이 받아 넘긴다.
    let cameraSession: CameraSessionController

    @State private var phase: Phase = .loading

    private enum Phase {
        case loading
        case loaded(rooms: [ShootableRoom], filters: [CameraFilter])
        case failed(String)
    }

    var body: some View {
        content
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)

        case let .loaded(rooms, filters):
            cameraScreen(rooms: rooms, filters: filters)

        case let .failed(message):
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)
                Button("다시 시도") {
                    phase = .loading
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cameraScreen(rooms: [ShootableRoom], filters: [CameraFilter]) -> some View {
        let demoStore = Store(
            initialState: CameraDemoFeature.State(
                camera: scenario.featureState(rooms: rooms, filters: filters)
            )
        ) {
            CameraDemoFeature()._printChanges()
        } withDependencies: {
            CompositionRoot.registerDependencies(for: scenario, into: &$0)
        }
        let cameraStore = demoStore.scope(state: \.camera, action: \.camera)

        return CameraView(store: cameraStore) {
            LiveCameraPreview(session: cameraSession, store: cameraStore)
        }
    }

    /// 두 목록을 나란히 받는다 — 실앱의 진입 버튼도 같은 방식으로 한 번에 기다린다.
    private func load() async {
        guard case .loading = phase else { return }

        await withDependencies {
            CompositionRoot.registerDependencies(for: scenario, into: &$0)
        } operation: {
            // 주입을 갈아끼운 뒤에 꺼내야 한다 — 뷰의 저장 프로퍼티로 두면 생성 시점 값이 잡힌다.
            @Dependency(\.fetchShootableRoomsUseCase) var fetchShootableRooms
            @Dependency(\.fetchCameraFiltersUseCase) var fetchCameraFilters

            do {
                async let rooms = fetchShootableRooms.run()
                async let filters = fetchCameraFilters.run()
                phase = try await .loaded(rooms: rooms, filters: filters)
            } catch let error as RoomError {
                phase = .failed(error.userMessage)
            } catch let error as PhotoError {
                phase = .failed(error.userMessage)
            } catch {
                phase = .failed(PhotoError.unknown.userMessage)
            }
        }
    }
}
