import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import SwiftUI

/// 사진 상세 화면. 하단 입력창은 아직 모양만 있다 — 채팅은 후속 이슈다.
@ViewAction(for: PhotoDetailFeature.self)
public struct PhotoDetailView: View {

    // MARK: - 프로퍼티와 init

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
                // 사진과 Spacer가 둘 다 유연해서, 작은 화면에서 사진이 먼저 줄지 않도록 우선권을 준다.
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
        // TabView는 제안된 공간을 다 채우므로, 비율만 잡은 빈 뷰가 크기를 정해준다.
        Color.clear
            .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
            .overlay {
                TabView(selection: selection) {
                    ForEach(store.photos) { photo in
                        PhotoCard(photo: photo)
                            .tag(Optional(photo.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // 페이지 TabView는 VoiceOver에 사진을 넘길 방법을 주지 않는다.
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text("다음 사진")) { send(.adjacentPhotoRequested(offset: 1)) }
                .accessibilityAction(named: Text("이전 사진")) { send(.adjacentPhotoRequested(offset: -1)) }
            }
    }

    /// 사진이 없을 때의 빈 자리. 카드 모양만 남긴다.
    private var emptyCard: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.xxlarge)
            .strokeBorder(CHALLAColor.Line.normal, lineWidth: Metric.cardBorderWidth)
            .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
            .overlay {
                if store.isLoading {
                    ProgressView().tint(CHALLAColor.Label.neutral)
                }
            }
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

    /// 채팅 입력창 자리. `.disabled(true)`는 글자색까지 비활성 색으로 바꿔 시안과 달라지므로 탭만 막고,
    /// VoiceOver에는 반응 없는 입력창이 잡히지 않게 숨긴다.
    private var messageField: some View {
        CHALLATextField(
            text: .constant(""),
            placeholder: "이 사진에 메시지를 보내 보세요.",
            textAlignment: .leading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 화면 아래를 물들이는 테마색 번짐 (시안의 배경 타원).
    private var glow: some View {
        Ellipse()
            .fill(CHALLAColor.defaultTheme.opacity(Metric.glowOpacity))
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
        Set(photo.reactions.filter { $0.userID == store.currentUserID }.map(\.kind))
    }
}

// MARK: - Figma 실측값

private enum Metric {
    /// 탑 내비 아래 ~ 사진 카드 (146 − 114).
    static let photoTopPadding: CGFloat = 32
    static let photoHorizontalPadding: CGFloat = 16
    static let cardBorderWidth: CGFloat = 1
    /// 사진 아래 ~ 점 표시 (493 − 477).
    static let indicatorTopSpacing: CGFloat = 16
    /// 사진 카드 아래 ~ 리액션 바 (684 − 649).
    static let reactionBarTopSpacing: CGFloat = 35
    static let reactionBarHorizontalPadding: CGFloat = 24
    /// 리액션 바 아래 ~ 입력창 (758 − 742).
    static let messageFieldTopSpacing: CGFloat = 16
    static let messageFieldHorizontalPadding: CGFloat = 20
    /// 배경 타원 390 × 244, 노랑 20%.
    static let glowHeight: CGFloat = 244
    static let glowOpacity: Double = 0.2
    /// Figma gaussian 300 — SwiftUI blur와 수치 체계가 달라 시각 근사값.
    static let glowBlurRadius: CGFloat = 150
}

#Preview {
    PhotoDetailView(
        store: Store(
            initialState: PhotoDetailFeature.State(
                roomID: "room-1",
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
        }
    )
}
