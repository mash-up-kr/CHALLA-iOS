import ComposableArchitecture
import Foundation
import PhotoDetailFeature
import PhotoDomain
import Testing
import UIKit

@MainActor
@Suite("PhotoDetailFeature — 저장과 화면 닫기")
struct PhotoDetailSaveTests {

    private var savedAlert: AlertState<PhotoDetailFeature.Action.Alert> {
        AlertState {
            TextState("사진을 저장했어요")
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        }
    }

    @Test("저장에 성공하면 완료 얼럿을 띄운다")
    func savesPhoto() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], save: { saved in
            #expect(saved.id == "photo-1")
        })

        await store.send(.view(.downloadButtonTapped)) { $0.isSaving = true }
        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
            $0.alert = self.savedAlert
        }
    }

    @Test("권한이 거부되면 설정으로 보내는 얼럿을 띄운다")
    func showsSettingsAlertOnPermissionDenied() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], save: { _ in throw PhotoError.permissionDenied })

        await store.send(.view(.downloadButtonTapped)) { $0.isSaving = true }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.alert = AlertState {
                TextState("사진을 저장하지 못했어요")
            } actions: {
                ButtonState(action: .openSettingsButtonTapped) { TextState("설정으로 이동") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.permissionDenied.userMessage)
            }
        }
    }

    @Test("권한 문제가 아니면 설정 이동 버튼을 붙이지 않는다")
    func omitsSettingsButtonForOtherFailures() async {
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], save: { _ in throw PhotoError.saveFailed })

        await store.send(.view(.downloadButtonTapped)) { $0.isSaving = true }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.alert = AlertState {
                TextState("사진을 저장하지 못했어요")
            } actions: {
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.saveFailed.userMessage)
            }
        }
    }

    @Test("설정으로 이동을 누르면 앱 설정 화면을 연다")
    func opensAppSettings() async {
        let opened = LockIsolated([URL]())
        let target = Fixture.photo(id: "photo-1")
        let store = await openedTestStore(photos: [target], save: { _ in throw PhotoError.permissionDenied })
        store.dependencies.openURL = OpenURLEffect { url in
            opened.withValue { $0.append(url) }
            return true
        }

        await store.send(.view(.downloadButtonTapped)) { $0.isSaving = true }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.alert = AlertState {
                TextState("사진을 저장하지 못했어요")
            } actions: {
                ButtonState(action: .openSettingsButtonTapped) { TextState("설정으로 이동") }
                ButtonState(role: .cancel) { TextState("확인") }
            } message: {
                TextState(PhotoError.permissionDenied.userMessage)
            }
        }

        await store.send(.alert(.presented(.openSettingsButtonTapped))) { $0.alert = nil }
        #expect(opened.value == [URL(string: UIApplication.openSettingsURLString)])
    }

    @Test("저장 중에 다시 누르면 요청이 한 번만 나간다")
    func ignoresDuplicateSaveTap() async {
        let target = Fixture.photo(id: "photo-1")
        let callCount = LockIsolated(0)
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        let store = await openedTestStore(photos: [target], save: { _ in
            callCount.withValue { $0 += 1 }
            await stream.first { _ in true }
        })

        await store.send(.view(.downloadButtonTapped)) { $0.isSaving = true }
        await store.send(.view(.downloadButtonTapped))

        continuation.yield()
        continuation.finish()
        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
            $0.alert = self.savedAlert
        }
        #expect(callCount.value == 1)
    }

    @Test("뒤로가기는 닫아 달라고 알리기만 한다")
    func requestsCloseOnBack() async {
        let store = makeTestStore()

        await store.send(.view(.backButtonTapped))
        await store.receive(\.delegate.closeRequested)
    }
}
