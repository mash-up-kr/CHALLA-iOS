import CHALLADesignSystem
import ComposableArchitecture
import RoomDomain
import SwiftUI

/// 홈 화면. 카드는 디자인 시스템이 그리고 이 뷰는 배치와 탭 전달만 맡는다.
/// 사진은 URL을 `RemoteImages`로 감싸 로드된 `Image`로 바꿔 넘긴다.
@ViewAction(for: HomeFeature.self)
public struct HomeView: View {

    // MARK: - 프로퍼티와 init

    @Bindable public var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            navigationBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .challaMainBackground()
        .overlay { plusMenuLayer }
        .challaDrawer(isPresented: createRoomBinding, allowsInteractiveDismiss: false) { createRoomDrawer }
        .challaDrawer(isPresented: joinRoomBinding, allowsInteractiveDismiss: false) { joinRoomDrawer }
        .task { await send(.task).finish() }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }

    // MARK: - 드로어

    // challaDrawer는 Bool만 받아서 Destination이 이 케이스인지 직접 확인한다.
    // 둘 다 입력 드로어라 딤 탭·끌어내리기를 막고 X 버튼으로만 닫는다.

    private var createRoomBinding: Binding<Bool> {
        Binding(
            get: { store.destination?.createRoom != nil },
            set: { if !$0 { send(.drawerDismissed) } }
        )
    }

    @ViewBuilder
    private var createRoomDrawer: some View {
        if let childStore = store.scope(
            state: \.destination?.createRoom,
            action: \.destination.createRoom
        ) {
            CreateRoomDrawer(store: childStore)
        }
    }

    private var joinRoomBinding: Binding<Bool> {
        Binding(
            get: { store.destination?.joinRoom != nil },
            set: { if !$0 { send(.drawerDismissed) } }
        )
    }

    @ViewBuilder
    private var joinRoomDrawer: some View {
        if let childStore = store.scope(
            state: \.destination?.joinRoom,
            action: \.destination.joinRoom
        ) {
            JoinRoomDrawer(store: childStore)
        }
    }

    // MARK: - 상단 바

    private var navigationBar: some View {
        CHALLATopNavigation.main(trailing: [
            .icon(.plus, accessibilityLabel: "방 추가") { send(.plusButtonTapped) },
            .icon(.setting, accessibilityLabel: "설정") { send(.settingsButtonTapped) }
        ])
    }

    // MARK: - + 메뉴

    /// 메뉴가 떠 있는 동안 화면 전체를 덮어 바깥 탭을 받는다 (시안 주석: 그 외 영역 탭 시 닫힘).
    @ViewBuilder
    private var plusMenuLayer: some View {
        if store.isPlusMenuPresented {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { send(.plusMenuDismissed) }
                PlusMenu(
                    onCreateRoom: { send(.createRoomButtonTapped) },
                    onJoinRoom: { send(.joinRoomButtonTapped) }
                )
                .padding(.top, HomeMetric.menuTopSpacing)
                .padding(.trailing, HomeMetric.menuTrailingSpacing)
            }
        }
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        if store.showsLoading {
            ProgressView()
                .tint(CHALLAColor.Label.neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = store.errorMessage {
            errorView(message)
        } else if store.showsEmptyState {
            HomeEmptyView(
                nickname: store.nickname,
                profileImageURL: store.profileImageURL,
                onCreateRoom: { send(.createRoomButtonTapped) },
                onJoinRoom: { send(.joinRoomButtonTapped) }
            )
        } else {
            roomList
        }
    }

    /// 첫 조회 실패 화면. 얼럿을 닫아도 다시 시도할 수단이 남아 있어야 한다.
    /// TODO: 문구·레이아웃 임의 작성본 — 시안에 조회 실패 화면 정의가 없다.
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HomeMetric.errorSpacing) {
            Text(message)
                .challaFont(.body.medium.medium)
                .foregroundStyle(CHALLAColor.Label.neutral)
                .multilineTextAlignment(.center)
            CHALLATextButton("다시 시도") { send(.retryButtonTapped) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, HomeMetric.horizontalPadding)
    }

    private var roomList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HomeMetric.sectionSpacing) {
                if !store.board.shooting.isEmpty {
                    section("촬영 중") {
                        shootingCards
                    }
                }
                if !store.board.shooting.isEmpty, !store.board.completed.isEmpty {
                    Rectangle()
                        .fill(CHALLAColor.Line.normal)
                        .frame(height: HomeMetric.dividerHeight)
                }
                if !store.board.completed.isEmpty {
                    section("촬영 완료") {
                        completedCards
                    }
                }
            }
            .padding(.horizontal, HomeMetric.horizontalPadding)
            .padding(.vertical, HomeMetric.listVerticalPadding)
        }
    }

    // MARK: - 섹션

    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: HomeMetric.labelCardSpacing) {
            Text(title)
                .challaFont(.body.small.bold)
                .foregroundStyle(CHALLAColor.Label.neutral)
            content()
        }
    }

    /// 촬영 중 — 카드가 고정 폭(200)이라 가로로 넘긴다.
    private var shootingCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HomeMetric.cardSpacing) {
                ForEach(store.board.shooting) { room in
                    Button {
                        send(.roomTapped(room.id))
                    } label: {
                        RemoteImages(urls: [room.coverImageURL].compactMap(\.self)) { images in
                            CHALLACardItem(
                                title: room.name,
                                memberCount: room.memberCount,
                                photoCount: room.photoCount,
                                photo: images.first
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // 가로 스크롤이 화면 가장자리까지 닿도록 좌우 패딩을 상쇄했다가 안쪽에서 되돌린다.
        .padding(.horizontal, -HomeMetric.horizontalPadding)
        .contentMargins(.horizontal, HomeMetric.horizontalPadding, for: .scrollContent)
    }

    /// 촬영 완료 — 카드가 가로 폭을 채워 세로로 쌓는다.
    private var completedCards: some View {
        VStack(spacing: HomeMetric.cardSpacing) {
            ForEach(store.board.completed) { room in
                Button {
                    send(.roomTapped(room.id))
                } label: {
                    RemoteImages(urls: room.thumbnailURLs) { images in
                        CHALLAPrintCard(
                            status: room.status == .printed ? .printed : .printing,
                            title: room.name,
                            memberCount: room.memberCount,
                            photos: images,
                            totalPhotoCount: room.photoCount
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Figma 실측값

private enum HomeMetric {
    /// 좌우 가장자리 여백.
    static let horizontalPadding: CGFloat = 16
    /// 목록 위아래 여백.
    static let listVerticalPadding: CGFloat = 12
    /// 섹션 라벨과 첫 카드 사이.
    static let labelCardSpacing: CGFloat = 20
    /// 섹션·구분선 사이 간격 (카드 하단 → 구분선 32, 구분선 → 다음 라벨 32).
    static let sectionSpacing: CGFloat = 32
    /// 섹션 사이 구분선 두께.
    static let dividerHeight: CGFloat = 1
    /// 실패 문구와 다시 시도 버튼 사이. 시안이 없어 임의값.
    static let errorSpacing: CGFloat = 16
    /// 같은 섹션 안의 카드 사이 (완료 카드 블록 200 → 다음 블록 y=224).
    static let cardSpacing: CGFloat = 24
    /// + 메뉴 상단 간격 — 상단 바 위 여백 15 + 터치 영역 40 (메뉴가 + 버튼 바로 아래 붙는다).
    static let menuTopSpacing: CGFloat = 55
    /// + 메뉴 우측 간격 — 메뉴 오른쪽 끝이 + 버튼 오른쪽과 정렬 (Figma x=154, 390−154−180).
    static let menuTrailingSpacing: CGFloat = 56
}

// MARK: - Preview

/// 사진이 들어간 프리뷰용 방들.
///
/// Domain의 `Room.previewXxx`는 URL이 비어 있다 — 프리뷰가 네트워크 없이 즉시 떠야 해서다.
/// 사진이 있어야 확인되는 것(낱장 스택·`+N` 오버레이·인화 대기 blur)을 보려고 여기에 따로 둔다.
/// `RoomData`의 `RoomSamples`와 같은 시드를 쓰지만, Feature는 Data를 import하지 않아 값을 복제한다.
private enum PreviewRooms {

    static let all: [Room] = [shooting, printWaiting, printed]

    private static let shooting = Room(
        id: "preview-shooting",
        name: "친구들과 강릉 여행",
        status: .shooting,
        memberCount: 11,
        photoCount: 24,
        shotCount: .twentyFour,
        coverImageURL: photoURL(seed: "gangneung-cover", size: 400),
        thumbnailURLs: []
    )

    private static let printWaiting = Room(
        id: "preview-print-waiting",
        name: "성수동 필름 산책",
        status: .printWaiting,
        memberCount: 6,
        photoCount: 48,
        shotCount: .fortyEight,
        coverImageURL: nil,
        thumbnailURLs: thumbnailURLs(prefix: "seongsu")
    )

    private static let printed = Room(
        id: "preview-printed",
        name: "인화 완료 된 방이에요",
        status: .printed,
        memberCount: 11,
        photoCount: 72,
        shotCount: .seventyTwo,
        coverImageURL: nil,
        thumbnailURLs: thumbnailURLs(prefix: "first-meeting")
    )

    private static func photoURL(seed: String, size: Int) -> URL? {
        URL(string: "https://picsum.photos/seed/\(seed)/\(size)")
    }

    private static func thumbnailURLs(prefix: String) -> [URL] {
        (1 ... 4).compactMap { photoURL(seed: "\(prefix)-\($0)", size: 200) }
    }
}

/// 프리뷰는 조회 결과만 다르다 — 나머지 조립은 같아 한곳에 둔다.
private func previewStore(_ fetchRooms: FetchRoomsUseCase) -> StoreOf<HomeFeature> {
    Store(initialState: HomeFeature.State(nickname: "나는야멋쟁이토마토")) {
        HomeFeature()
    } withDependencies: {
        $0.fetchRoomsUseCase = fetchRooms
    }
}

#Preview("목록 (사진)") {
    HomeView(store: previewStore(FetchRoomsUseCase(run: { PreviewRooms.all })))
}

#Preview("목록 (사진 없음)") {
    HomeView(store: previewStore(.previewValue))
}

#Preview("빈 상태") {
    HomeView(store: previewStore(FetchRoomsUseCase(run: { [] })))
}

#Preview("조회 실패") {
    HomeView(store: previewStore(FetchRoomsUseCase(run: { throw RoomError.network })))
}

#Preview("로딩") {
    HomeView(store: previewStore(FetchRoomsUseCase(run: {
        try await Task.sleep(for: .seconds(600))
        return []
    })))
}
