import CHALLADesignSystem
import CHALLAImageKit
import PhotoDomain
import SwiftUI

/// 인화 완료 안내 — 인화가 끝난 방에 처음 들어왔을 때 한 번만 뜬다.
///
/// 필름 출구에서 아래로 당기면 사진이 지나가며 화면 밖으로 내려가고, 끝나면 `onFinished`를 부른다.
/// 노출 기록과 화면 전환은 리듀서가 맡는다.
///
/// 사진이 필름을 앞서 도착할 만큼 빨리 들어올 때부터 당길 수 있다 (`PrintNoticePhotoStore.canPull`).
/// 전부 기다리지는 않는다 — 한 칸이 화면에 머무는 시간이 0.06초라, 받는 속도가 그보다 빠르면
/// 남은 장은 필름이 닿기 전에 도착한다. 회선이 느려 끝내 따라오지 못하면 안내를 접는다.
///
/// 그때까지 필름은 출구 안에 있다. 미리 내놓으면 사진이 실리기 전의 칸이 검은 채로 걸려 있다 —
/// 준비되면 그제서야 나오게 해서 빈 칸이 보일 자리를 없앤다.
///
/// `ScrollView`를 쓰지 않는다. 스크롤은 손을 뗀 시점을 알려주지 않기 때문이다 —
/// 스크롤이 제스처를 가져가면 `onEnded`가 오지 않고, iOS 17에는 이를 관찰하는 API가 없다.
/// "잡으면 멈추고 놓으면 이어서 내려간다"가 이 화면의 핵심이라 직접 다룬다.
struct PrintNoticeView: View {

    /// 필름에 실을 사진. 찍힌 순서대로 받는다.
    let photos: [Photo]
    /// 필름이 화면 밖으로 다 내려갔을 때 불린다.
    let onFinished: () -> Void
    /// 사진을 제때 받지 못해 안내를 접을 때 불린다. 본 것이 아니므로 기록과 이어지지 않는다.
    let onSkipped: () -> Void

