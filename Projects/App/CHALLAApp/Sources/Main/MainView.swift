import ChatRoomFeature
import ComposableArchitecture
import HomeFeature
import PhotoDetailFeature
import RoomDetailFeature
import SwiftUI

/// 로그인 뒤 화면. 앱에서 유일한 `NavigationStack` — 홈이 루트, 나머지는 `path`에 쌓인 순서대로.
///
/// 스택 안 화면은 전부 `CHALLATopNavigation`을 직접 그리므로 시스템 바를 숨긴다.
/// 바를 숨기면 UIKit이 스와이프 백을 꺼 버려 `InteractivePopGestureEnabler`로 되살린다 —
/// 스택 전체가 컨트롤러 하나를 공유하므로 루트에 한 번만 붙이면 된다.
struct MainView: View {

    @Bindable var store: StoreOf<MainFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
                .background { InteractivePopGestureEnabler().frame(width: 0, height: 0) }
        } destination: { pathStore in
            // `pathStore`는 루트가 아니라 스택 원소 하나의 Store. `.case`로 어느 화면인지 꺼낸다.
            Group {
                switch pathStore.case {
                case let .roomDetail(store):
                    RoomDetailView(store: store)
                case let .photoDetail(store):
                    PhotoDetailView(store: store)
                case let .chat(store):
                    ChatRoomView(store: store)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
