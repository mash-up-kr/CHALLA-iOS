import ComposableArchitecture
import SwiftUI

/// 앱 최상위 View. 화면(`AppView`) 위에 화면과 무관한 것을 얹는다.
///
/// 지금 얹는 것은 방 참여 토스트 하나다 — 어느 화면에 있든 떠야 해서 여기가 자리다.
public struct RootView: View {

    private let store: StoreOf<RootFeature>

    public init(store: StoreOf<RootFeature>) {
        self.store = store
    }

    public var body: some View {
        AppView(store: store.scope(state: \.app, action: \.app))
            .overlay(alignment: .top) {
                if let joined = store.joinToast {
                    Button {
                        store.send(.toastTapped)
                    } label: {
                        RoomJoinToastView(joined: joined)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Metric.topInset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: Metric.animationDuration), value: store.joinToast)
    }
}

private enum Metric {
    /// 상태 표시줄 아래 여백. TODO: 시안 대조 전 임시값.
    static let topInset: CGFloat = 8
    static let animationDuration: TimeInterval = 0.25
}
