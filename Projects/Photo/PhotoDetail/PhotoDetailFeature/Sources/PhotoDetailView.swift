import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import SwiftUI

/// 사진 상세 화면
@ViewAction(for: PhotoDetailFeature.self)
public struct PhotoDetailView: View {

    @Environment(\.challaTheme) private var theme

    @Bindable public var store: StoreOf<PhotoDetailFeature>

    public init(store: StoreOf<PhotoDetailFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            CHALLAColor.Background.surface.ignoresSafeArea()
            glow.ignoresSafeArea()
            content

            if store.isSaving {
                savingOverlay
            }
        }
        // 탑 내비게이션을 직접 그리므로 시스템 바는 숨긴다.
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
                },
                trailing: .icon(.downloadSimple, accessibilityLabel: "사진 저장") {
                    send(.downloadButtonTapped)
                }
            )

            photoArea
                .padding(.top, Metric.photoTopPadding)
                .padding(.horizontal, Metric.photoHorizontalPadding)
                // 리액션을 남기면 이모지가 사진 위로 쏟아진다. id가 바뀔 때마다 처음부터 다시 튄다.
                .overlay {
                    if let burst = store.reactionBurst {
                        ReactionBurstView(kind: burst.kind)
                            .id(burst.id)
                    }
                }
                // 화면이 작아도 Spacer보다 사진 크기를 먼저 지킨다.
                .layoutPriority(1)

            Spacer(minLength: Metric.reactionBarTopSpacing)

            reactionBar

            messageField
                .padding(.top, Metric.messageFieldTopSpacing)
                .padding(.horizontal, Metric.messageFieldHorizontalPadding)
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
        // GeometryReader로 페이지 크기를 확정해 각 PhotoCard에 명시적 frame으로 준다.
        // 페이지 TabView(.page)는 처음 보이는 페이지에 크기 측정 콜백을 늦게 태워,
        // CHALLAAsyncImage가 크기를 못 재 첫 진입에 빈 화면이 되던 문제를 막는다.
        GeometryReader { proxy in
            TabView(selection: selection) {
                ForEach(store.photos) { photo in
                    PhotoCard(photo: photo, slots: store.stickerSlots, isBlurred: !store.isPrinted)
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
            .padding(.horizontal, Metric.reactionBarHorizontalPadding)
        }
    }

    /// 채팅 입력창 자리(아직 동작 안 함). .disabled는 글자색을 바꾸므로 탭만 막고, VoiceOver에서도 숨긴다.
    private var messageField: some View {
        CHALLATextField(
            text: .constant(""),
            placeholder: "이 사진에 메시지를 보내 보세요.",
            textAlignment: .leading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
}

// MARK: - Figma 실측값

private enum Metric {
    static let photoTopPadding: CGFloat = 32
    static let photoHorizontalPadding: CGFloat = 16
    static let indicatorTopSpacing: CGFloat = 16
    static let reactionBarTopSpacing: CGFloat = 35
    static let messageFieldTopSpacing: CGFloat = 16
    static let messageFieldHorizontalPadding: CGFloat = 20
    static let reactionBarHorizontalPadding: CGFloat = 24
    static let cardBorderWidth: CGFloat = 1
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
                currentUserID: "user-1"
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
