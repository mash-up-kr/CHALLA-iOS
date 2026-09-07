import CHALLADesignSystem
import SwiftUI

/// Component > Main Background 검수 화면.
/// 화면 전체에 붙인 배경 위에 얹는 내용을 바꿔 가며 하단 번짐과 콘텐츠 대비를 본다.
struct MainBackgroundGallery: View {

    @State private var overlay: Overlay = .empty

    var body: some View {
        VStack(spacing: 0) {
            picker
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .challaMainBackground()
        .navigationTitle("Main Background")
        .navigationBarTitleDisplayMode(.inline)
        // 배경이 네비바 밑까지 어둡게 칠하므로 바 글자도 밝은 쪽으로 맞춘다.
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// 시스템 Picker는 어두운 배경에서 선택되지 않은 칸이 묻혀 DS 버튼으로 대신한다.
    private var picker: some View {
        HStack(spacing: 8) {
            ForEach(Overlay.allCases, id: \.self) { option in
                CHALLATextButton(
                    option.title,
                    variant: overlay == option ? .theme : .neutral,
                    size: .medium
                ) {
                    overlay = option
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        switch overlay {
        case .empty:
            Spacer()

        case .card:
            // 번짐에서 먼 위쪽에 둬서 카드 배경이 배경색에 묻히지 않는지 본다.
            CHALLARoomCard(
                title: "친구들과 강릉 여행",
                memberCount: 11,
                photo: nil,
                variant: .shooting(shotCount: 24, totalCount: 24, isPreparing: false, onShoot: nil)
            )
            .padding(.top, 20)
            Spacer()

        case .actions:
            // 번짐이 가장 진한 하단에 버튼을 둔다 (홈 빈 상태와 같은 배치).
            Spacer()
            VStack(spacing: 8) {
                CHALLATextButton("방 만들기", variant: .theme, isFullWidth: true) {}
                CHALLATextButton("초대 코드로 입장하기", isFullWidth: true) {}
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    private enum Overlay: CaseIterable {
        case empty, card, actions

        var title: String {
            switch self {
            case .empty: "배경만"
            case .card: "카드"
            case .actions: "버튼"
            }
        }
    }
}

#Preview {
    NavigationStack {
        MainBackgroundGallery()
    }
}
