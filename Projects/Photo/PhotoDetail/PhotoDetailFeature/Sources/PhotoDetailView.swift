import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import SwiftUI

/// 사진 상세 화면
@ViewAction(for: PhotoDetailFeature.self)
public struct PhotoDetailView: View {

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
                .padding(.horizontal, 16)
                // 화면이 작아도 Spacer보다 사진 크기를 먼저 지킨다.
                .layoutPriority(1)

            Spacer(minLength: Metric.reactionBarTopSpacing)

            reactionBar

            messageField
                .padding(.top, Metric.messageFieldTopSpacing)
                .padding(.horizontal, 20)
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
        // TabView는 주어진 공간을 모두 채우므로, 비율만 지정한 빈 뷰로 크기를 고정한다.
        Color.clear
            .aspectRatio(PhotoCard.aspectRatio, contentMode: .fit)
            .overlay {
                TabView(selection: selection) {
                    ForEach(store.photos) { photo in
                        PhotoCard(photo: photo, slots: store.stickerSlots)
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

    /// 사진이 없을 때의 빈 자리. 로딩 중이면 스피너, 끝났으면 안내 문구를 얹는다.
    private var emptyCard: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.xxlarge)
            .strokeBorder(CHALLAColor.Line.normal, lineWidth: 1)
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
            .padding(.horizontal, 24)
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
    static let photoTopPadding: CGFloat = 32
    static let indicatorTopSpacing: CGFloat = 16
    static let reactionBarTopSpacing: CGFloat = 35
    static let messageFieldTopSpacing: CGFloat = 16
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
        }
    )
}