    @Environment(\.challaTheme) private var theme
    /// 사진을 미리 받는 데 쓴다 — `CHALLAAsyncImage`가 쓰는 것과 같은 로더다.
    @Environment(\.challaImageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale

    /// 슬롯 밖으로 나온 필름 길이. 이 값 하나가 필름과 툴팁 위치를 함께 정한다.
    /// 사진이 준비될 때까지는 0 — 필름이 출구 안에 있어 아무것도 보이지 않는다.
    @State private var pulled: CGFloat = 0
    /// 당길 곳을 알리는 움직임.
    @State private var hint = PrintNoticeHint()
    /// 미리 받아 둔 사진.
    @State private var photoStore = PrintNoticePhotoStore()

    /// 나머지가 알아서 내려가는 중.
    @State private var isRunning = false
    /// 한 번이라도 내려가기 시작했는지. 중간에 잡아도 툴팁이 다시 나타나지 않게 한다.
    @State private var didStartRun = false
    /// 내려가는 중인 움직임. 중간에 잡았을 때 지금 자리를 계산하는 데 쓴다.
    @State private var runInFlight: RunInFlight?
    /// 실행 번호. 잡았다 놓으면 앞선 움직임의 완료 통보를 무시하는 데 쓴다.
    @State private var runID = 0
    /// 끌기 시작한 자리. 잡은 자리에서 이어 끌려고 기억한다.
    @State private var dragBase: CGFloat?
    /// 손이 닿았는지. 툴팁을 거둔다.
    @State private var didTouch = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // 필름보다 먼저 그린다 — 필름이 슬롯에서 나와 출구 아래쪽 테두리를 덮고 내려간다.
                bezel
                    .padding(.top, PrintNoticeMetric.bezelTopPadding)
                film
                tooltip
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // 필름 폭이 좁아서, 옆의 빈 곳을 당겨도 반응하게 한다.
            .contentShape(Rectangle())
            // 준비 전에는 제스처 자체를 받지 않는다 — 안에서 걸러내면 손가락을 따라 필름이 움직인다.
            .gesture(pullGesture(containerHeight: proxy.size.height), including: canPull ? .all : .subviews)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("인화된 필름")
            .accessibilityHint(canPull ? "아래로 당기면 인화된 사진이 나옵니다" : "사진을 불러오는 중입니다")
            // 보이스오버는 당길 수 없으므로 같은 일을 하는 동작을 따로 준다.
            .accessibilityAction(named: "필름 당기기") {
                guard canPull else { return }
                run(containerHeight: proxy.size.height)
            }
        }
        // 사진이 준비되면 필름을 내보내고, 다 나온 뒤에 당길 곳을 알린다.
        .onChange(of: canPull, initial: true) {
            guard canPull else { return }
            withAnimation(.easeOut(duration: Const.revealDuration)) {
                pulled = PrintNoticeMetric.initialReveal
            }
            hint.start(delay: Const.revealDuration + Const.hintDelay)
        }
        // 준비 전에는 당길 수 없으므로, 끝내 못 받으면 화면이 멈춘 채로 남는다. 그래서 기한을 둔다.
        .task {
            try? await Task.sleep(for: .seconds(Const.loadBudget))
            guard !canPull else { return }
            onSkipped()
        }
        .task { await photoStore.warm(photos, loader: imageLoader, scale: displayScale) }
        // 붙들고 있으면 로더 캐시가 이 사진들을 비우지 못한다.
        .onDisappear { photoStore.clear() }
    }

    // MARK: - 필름 출구

    /// 필름이 나오는 구멍. 테마 색 테두리 안에 어두운 슬롯이 하나 있다.
    private var bezel: some View {
        RoundedRectangle(cornerRadius: PrintNoticeMetric.bezelHeight / 2)
            .fill(CHALLAColor.Static.black)
            .frame(width: PrintNoticeMetric.bezelWidth, height: PrintNoticeMetric.bezelHeight)
            .overlay {
                RoundedRectangle(cornerRadius: PrintNoticeMetric.slotHeight / 2)
                    .fill(CHALLAColor.Background.level4)
                    .frame(width: PrintNoticeMetric.slotWidth, height: PrintNoticeMetric.slotHeight)
            }
            .overlay {
                // 시안 테두리는 바깥쪽이다. stroke는 선 중앙에 그리므로 절반만큼 넓힌다.
                RoundedRectangle(
                    cornerRadius: PrintNoticeMetric.bezelHeight / 2 + PrintNoticeMetric.bezelBorderWidth / 2
                )
                .stroke(theme.accent, lineWidth: PrintNoticeMetric.bezelBorderWidth)
                .padding(-PrintNoticeMetric.bezelBorderWidth / 2)
            }
            .shadow(
                color: CHALLAColor.Static.black.opacity(PrintNoticeMetric.bezelShadowOpacity),
                radius: PrintNoticeMetric.bezelShadowRadius,
                y: PrintNoticeMetric.bezelShadowOffsetY
            )
    }

    // MARK: - 필름

    /// 슬롯에서 나와 아래로 흐르는 필름.
    ///
    /// 크기가 아니라 `offset`으로 움직인다. 크기를 애니메이션하면 매 프레임 배치를 다시 잡아 끊긴다.
    /// 잘리는 창은 슬롯의 세로 중앙에 고정한다 — 필름이 출구 아랫변이 아니라 슬롯에서 나와야 한다.
    /// 잘린 결과를 통째로 옮기면 슬롯과 필름 사이가 벌어진다.
    /// 당길 곳을 알리는 튕김은 여기에 더하지 않는다 — 툴팁만 튕긴다.
    /// 필름까지 움직이면 출구에서 밀려 나왔다 들어가는 것처럼 보여 무겁다.
    private var film: some View {
        filmStrip
            .frame(width: PrintNoticeMetric.filmWidth, height: stripHeight)
            .offset(y: pulled - stripHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .padding(.top, PrintNoticeMetric.filmTopPadding)
    }

    private var filmStrip: some View {
        HStack(spacing: 0) {
            FilmPerforation(height: stripHeight)
            VStack(spacing: 0) {
                ForEach(frames) { photo in
                    FilmFrame(slot: photoStore.slots[photo.id])
                }
            }
            FilmPerforation(height: stripHeight)
        }
        .background(CHALLAColor.Static.black)
    }

    // MARK: - 툴팁

    /// 필름 끝을 가리키는 안내. 필름을 따라 내려오고, 당길 곳을 알리는 튕김은 이쪽만 받는다.
    /// 여백이 아니라 `offset`으로 옮긴다 — 여백은 보간 방식이 달라 움직이는 동안 필름과 어긋난다.
    private var tooltip: some View {
        CHALLATooltip(Const.message, position: .bottom, arrowAlignment: .center)
            .offset(y: pulled - PrintNoticeMetric.initialReveal + hint.offset)
            .padding(.top, PrintNoticeMetric.filmTopPadding
                + PrintNoticeMetric.initialReveal + PrintNoticeMetric.tooltipSpacing)
            .opacity(canPull && !didStartRun ? 1 : 0)
    }

    // MARK: - 당기기

    /// 당기는 동안 손가락을 그대로 따라온다.
    /// 내려가는 중에는 누르기만 해도 멈추고, 떼면 이어서 내려간다.
    /// 손을 뗐을 때 충분히 나와 있지 않으면 처음 자리로 되감긴다.
    private func pullGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: Const.minimumDragDistance)
            .onChanged { value in
                if dragBase == nil {
                    // 손이 닿은 순간. 내려가는 중이었으면 세우고 그 자리부터 끈다.
                    catchRunningFilm()
                    touched()
                    dragBase = pulled
                }
                guard let dragBase else { return }

                // 다 빠져나간 뒤로는 더 당겨도 빈 화면만 끌린다.
                pulled = min(
                    runEnd(containerHeight: containerHeight),
                    max(0, dragBase + value.translation.height)
                )
            }
            .onEnded { _ in
                dragBase = nil

                // 이동량이 아니라 나온 길이로 판단한다. 잡았다 놓은 경우도 같은 규칙이다.
                if pulled >= PrintNoticeMetric.initialReveal + Const.pullThreshold {
                    run(containerHeight: containerHeight)
                } else {
                    withAnimation(.spring(duration: Const.releaseDuration, bounce: Const.releaseBounce)) {
                        pulled = PrintNoticeMetric.initialReveal
                    }
                }
            }
    }

    /// 손이 닿았다 — 안내를 거둔다.
    private func touched() {
        hint.stop()
        guard !didTouch else { return }
        didTouch = true
    }

    /// 내려가던 필름을 지금 자리에 세운다.
    ///
    /// SwiftUI는 애니메이션 도중의 값을 알려주지 않는다. 일정한 속도로 내려가므로
    /// 지난 시간에 비례한 자리가 곧 지금 자리다.
    private func catchRunningFilm() {
        guard isRunning, let run = runInFlight else { return }

        let position = run.position(at: .now)

        isRunning = false
        runInFlight = nil

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pulled = position
        }
    }

    /// 여기까지 내려가면 필름이 화면에서 다 빠져나간다.
    private func runEnd(containerHeight: CGFloat) -> CGFloat {
        stripHeight + containerHeight
    }

    /// 필름을 화면 밖까지 내려보낸 뒤 끝났다고 알린다.
    private func run(containerHeight: CGFloat) {
        guard !isRunning else { return }
        hint.stop()

        // 남은 거리로 시간을 잡아 속도를 일정하게 한다. 너무 길거나 짧지 않게 자른다.
        let from = pulled
        let end = runEnd(containerHeight: containerHeight)
        let duration = min(
            max((end - from) / PrintNoticeMetric.runSpeed, PrintNoticeMetric.minRunDuration),
            PrintNoticeMetric.maxRunDuration
        )

        runID += 1
        let id = runID
        runInFlight = RunInFlight(startedAt: .now, from: from, to: end, duration: duration)

        withAnimation(.easeOut(duration: Const.tooltipFadeDuration)) {
            isRunning = true
            didStartRun = true
        }
        // 일정한 속도로 내려간다. 곡선이면 중간에 잡았을 때 자리를 역산해야 한다.
        withAnimation(.linear(duration: duration)) {
            pulled = end
        } completion: {
            // 중간에 잡아 멈춘 움직임도 완료 통보가 온다. 그때는 끝난 것이 아니다.
            guard isRunning, id == runID else { return }
            onFinished()
        }
    }

    // MARK: - 계산값

    /// 필름에 싣는 사진. 아래쪽 끝부터 빠져나오므로, 뒤집어야 먼저 찍은 사진이 먼저 보인다.
    private var frames: [Photo] {
        Array(photos.reversed())
    }

    private var stripHeight: CGFloat {
        CGFloat(frames.count) * PrintNoticeMetric.frameHeight
    }

    /// 당겨도 되는 상태인지. 스토어가 받는 속도를 보고 정한다.
    private var canPull: Bool {
        photoStore.canPull
    }

    // MARK: - 상수

    private enum Const {
        static let message = "필름을 아래로 당겨 보세요!"

        /// 0이면 손이 닿는 즉시 반응한다. 값을 주면 누르는 것만으로는 내려가는 필름을 못 세운다.
        static let minimumDragDistance: CGFloat = 0
        /// 손을 뗐을 때 이만큼 나와 있으면 나머지가 이어서 내려간다. 그보다 짧으면 되감긴다.
        static let pullThreshold: CGFloat = 72
        /// 문턱을 못 넘기고 놓았을 때 되감기는 움직임.
        static let releaseDuration: TimeInterval = 0.45
        static let releaseBounce: CGFloat = 0.45

        static let tooltipFadeDuration: TimeInterval = 0.2

        /// 사진이 준비된 뒤 필름이 출구 밖으로 나오는 시간.
        static let revealDuration: TimeInterval = 0.5
        /// 필름이 다 나온 뒤 당길 곳을 알리기까지 두는 사이.
        static let hintDelay: TimeInterval = 0.25
        /// 당길 수 있게 될 때까지 기다려 주는 시간. 넘기면 안내를 접는다.
        /// 지금은 목록 API가 원본(장당 4~4.5MB)을 주므로 큰 방은 이 기한을 넘긴다.
        static let loadBudget: TimeInterval = 20.0
    }
}

// MARK: - 진행 중인 내려가기

/// 내려가는 중인 움직임 한 번. 중간에 잡았을 때 지금 자리를 계산하는 데 쓴다.
struct RunInFlight: Equatable {

    let startedAt: Date
    let from: CGFloat
    let to: CGFloat
    let duration: TimeInterval

    /// `now` 시점에 필름이 있는 자리. 일정한 속도로 내려가므로 지난 시간에 비례한다.
    /// 시작 전이나 끝난 뒤를 물으면 양 끝값으로 자른다.
    func position(at now: Date) -> CGFloat {
        let progress = min(1, max(0, now.timeIntervalSince(startedAt) / duration))
        return from + (to - from) * progress
    }
}

// MARK: - Preview

#Preview("인화 완료 안내") {
    VStack(spacing: 0) {
        CHALLATopNavigation.sub(
            title: "친구들과 강릉 여행",
            leading: .icon(.caretLeft, accessibilityLabel: "뒤로 가기") {}
        )
        PrintNoticeView(photos: PreviewSamples.photos(count: 24), onFinished: {}, onSkipped: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .challaMainBackground()
}
