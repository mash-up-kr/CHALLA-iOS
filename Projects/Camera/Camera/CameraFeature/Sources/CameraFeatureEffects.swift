import ComposableArchitecture
import Foundation
import PhotoDomain
import RoomDomain

/// 리듀서가 돌려주는 이펙트 모음. 서버 호출·타이머처럼 화면 밖에서 벌어지는 일만 모은다
/// (본체는 상태 전이만 읽히도록 남긴다).
extension CameraFeature {

    func loadRooms() -> Effect<Action> {
        .run { [fetchShootableRooms] send in
            do {
                let rooms = try await fetchShootableRooms.run()
                await send(.roomsResponse(.success(rooms)))
            } catch let error as RoomError {
                await send(.roomsResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.roomsResponse(.failure(.unknown)))
            }
        }
    }

    func loadFilters() -> Effect<Action> {
        .run { [fetchCameraFilters] send in
            do {
                let filters = try await fetchCameraFilters.run()
                await send(.filtersResponse(.success(filters)))
            } catch let error as PhotoError {
                await send(.filtersResponse(.failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.filtersResponse(.failure(.unknown)))
            }
        }
    }

    /// LUT 하나를 내려받아 카탈로그에 등록한다. 실패해도 화면은 계속 쓸 수 있어야 하므로
    /// (그 필터만 무보정 통과) 오류를 사용자에게 알리지 않고 삼킨다.
    func prepareLUT(_ filter: CameraFilter) -> Effect<Action> {
        .run { [loadFilterLUT] send in
            guard let data = try? await loadFilterLUT.run(filter),
                  CameraFilterCatalog.register(cubeData: data, for: filter.id)
            else { return }
            await send(.filterLUTPrepared(filter.id))
        }
    }

    func upload(
        jpegData: Data,
        roomID: ShootableRoom.ID,
        filterID: CameraFilter.ID?
    ) -> Effect<Action> {
        .run { [uploadPhoto] send in
            do {
                // TODO: 백엔드 확인 — cameraFilterName이 필수라 무필터 촬영 시 보낼 값이 정해지지 않았다.
                //       (서버 필터 목록에 "원본" 항목이 포함되는지 확인 후 확정)
                let remained = try await uploadPhoto.run(jpegData, roomID, filterID ?? "")
                await send(.uploadResponse(roomID: roomID, .success(remained)))
            } catch let error as PhotoError {
                await send(.uploadResponse(roomID: roomID, .failure(error)))
            } catch is CancellationError {
            } catch {
                await send(.uploadResponse(roomID: roomID, .failure(.unknown)))
            }
        }
    }

    /// 진입 직후 잠깐 뜸을 들였다가 안내 1단계를 띄운다. 이미 시작했으면 아무것도 하지 않는다.
    func startCoachMark(_ state: inout State) -> Effect<Action> {
        guard !state.hasStartedCoachMark else { return .none }
        state.hasStartedCoachMark = true
        return .run { [clock] send in
            try await clock.sleep(for: CameraCoachMark.presentationDelay)
            await send(.coachMarkDelayElapsed)
        }
        .cancellable(id: CancelID.coachMark, cancelInFlight: true)
    }

    func dismissToastAfterDelay() -> Effect<Action> {
        .run { [clock] send in // 비-Sendable self 대신 의존성 값만 캡처
            try await clock.sleep(for: Self.toastDuration)
            await send(.toastDismissed)
        }
        .cancellable(id: CancelID.toast, cancelInFlight: true)
    }

    enum CancelID { case toast, coachMark }

    static var toastDuration: Duration {
        .seconds(3)
    }
}
