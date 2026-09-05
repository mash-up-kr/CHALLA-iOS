import CHALLADesignSystem
import ComposableArchitecture
import PhotoDomain
import RoomDomain
import SwiftUI

/// 방 상세 화면. 슬롯 그리드가 본문이고, 참여자 바가 그 위에 겹쳐 뜬다.
///
/// 화면이 갈리는 기준이 두 가지로 나뉜다.
/// - 그리드는 사진 개수를 본다 — 찍힌 자리는 사진, 남은 자리는 빈 칸.
///   사진은 인화 완료면 선명하게, 그 전이면 블러로 그린다.
/// - 하단은 방 상태를 본다 — 촬영 중은 사진 찍기, 인화 대기는 카운트다운,
///   인화 완료는 채팅 버튼 하나가 가운데.
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
                leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") { send(.backButtonTapped) },
                trailing: .icon(.setting, accessibilityLabel: "방 설정") { send(.settingsButtonTapped) }
            )
            slotGrid
                .overlay(alignment: .top) { memberBar }
                // 참여자 바보다 나중에 선언해 열린 팝오버 위에 그려지게 한다.
                .overlay(alignment: .top) { toastLayer }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .challaMainBackground()
        .overlay(alignment: .bottom) { bottomActions }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(isPresented: $store.isSharePresented) {
            if let url = store.inviteShareURL {
                ActivityShareSheet(items: [url])
                    .presentationDetents([.medium, .large]) // 시안의 반 시트 — 위로 끌면 전체
            }
        }
        .task { send(.task) }
        // 자동으로 열린 안내는 사용자가 손댄 곳이 없어 VoiceOver가 모른다 — 열릴 때 직접 알린다.
        .onChange(of: store.isInviteGuidePresented) { _, isPresented in
            guard isPresented else { return }
            AccessibilityNotification.Announcement(Self.inviteGuideMessage).post()
        }
    }

    /// 첫 진입 안내 문구 — 툴팁과 VoiceOver 알림이 같은 문장을 쓴다.
    private static let inviteGuideMessage = "초대 코드로 친구를 초대해보세요"

    // MARK: - 슬롯 그리드 (사진 개수 기준)

    /// 총 촬영 장수만큼 슬롯을 깐다. 슬롯 크기는 FilmCard가 비율로 정하므로 열만 나눈다.
    private var slotGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.columns, spacing: RoomDetailMetric.slotSpacing) {
                ForEach(1 ... max(store.room.totalPhotoCount, 1), id: \.self) { number in
                    slot(number: number)
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

    /// 슬롯 한 칸 — 사진이 있으면 사진, 없으면 빈 칸.
    /// 촬영 중에 찍은 사진도 블러로 보이고, 인화가 끝나야 선명해진다.
    /// 사진 조회가 실패하면 아직 안 찍힌 자리와 같은 모습이 된다.
    @ViewBuilder
    private func slot(number: Int) -> some View {
        if number <= store.photos.count {
            let photo = store.photos[number - 1]
            Button {
                send(.photoTapped(photo.id))
            } label: {
                CHALLAAsyncImage(url: photo.imageURL) { image in
                    CHALLAFilmCard(
                        variant: store.room.status == .printed
                            ? .printed(photo: image)
                            : .printing(photo: image),
                        slotNumber: number
                    )
                } placeholder: {
                    loadingSlot
                }
            }
            .buttonStyle(.plain)
        } else {
            CHALLAFilmCard(variant: .beforeCapture, slotNumber: number)
        }
    }

    /// 사진을 받아오는 동안의 자리. 점선(촬영 전)을 쓰지 않는 이유는 찍힌 자리인데
    /// 안 찍힌 것처럼 보이기 때문이다 — 카드 크기는 FilmCard와 같은 비율로 맞춘다.
    private var loadingSlot: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.medium)
            .fill(CHALLAColor.Background.level2)
            .aspectRatio(CHALLAFilmCard.aspectRatio, contentMode: .fit)
    }

    // MARK: - 참여자 바

    /// 상세가 조회되기 전에는 그리지 않는다 — 참여자를 모른 채 빈 캡슐만 뜨는 것을 막는다.
    /// 조회에 실패하면 얼럿이 다시 시도를 받는다.
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
                // 문구는 뷰 소유 — 리듀서는 띄울지(Bool)만 안다.
                popoverTooltip: store.isInviteGuidePresented ? Self.inviteGuideMessage : nil,
                onShareInviteCode: { send(.shareInviteCodeTapped) }
            )
        }
    }

    // MARK: - 토스트

    /// 인화 대기 안내. 표시 시간은 리듀서의 타이머가 정하고, 여기는 문구가 있는 동안만 그린다.
    @ViewBuilder
    private var toastLayer: some View {
        if let toast = store.toast {
            CHALLAToast(toast)
                .padding(.top, RoomDetailMetric.toastTopPadding)
        }
    }

    // MARK: - 하단 동작 (방 상태 기준)

    /// 촬영 중: 채팅 + 사진 찍기 / 인화 대기: 채팅 + 카운트다운 /
    /// 인화 완료: 채팅 버튼 하나가 가운데 (시안 7539:91265).
    @ViewBuilder
    private var bottomActions: some View {
        switch store.room.status {
        case .shooting:
            actionBar {
                chatButton
                CHALLATextButton(
                    "사진 찍기",
                    variant: .theme,
                    size: .large,
                    isFullWidth: true,
                    // 목록·필터·권한을 받는 동안 로딩으로 바꾼다 — 그동안 화면은 그대로 남는다.
                    isLoading: store.isPreparingShoot,
                    leadingIcon: .camera
                ) {
                    send(.shootButtonTapped)
                }
            }
        case .printWaiting:
            actionBar {
                chatButton
                if let completedAt = store.room.photoPrintCompletedAt {
                    countdownBar(until: completedAt)
                } else {
                    Spacer() // 완료 예정 시각이 없으면(파싱 실패) 바 없이 채팅만 남긴다
                }
            }
        case .printed:
            actionBar {
                Spacer(minLength: 0)
                chatButton
                Spacer(minLength: 0)
            }
        }
    }

    /// 하단 동작 줄의 공통 틀 — 내용물 배치와 배경 그라데이션만 담당한다.
    /// 그라데이션은 위 여백(8)부터 홈 인디케이터 영역까지 투명 → 검정으로 깔린다 (시안 7486:80245).
    private func actionBar(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: RoomDetailMetric.actionSpacing) {
            content()
        }
        .padding(.horizontal, RoomDetailMetric.horizontalPadding)
        .padding(.top, RoomDetailMetric.actionTopPadding)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [.clear, CHALLAColor.Static.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// 채팅 진입 버튼. 세 상태가 같은 버튼을 쓰고 자리만 다르다.
    private var chatButton: some View {
        CHALLAIconButton(
            .chatTeardropDots,
            accessibilityLabel: "채팅",
            variant: .primary,
            size: .large
        ) {
            send(.chatButtonTapped)
        }
    }

    /// 인화 완료까지 남은 시간. 초마다 다시 그린다 — 남은 값은 State에 두지 않고
    /// 완료 예정 시각(photoPrintCompletedAt)에서 그때그때 계산한다.
    private func countdownBar(until completedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(PrintCountdown.text(until: completedAt, now: context.date)) 후 인화 완료")
                .challaFont(.body.large.bold)
                // 비활성 버튼 팔레트(Label.disabled)와 다른 색이라 버튼 재사용 대신 직접 그린다.
                .foregroundStyle(CHALLAColor.Label.alternative)
        }
        .frame(maxWidth: .infinity, minHeight: RoomDetailMetric.countdownBarHeight)
        .background {
            RoundedRectangle(cornerRadius: CHALLARadius.large)
                .fill(CHALLAColor.Background.level2)
        }
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
    /// 카운트다운 바 높이 — 하단 버튼(.large 54)과 나란히 놓여 같은 높이를 쓴다.
    static let countdownBarHeight: CGFloat = 54
}

