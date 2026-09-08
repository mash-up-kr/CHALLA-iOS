import AppDomain
import ComposableArchitecture
import Foundation
import HomeFeature
import UserDomain

// MARK: - Effects

extension AppFeature {

    enum CancelID { case profile, sessionExpiration, updateCheck, splashHold }

    /// 링크로 실행된 콜드 스타트의 마무리 — 보관해 둔 초대 코드가 있으면 홈에 넘겨 입장을 잇는다.
    func deliverPendingInviteCode() -> Effect<Action> {
        .run { [pendingInviteCode] send in
            guard let code = pendingInviteCode.take() else { return }
            await send(.home(.inviteCodeReceived(code)))
        }
    }

    /// 실행 직후 1회 버전 체크.
    /// 실패는 `.notRequired`로 접는다 — 체크 서버가 죽었다고 전 사용자 앱을 스플래시에 가둘 수는 없다.
    func checkAppUpdate() -> Effect<Action> {
        .run { [checkAppUpdateUseCase] send in
            // 취소되면 send 자체가 무시되므로 try? 가 취소를 .notRequired 로 오인해도 화면이 진행되지 않는다.
            let requirement = await (try? checkAppUpdateUseCase.run()) ?? .notRequired
            await send(.updateCheckResponse(requirement))
        }
        .cancellable(id: CancelID.updateCheck, cancelInFlight: true)
    }

    /// 저절로 풀릴 수 있는 실패가 이어질 때의 재시도 정책.
    enum RetryBackoff {
        /// 첫 시도를 포함한 총 시도 횟수. 상한이 없으면 화면이 스플래시에 멈춘 채 빠져나가지 못한다.
        static let maxAttempts = 5

        /// 시도 사이의 대기 간격. 마지막 값이 상한이다.
        private static let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]

        static func delay(for attempt: Int) -> Duration {
            delays[min(attempt, delays.count - 1)]
        }
    }

    /// 저장된 세션이 있을 때만 프로필을 조회한다 — 없으면 실패할 요청을 보내지 않고 곧바로 로그인 화면으로 간다.
    func restoreSession() -> Effect<Action> {
        .run { [restoreSessionUseCase] send in
            await send(.sessionRestored(restoreSessionUseCase.run()))
        }
    }

    /// 토큰 갱신이 최종 실패하면(재로그인 필요) 어느 화면에 있든 로그인으로 되돌린다.
    func observeSessionExpiration() -> Effect<Action> {
        .run { [sessionExpirationChannel] send in
            for await _ in sessionExpirationChannel.events {
                await send(.sessionExpired)
            }
        }
        .cancellable(id: CancelID.sessionExpiration, cancelInFlight: true)
    }

    func fetchMyProfile() -> Effect<Action> {
        .run { [fetchMyProfileUseCase, clock] send in
            for attempt in 0 ..< RetryBackoff.maxAttempts {
                do {
                    let profile = try await fetchMyProfileUseCase.run()
                    await send(.profileResponse(.success(profile)))
                    return
                } catch is CancellationError {
                    return
                } catch let error as UserError
                    where error.isRetryable && attempt < RetryBackoff.maxAttempts - 1 {
                    // 사용자가 손쓸 수 없는 실패다 — 알리지 않고 아래에서 대기 후 재시도한다.
                } catch {
                    // 재시도로 풀리지 않는 실패와 마지막 시도의 실패가 함께 여기로 온다.
                    await send(.profileResponse(.failure((error as? UserError) ?? .unknown)))
                    return
                }

                // try? 로 감싸면 취소된 뒤에도 루프가 계속 돈다 — 취소는 그대로 밖으로 던진다.
                try await clock.sleep(for: RetryBackoff.delay(for: attempt))
            }
        }
        .cancellable(id: CancelID.profile, cancelInFlight: true)
    }
}
