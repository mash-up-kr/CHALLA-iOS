import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import SwiftUI
import UIKit

/// 사진 상세 화면
@ViewAction(for: PhotoDetailFeature.self)
public struct PhotoDetailView: View {

    @Environment(\.challaTheme) private var theme

    @Bindable public var store: StoreOf<PhotoDetailFeature>

    /// 입력창이 차지하는 높이 — 콘텐츠가 그만큼 하단 여백을 비워 입력창과 겹치지 않게 한다.
    @State private var inputHeight: CGFloat = 0

    public init(store: StoreOf<PhotoDetailFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .bottom) {
            CHALLAColor.Background.surface
                .ignoresSafeArea()
                // 빈 영역을 탭하면 키보드를 내린다.
                .onTapGesture { dismissKeyboard() }
            glow.ignoresSafeArea()

            content
                // 입력창 자리만큼 하단을 비운다(입력창은 오버레이라 콘텐츠 레이아웃에 안 낀다).
                .padding(.bottom, inputHeight)
                // 키보드가 올라와도 콘텐츠(사진·리액션)는 반응하지 않아 리사이즈되지 않는다 — 채팅 화면과 동일.
                .ignoresSafeArea(.keyboard, edges: .bottom)

            // 입력창만 키보드 위로 떠오르고, 키보드는 아래(리액션 바·사진 하단)를 덮기만 한다.
            messageField
                .padding(.top, Metric.messageFieldTopSpacing)
                .padding(.horizontal, Metric.messageFieldHorizontalPadding)
                .padding(.bottom, Metric.messageFieldBottomSpacing)
                .background(
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.size.height, initial: true) { _, height in
                            inputHeight = height
                        }
                    }
                )

            if store.isSaving {
                savingOverlay
            }

            toastLayer
                .animation(.easeInOut(duration: Metric.toastFadeDuration), value: store.toast)
        }
        // 탑 내비게이션을 직접 그리므로 시스템 바는 숨긴다.
        .toolbar(.hidden, for: .navigationBar)
        .alert($store.scope(state: \.alert, action: \.alert))
        .challaDrawer(isPresented: isDrawerPresented) {
            deleteReactionDrawer
        }
        .onAppear { send(.onAppear) }
    }

    private var content: some View {
        VStack(spacing: 0) {
            CHALLATopNavigation.sub(
                title: store.roomTitle,
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {
                    send(.backButtonTapped)
                },
                trailing: downloadItem
            )

            photoAndReactions
        }
    }

    private var photoAndReactions: some View {
        VStack(spacing: 0) {
            photoArea
                .padding(.top, Metric.photoTopPadding)
                .padding(.horizontal, Metric.photoHorizontalPadding)
                // 화면이 작아도 Spacer보다 사진 크기를 먼저 지켜 리액션 바가 잘리지 않게 한다.
                .layoutPriority(1)
                // 사진을 탭하면 키보드를 내린다.
                .onTapGesture { dismissKeyboard() }

            Spacer(minLength: Metric.reactionBarTopSpacing)

            reactionBar
        }
    }

    private var downloadItem: CHALLATopNavigation.Item? {
        guard store.isPrinted else { return nil }
        return .icon(.downloadSimple, accessibilityLabel: "사진 저장") {
            send(.downloadButtonTapped)
        }
    }

    private var isDrawerPresented: Binding<Bool> {
        Binding(
            get: { store.drawer != nil },
            set: { isPresented in
                guard !isPresented else { return }
                send(.drawerDismissed)
            }
        )
    }

    @ViewBuilder
    private var deleteReactionDrawer: some View {
        if case .deleteReaction = store.drawer {
            CHALLADrawer(
                header: .handle,
                actions: [
                    CHALLADrawerAction("삭제", variant: .neutral, role: .destructive) {
                        send(.deleteReactionConfirmed)
                    }
                ],
                footerAction: CHALLADrawerAction("닫기") { send(.drawerDismissed) }
            ) {
                CHALLADrawerMessage(
                    "이모지를 삭제할까요?",
                    description: "사진에서 이 이모지가 사라져요"
                )
            }
        }
    }

    /// 입력창·키보드와 겹치지 않도록 중앙에 표시한다.
    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            CHALLAToast(toast)
                .transition(.opacity)
                .allowsHitTesting(false)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    // MARK: - 사진 영역

    private var photoArea: some View {
        VStack(spacing: Metric.indicatorTopSpacing) {
            if store.photos.isEmpty {
                emptyCard
            } else {
                pager
                PhotoPageIndicator(count: store.photos.count, currentIndex: currentIndex)
            }
        }
    }

    private var pager: some View {
        // 사진은 남는 공간에 맞춰 축소되(작은 기기에서 리액션 바가 잘리지 않게), 세로 공간이 바뀌어도
        // 리사이즈되지 않도록 콘텐츠 전체가 키보드를 무시한다(body에서 `.ignoresSafeArea(.keyboard)`).
        GeometryReader { proxy in
            TabView(selection: selection) {
                ForEach(store.photos) { photo in
                    PhotoCard(
                        photo: photo,
                        isBlurred: !store.isPrinted,
                        onStickerTap: { send(.stickerTapped(reactionID: $0)) }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // 페이지 TabView는 VoiceOver에 사진을 넘길 방법을 주지 않는다.
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: Text("다음 사진")) { send(.adjacentPhotoRequested(offset: 1)) }
            .accessibilityAction(named: Text("이전 사진")) { send(.adjacentPhotoRequested(offset: -1)) }
        }
        .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
        // 애니메이션 좌표를 사진 카드 영역에 맞춘다.
        .overlay {
            if let burst = store.reactionBurst {
                ReactionBurstView(kind: burst.kind)
                    .id(burst.id)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.xxlarge))
    }

    /// 사진이 없을 때의 빈 자리. 로딩 중이면 스피너, 끝났으면 안내 문구를 얹는다.
    private var emptyCard: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.xxlarge)
            .strokeBorder(CHALLAColor.Line.normal, lineWidth: Metric.cardBorderWidth)
            .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
            .overlay {
                if store.isLoading {
                    ProgressView().tint(CHALLAColor.Label.neutral)
                } else {
                    // TODO: 시안에 빈 상태 표현이 없어 임의 문구다 — 빈 상태 시안이 나오면 교체한다.
                    Text("아직 인화된 사진이 없어요")
                        .challaFont(.body.medium.medium)
                        .foregroundStyle(CHALLAColor.Label.neutral)
                        .multilineTextAlignment(.center)
                }
            }
    }

    /// 저장 중 화면을 덮는 오버레이. 다운로드가 몇 초 걸리므로 진행 중임을 표시한다.
    private var savingOverlay: some View {
        ZStack {
            CHALLAColor.Material.dimmer.ignoresSafeArea()
            ProgressView().tint(CHALLAColor.Static.white)
        }
        .accessibilityElement()
        .accessibilityLabel("사진 저장 중")
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - 하단

    @ViewBuilder
    private var reactionBar: some View {
        if let photo = store.selectedPhoto {
            ReactionBar(selectedKinds: selectedKinds(of: photo)) { kind in
                send(.reactionTapped(kind))
            }
        }
    }

    /// 이 사진에 채팅 메시지를 보내는 입력창. 채팅 상세와 동일한 DS 컴포넌트를 쓰고 placeholder만 다르다.
    private var messageField: some View {
        CHALLAMessageInputBar(
            text: Binding(get: { store.messageDraft }, set: { send(.messageChanged($0)) }),
            placeholder: "이 사진에 메시지를 보내 보세요."
        ) {
            send(.sendMessageTapped)
        }
    }

    /// 화면 하단의 배경 그라데이션.
    private var glow: some View {
        Ellipse()
            .fill(theme.accent.opacity(Metric.glowOpacity))
            .frame(height: Metric.glowHeight)
            .blur(radius: Metric.glowBlurRadius)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: - 상태 읽기

    /// TabView가 요구하는 양방향 바인딩. 읽기는 상태에서, 쓰기는 액션으로 보낸다.
    private var selection: Binding<Photo.ID?> {
        Binding(
            get: { store.selectedPhotoID },
            set: { send(.photoSelected($0)) }
        )
    }

    private var currentIndex: Int {
        store.selectedPhotoID.flatMap { store.photos.index(id: $0) } ?? 0
    }

    private func selectedKinds(of photo: Photo) -> Set<ReactionKind> {
        // 스티커는 첫 이모지 하나지만, 칩 띠는 내가 이 사진에 누른 종류 전부에 켜진다(서버 재조회 시에도 복원).
        photo.reactedKinds(by: store.currentUserID)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let photoTopPadding: CGFloat = 32
    static let photoHorizontalPadding: CGFloat = 16
    static let indicatorTopSpacing: CGFloat = 16
    static let reactionBarTopSpacing: CGFloat = 35
    static let messageFieldTopSpacing: CGFloat = 16
    static let messageFieldHorizontalPadding: CGFloat = 20
    static let messageFieldBottomSpacing: CGFloat = 12
    static let cardBorderWidth: CGFloat = 1
    static let toastFadeDuration: Double = 0.2
    /// 배경 그라데이션 390 × 244, 투명도 20%.
    static let glowHeight: CGFloat = 244
    static let glowOpacity: Double = 0.2
    static let glowBlurRadius: CGFloat = 150
}

#Preview {
    PhotoDetailView(
        store: Store(
            initialState: PhotoDetailFeature.State(
                roomID: -1,
                roomTitle: "해피하우스 강릉 여행",
                currentUserID: "user-1",
                isPrinted: true
            )
        ) {
            PhotoDetailFeature()
        } withDependencies: {
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in
                (1 ... 5).compactMap { index in
                    guard let imageURL = URL(string: "https://picsum.photos/seed/challa\(index)/600/800") else {
                        return nil
                    }
                    return Photo(
                        id: "photo-\(index)",
                        imageURL: imageURL,
                        author: PhotoAuthor(id: "user-2", nickname: "나는야멋쟁이토마토"),
                        capturedAt: Date(timeIntervalSince1970: 1_784_000_040)
                    )
                }
            })
            $0.fetchPhotoReactionsUseCase = .previewValue
        }
    )
}