// MARK: - Preview

/// 프리뷰용 가짜 사진. picsum 사진 6장을 돌려 쓴다 — 슬롯마다 다른 URL을 주면
/// 수십 건이 한꺼번에 나가 picsum이 막고, 같은 URL은 로더가 캐시로 재사용해 6번만 받는다.
private func previewPhotos(count: Int) -> [Photo] {
    (0 ..< count).compactMap { index in
        guard let url = URL(string: "https://picsum.photos/seed/challa-slot\(index % 6)/300/400") else { return nil }
        return Photo(
            id: "\(index)",
            imageURL: url,
            author: PhotoAuthor(id: "author", nickname: "찰나둥이"),
            capturedAt: .now
        )
    }
}

#Preview("촬영 중") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = .previewValue
        }
    )
}

#Preview("촬영 중 (12장 찍힘)") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = .previewValue
            // 24칸 중 12장 찍힌 상태 — 찍은 자리는 블러, 남은 자리는 빈 칸으로 섞여 보인다.
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in previewPhotos(count: 12) })
        }
    )
}

#Preview("조회 실패 (다시 불러오기)") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in throw RoomError.network })
        }
    )
}

#Preview("인화 대기 (카운트다운)") {
    // 고정 픽스처(previewPrintWaiting)는 완료 시각이 과거라 0:00:00만 보인다 — 시안 값으로 직접 만든다.
    // 타입을 명시해 둔다 — 리터럴 곱셈을 인자 자리에 그대로 두면 타입 추론이 제한 시간을 넘긴다.
    let secondsUntilExpiry: TimeInterval = 60 * 60 * 24 * 30 //      30일
    let secondsUntilPrinted: TimeInterval = 2 * 3600 + 59 * 60 + 58 // 2:59:58
    let room = Room(
        id: -2,
        title: "성수동 필름 산책",
        status: .printWaiting,
        totalPhotoCount: 48,
        remainedPhotoCount: 0,
        createdAt: .now,
        expiresAt: .now.addingTimeInterval(secondsUntilExpiry),
        photoPrintCompletedAt: .now.addingTimeInterval(secondsUntilPrinted)
    )
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: room)) {
            RoomDetailFeature()
        } withDependencies: {
            // previewValue는 촬영 중인 방을 돌려줘서 진입 조회가 이 방을 덮어쓴다 — 같은 방을 돌려주게 한다.
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in
                RoomDetail(room: room, invitationCode: "1928121", members: RoomDetail.preview.members)
            })
            // 인화 대기는 다 찍었을 때만 들어오는 상태라 빈 슬롯이 없다 (남은 장수 0).
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in
                previewPhotos(count: room.totalPhotoCount)
            })
        }
    )
}

#Preview("첫 진입 (팝오버 + 툴팁)") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewShooting)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = .previewValue
            $0.shouldShowInviteGuideUseCase.run = { true }
        }
    )
}

#Preview("인화 완료 (채팅 버튼 가운데)") {
    RoomDetailView(
        store: Store(initialState: RoomDetailFeature.State(room: .previewPrinted)) {
            RoomDetailFeature()
        } withDependencies: {
            $0.fetchRoomDetailUseCase = FetchRoomDetailUseCase(run: { _ in
                RoomDetail(room: .previewPrinted, invitationCode: "1928121", members: RoomDetail.preview.members)
            })
            $0.fetchRoomPhotosUseCase = FetchRoomPhotosUseCase(run: { _ in
                previewPhotos(count: Room.previewPrinted.totalPhotoCount)
            })
        }
    )
}
