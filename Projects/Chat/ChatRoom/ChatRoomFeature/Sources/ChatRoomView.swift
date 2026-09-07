import CHALLADesignSystem
import ChatDomain
import ComposableArchitecture
import SwiftUI
import UIKit

/// 방 채팅 화면(개별 상세)
@ViewAction(for: ChatRoomFeature.self)
public struct ChatRoomView: View {

    @Bindable public var store: StoreOf<ChatRoomFeature>

    /// 하단 그라데이션에 쓰는 강조 색 (PhotoDetailView와 같다).
    @Environment(\.challaTheme) private var theme

    /// 더보기로 이전 메시지를 위에 붙일 때, 스크롤 위치를 유지하려고 붙이기 직전의 맨 위 메시지 id를 기억한다.
    @State private var anchorMessageID: UUID?

    public init(store: StoreOf<ChatRoomFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            CHALLAColor.Background.surface
                .ignoresSafeArea()
                // 빈 영역을 탭하면 키보드를 내린다.
                .onTapGesture { dismissKeyboard() }
            glow.ignoresSafeArea()
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear { send(.onAppear) }
    }

    private var content: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: store.roomTitle,
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                }
            )

            messageList

            CHALLAMessageInputBar(
                text: Binding(get: { store.draft }, set: { send(.draftChanged($0)) }),
                placeholder: "메시지를 보내 보세요."
            ) {
                send(.sendTapped)
            }
            .padding(.horizontal, Metric.inputHorizontalPadding)
            .padding(.top, Metric.inputTopPadding)
            // 키보드가 올라와도 입력창이 키보드에 붙지 않고 위에 마진이 남게 한다.
            .padding(.bottom, Metric.inputBottomPadding)
        }
    }

    // MARK: - 메시지 목록

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metric.rowSpacing) {
                    // 맨 위에 닿으면(위로 스크롤) 이전 메시지를 더 불러온다. 붙이기 전 위치를 기억해 둔다.
                    if store.hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                anchorMessageID = store.messages.first?.id
                                send(.reachedTop)
                            }
                    }
                    if store.isLoadingMore {
                        ProgressView()
                            .tint(CHALLAColor.Label.neutral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Metric.loadMoreSpacing)
                    }

                    ForEach(displayRows) { row in
                        if row.showDateDivider {
                            dateDivider(row.message.createdAt)
                        }
                        ChatMessageRow(
                            message: row.message,
                            isMine: row.message.isMine(currentUserNickname: store.currentUserNickname),
                            isPhotoBlurred: !store.isPrinted
                        )
                        .id(row.message.id)
                    }
                }
                .padding(.horizontal, Metric.listHorizontalPadding)
                .padding(.vertical, Metric.listVerticalPadding)
                .frame(maxWidth: .infinity)
                // 목록 영역을 탭해도 키보드를 내린다(메시지는 탭 동작이 없다).
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            // 진입 시 최신 메시지(맨 아래)부터 보여준다 — 맨 위 더보기 트리거가 진입 즉시 발동하지 않게도 한다.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if store.isLoading, store.messages.isEmpty {
                    ProgressView().tint(CHALLAColor.Label.neutral)
                }
            }
            .onChange(of: store.messages.last?.id) {
                scrollToBottom(proxy)
            }
            // 이전 메시지를 위에 붙인 뒤, 붙이기 전 맨 위 메시지로 스크롤을 되돌려 위치를 유지한다.
            .onChange(of: store.messages.first?.id) {
                guard let anchor = anchorMessageID else { return }
                proxy.scrollTo(anchor, anchor: .top)
                anchorMessageID = nil
            }
        }
    }

    private func dateDivider(_ date: Date) -> some View {
        Text(Self.dateFormatter.string(from: date))
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.neutral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metric.dividerVerticalPadding)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = store.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 하단 배경 그라데이션 (PhotoDetailView와 같은 연출).
    private var glow: some View {
        Ellipse()
            .fill(theme.accent.opacity(Metric.glowOpacity))
            .frame(height: Metric.glowHeight)
            .blur(radius: Metric.glowBlurRadius)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: - 표시용 행 (날짜 구분선 삽입)

    private struct DisplayRow: Identifiable {
        let id: UUID
        let message: ChatMessage
        let showDateDivider: Bool
    }

    private var displayRows: [DisplayRow] {
        let calendar = Calendar.current
        return store.messages.enumerated().map { index, message in
            let showDivider: Bool = if index == 0 {
                true
            } else {
                !calendar.isDate(
                    message.createdAt,
                    inSameDayAs: store.messages[index - 1].createdAt
                )
            }
            return DisplayRow(id: message.id, message: message, showDateDivider: showDivider)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M.d."
        return formatter
    }()
}

private enum Metric {
    static let rowSpacing: CGFloat = 16
    static let loadMoreSpacing: CGFloat = 8
    static let listHorizontalPadding: CGFloat = 16
    static let listVerticalPadding: CGFloat = 12
    static let dividerVerticalPadding: CGFloat = 4
    static let inputHorizontalPadding: CGFloat = 16
    static let inputTopPadding: CGFloat = 8
    static let inputBottomPadding: CGFloat = 12
    /// 배경 그라데이션 390 × 244, 투명도 20%.
    static let glowHeight: CGFloat = 244
    static let glowOpacity: Double = 0.2
    static let glowBlurRadius: CGFloat = 150
}
