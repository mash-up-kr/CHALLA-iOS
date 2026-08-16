import CHALLADesignSystem
import ComposableArchitecture
import RoomDomain
import SwiftUI

/// 방 상세 화면. 슬롯 그리드가 본문이고, 참여자 바가 그 위에 겹쳐 뜬다.
/// 방 상태에 따라 하단이 갈린다 — 촬영 중이면 사진 찍기 버튼, 그 외에는 채팅 버튼만.
@ViewAction(for: RoomDetailFeature.self)
public struct RoomDetailView: View {

    @Bindable public var store: StoreOf<RoomDetailFeature>

    public init(store: StoreOf<RoomDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: store.room.title,
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") { send(.backButtonTapped) }
            )
            slotGrid
                .overlay(alignment: .top) { memberBar }
                // 참여자 바보다 나중에 선언해 열린 팝오버 위에 그려지게 한다 (시안 5604:19185).
                .overlay(alignment: .top) { toastLayer }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .challaMainBackground()
        .overlay(alignment: .bottom) { bottomActions }
        .task { send(.task) }
    }

    // MARK: - 슬롯 그리드

    /// 총 촬영 장수만큼 빈 슬롯을 깐다. 슬롯 크기는 FilmCard가 비율로 정하므로 열만 나눈다.
    private var slotGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.columns, spacing: RoomDetailMetric.slotSpacing) {
                ForEach(1 ... max(store.room.totalPhotoCount, 1), id: \.self) { number in
                    CHALLAFilmCard(variant: .beforeCapture, slotNumber: number)
                }
            }
            .padding(.horizontal, RoomDetailMetric.horizontalPadding)
            // 참여자 바가 그리드 첫 줄에 겹쳐 뜨므로 그 높이만큼 내려서 시작한다.
            .padding(.top, RoomDetailMetric.gridTopPadding)
            .padding(.bottom, RoomDetailMetric.gridBottomPadding)
        }
        .scrollIndicators(.hidden)
    }

    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: RoomDetailMetric.slotSpacing),
        count: RoomDetailMetric.columnCount
    )

    // MARK: - 참여자 바

    /// 상세가 조회되기 전에는 그리지 않는다 — 참여자를 모른 채 빈 캡슐만 뜨는 것을 막는다.
    /// 팝오버(초대 코드·전체 리스트)와 열림 토글은 `CHALLAProfileBar`가 담당한다.
    @ViewBuilder
    private var memberBar: some View {
        if let detail = store.detail, !detail.members.isEmpty {
            CHALLAProfileBar(
                members: detail.members.map { member in
                    .init(
                        id: String(member.id),
                        name: member.nickname ?? "프로필 미설정",
                        avatarURL: member.imageURL
                    )
                },
                inviteCode: detail.invitationCode,
                isPresented: $store.isInvitePopoverPresented,
                onCopyInviteCode: { send(.copyInviteCodeTapped) }
            )
        }
    }

    // MARK: - 토스트

    /// 복사 완료 안내. 표시 시간은 리듀서의 타이머가 정하고, 여기는 문구가 있는 동안만 그린다.
    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            CHALLAToast(toast)
                .padding(.top, RoomDetailMetric.toastTopPadding)
        }
    }

    // MARK: - 하단 동작

    private var bottomActions: some View {
        HStack(spacing: RoomDetailMetric.actionSpacing) {
            CHALLAIconButton(
                .chatTeardropDots,
                accessibilityLabel: "채팅",
                variant: .primary,
                size: .large
            ) {
                send(.chatButtonTapped)
            }

            if store.room.status == .shooting {
                CHALLATextButton(
                    "사진 찍기",
                    variant: .theme,
                    size: .large,
                    isFullWidth: true,
                    leadingIcon: .camera
                ) {
                    send(.shootButtonTapped)
                }
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, RoomDetailMetric.horizontalPadding)
        .padding(.top, RoomDetailMetric.actionTopPadding)
    }
}

// MARK: - Figma 실측값

private enum RoomDetailMetric {
    /// 좌우 가장자리 여백.
    static let horizontalPadding: CGFloat = 16
    /// 슬롯 열 수 (390pt 기준 슬롯 폭 82).
    static let columnCount = 4
    /// 슬롯 사이 간격 (가로·세로 동일).
    static let slotSpacing: CGFloat = 10
    /// 그리드 시작 내림 — 상단 바(70) 아래 시안 top 134에서 바 높이를 뺀 값에 참여자 바 겹침을 더한 것.
    static let gridTopPadding: CGFloat = 20
    /// 그리드 하단 — 하단 버튼(54)에 가려지지 않을 여유.
    static let gridBottomPadding: CGFloat = 78
    /// 토스트 내림 — 시안 top 122 − 상단 바 하단 114.
    static let toastTopPadding: CGFloat = 8
    /// 채팅 버튼과 사진 찍기 버튼 사이 (시안 8).
    static let actionSpacing: CGFloat = 8
    /// 버튼 위 여백 (시안 8).
    static let actionTopPadding: CGFloat = 8
}

// MARK: - Preview

#Preview("촬영 중") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = .previewValue
        }
    )
}

#Preview("조회 실패 (참여자 바 없음)") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in throw RoomError.network })
        }
    )
}
