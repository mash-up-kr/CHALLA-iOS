import CHALLADesignSystem
import SwiftUI

/// Component > Drawer 검수 화면.
/// 드로어는 떠 있는 상태가 실제 모습이므로 정적 나열 대신 Figma EXAMPLE 전부를
/// 버튼으로 나열하고, 탭하면 진짜 프레젠테이션(딤·등장·끌어내리기·키보드)으로 띄운다.
struct DrawerGallery: View {

    /// Figma EXAMPLE 목록. 케이스 추가 = 목록 버튼·드로어 자동 추가.
    private enum Example: CaseIterable, Identifiable {
        case profilePhoto
        case withdrawConfirm
        case withdrawDone
        case buttonless
        case createRoom
        case longTitle

        var id: Self {
            self
        }

        /// 목록 버튼에 표시할 문구.
        var label: String {
            switch self {
            case .profilePhoto: "프로필 사진 — 버튼 2 + 보조 액션"
            case .withdrawConfirm: "회원 탈퇴 확인 — 메시지 + destructive 채움"
            case .withdrawDone: "탈퇴 완료 — 메시지 + 버튼 1"
            case .buttonless: "버튼 0 — 콘텐츠만"
            case .createRoom: "방 만들기 — 타이틀 헤더 + 입력 + 장수 선택"
            case .longTitle: "긴 타이틀 — 말줄임 검수"
            }
        }

        /// 딤 탭·끌어내리기로 닫아도 되는가.
        /// 닫기 버튼이 있는 타이틀 헤더 드로어는 입력 보호를 위해 false — 닫기 버튼으로만 닫는다.
        var allowsInteractiveDismiss: Bool {
            switch self {
            case .createRoom, .longTitle: false
            case .profilePhoto, .withdrawConfirm, .withdrawDone, .buttonless: true
            }
        }
    }

    @State private var activeExample: Example?
    @State private var isPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                galleryTitle("Examples")
                galleryCaption("탭하면 실제로 뜬다 — 핸들 드로어는 딤 탭·끌어내리기로, 타이틀 드로어는 닫기 버튼으로만 닫힘")
                ForEach(Example.allCases) { example in
                    CHALLATextButton(example.label, variant: .neutral, size: .medium, isFullWidth: true) {
                        present(example)
                    }
                }
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Drawer")
        .navigationBarTitleDisplayMode(.inline)
        .challaDrawer(
            isPresented: $isPresented,
            allowsInteractiveDismiss: activeExample?.allowsInteractiveDismiss ?? true
        ) {
            // activeExample은 닫힘 애니메이션 동안 남겨둔다 (nil로 비우면 내려가는 카드가 빈 껍데기가 됨)
            if let activeExample {
                drawer(for: activeExample)
            }
        }
    }

    private func present(_ example: Example) {
        activeExample = example
        isPresented = true
    }

    private func dismiss() {
        isPresented = false
    }

    /// 예시 → 드로어 연결 목차. 조립은 아래 프로퍼티·뷰가 하나씩 맡는다.
    @ViewBuilder
    private func drawer(for example: Example) -> some View {
        switch example {
        case .profilePhoto: profilePhotoDrawer
        case .withdrawConfirm: withdrawConfirmDrawer
        case .withdrawDone: withdrawDoneDrawer
        case .buttonless: buttonlessDrawer
        case .createRoom: CreateRoomDrawerDemo(onFinish: dismiss)
        case .longTitle: longTitleDrawer
        }
    }

    // MARK: - 예시별 드로어

    private var profilePhotoDrawer: some View {
        CHALLADrawer(
            header: .handle,
            actions: [
                CHALLADrawerAction("앨범에서 선택", variant: .neutral) { dismiss() },
                CHALLADrawerAction("프로필 사진 삭제", variant: .neutral, role: .destructive) { dismiss() }
            ],
            auxiliaryAction: CHALLADrawerAction("보조 액션") { dismiss() }
        )
    }

    private var withdrawConfirmDrawer: some View {
        CHALLADrawer(
            header: .handle,
            actions: [CHALLADrawerAction("그래도 탈퇴하기", role: .destructive) { dismiss() }],
            auxiliaryAction: CHALLADrawerAction("닫기") { dismiss() }
        ) {
            CHALLADrawerMessage("모든 기록이 사라져요", description: "탈퇴 시 참여 중이던 방에서 나가져요")
        }
    }

    private var withdrawDoneDrawer: some View {
        CHALLADrawer(
            header: .handle,
            actions: [CHALLADrawerAction("확인") { dismiss() }]
        ) {
            CHALLADrawerMessage("회원 탈퇴가\n정상적으로 완료 됐어요")
        }
    }

    private var buttonlessDrawer: some View {
        CHALLADrawer(header: .handle) {
            CHALLADrawerMessage("버튼 없는 드로어", description: "buttonCount 0 케이스 — 딤 탭이나 끌어내리기로만 닫는다")
        }
    }

    private var longTitleDrawer: some View {
        CHALLADrawer(
            header: .title("아주아주 길어서 한 줄에 다 안 들어가는 드로어 타이틀", onClose: { dismiss() }),
            actions: [CHALLADrawerAction("확인") { dismiss() }]
        )
    }

    // MARK: - 공용 헬퍼

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
    }

    private func galleryCaption(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.alternative)
    }
}

// MARK: - 방 만들기 데모

/// 방 만들기 예시 — 입력·장수 선택 상태를 스스로 소유한다.
/// 드로어가 닫히면 이 뷰가 제거되고 다시 열 때 새로 만들어지므로 @State가 초기값으로 돌아온다 (리셋 코드 불필요).
private struct CreateRoomDrawerDemo: View {
    @State private var roomName = ""
    @State private var photoCount = 24

    /// 닫기 버튼·만들기 버튼이 눌렸을 때 호출 (갤러리의 dismiss).
    let onFinish: () -> Void

    var body: some View {
        CHALLADrawer(
            header: .title("방 만들기", onClose: onFinish),
            actions: [CHALLADrawerAction("만들기", isEnabled: !roomName.isEmpty) { onFinish() }]
        ) {
            // 간격 21·12는 핸드오프 "방 만들기" 모달 실측값 (노드 4388:8987)
            VStack(spacing: 21) {
                CHALLATextField(text: $roomName, placeholder: "방 이름 입력", textAlignment: .leading)
                VStack(spacing: 12) {
                    Text("얼마나 찍을까요?")
                        .challaFont(.body.xsmall.medium)
                        .foregroundStyle(CHALLAColor.Label.alternative)
                    HStack(spacing: 4) {
                        photoCountButton(24)
                        photoCountButton(48)
                        photoCountButton(72)
                    }
                }
            }
        }
    }

    /// 장수 선택 버튼 — 데모용 임시 조립. 선택 상태가 있는 세그먼트는
    /// 아직 DS 컴포넌트가 없어 토큰으로만 구성했다 (정식 컴포넌트는 별도 이슈 후보).
    /// 스타일은 핸드오프 실측(노드 4412:1407·5490:22148):
    /// 선택 = Level 4 배경 + Line.normal 1.5pt 테두리 + Label.normal 글자,
    /// 비선택 = Level 2 배경 + Label.neutral 글자. 높이 52 · 균등폭 · radius 12.
    private func photoCountButton(_ count: Int) -> some View {
        let isSelected = photoCount == count
        return Button {
            photoCount = count
        } label: {
            Text("\(count)장")
                .challaFont(.body.medium.bold)
                .foregroundStyle(isSelected ? CHALLAColor.Label.normal : CHALLAColor.Label.neutral)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: CHALLARadius.large)
                        .fill(isSelected ? CHALLAColor.Background.level4 : CHALLAColor.Background.level2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CHALLARadius.large)
                        .stroke(CHALLAColor.Line.normal, lineWidth: isSelected ? 1.5 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DrawerGallery()
    }
}
