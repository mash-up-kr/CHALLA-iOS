import CHALLAImageKit
import Foundation
import PhotoDomain
import SwiftUI

/// 필름 한 칸이 들고 있는 사진.
///
/// 칸마다 따로 두는 이유: 한 장이 도착할 때마다 필름 전체를 다시 그리면 칸 72개와
/// 천공 구멍 900여 개가 통째로 재구성돼 받는 속도까지 끌어내린다.
/// 칸이 자기 사진만 지켜보면 도착한 그 칸만 다시 그린다.
@MainActor
@Observable
final class PrintNoticePhotoSlot {

    var image: Image?
}

/// 인화 완료 안내의 필름에 실을 사진을 미리 받아 들고 있는 곳.
///
/// 칸이 그려질 때 사진을 받기 시작하면, 빠르게 지나가는 칸은 도착 전에 화면을 벗어나 검은 채로 지나간다.
/// (`CHALLAAsyncImage`는 칸마다 크기 측정 → 비동기 로드 → 0.25초 페이드인을 거친다.)
/// 그래서 화면과 별개로 미리 받아 두고, 칸은 여기서 꺼내 그 자리에서 그린다.
///
/// 전부 받을 때까지 기다리지는 않는다. 받는 속도가 필름이 지나가는 속도보다 빠르면
/// 남은 장은 필름이 그 칸에 닿기 전에 도착한다. 그 관계가 성립할 때 당기기를 연다(``canPull``).
@MainActor
@Observable
final class PrintNoticePhotoStore {

    /// 사진별 칸. 받기 시작할 때 한 번 만들고, 이후에는 각 칸 안의 사진만 바뀐다.
    private(set) var slots: [Photo.ID: PrintNoticePhotoSlot] = [:]

    /// 당겨도 되는지. 값이 바뀔 때만 갱신한다 — 장마다 다시 쓰면 필름 전체가 매번 다시 그려진다.
    private(set) var canPull = false

    /// 받기로 한 장수. 남은 장을 세는 기준이다.
    private var total = 0
    /// 지금까지 받은 장수. 실패한 장은 세지 않는다.
    private var loadedCount = 0
    /// 필름에 실릴 순서. 앞에서부터 얼마나 채워졌는지 세는 데 쓴다.
    private var order: [Photo.ID] = []
    /// 받은 사진의 자리. 도착 순서가 뒤섞여도 앞에서부터 센다.
    private var loadedIDs: Set<Photo.ID> = []
    /// 맨 앞에서부터 끊기지 않고 이어서 받은 장수.
    private var leadingReady = 0
    /// 받기 시작한 시각. 남은 시간을 어림잡는 데 쓴다.
    private var startedAt: Date?

    /// 당기기를 열 시점을 정하는 규칙. 필름 길이에 따라 기준이 달라져 받을 때 만든다.
    private var gate = PrintNoticePullGate(
        minReadyFrames: Const.minReadyFrames,
        safetyWindow: PrintNoticeMetric.maxRunDuration
    )

    /// 나올 순서대로 미리 받는다. 한 번에 몇 장씩만 받아 요청이 몰리지 않게 한다.
    ///
    /// `photos`가 곧 나오는 순서다 — 먼저 찍은 사진이 먼저 슬롯을 빠져나온다.
    /// 그래서 앞에서부터 받으면 필름이 훑는 순서와 도착 순서가 같아진다.
    func warm(_ photos: [Photo], loader: ImageLoader?, scale: CGFloat) async {
        guard let loader else { return }

        total = photos.count
        loadedCount = 0
        order = photos.map(\.id)
        loadedIDs = []
        leadingReady = 0
        startedAt = .now
        gate = PrintNoticePullGate(
            minReadyFrames: Const.minReadyFrames,
            safetyWindow: PrintNoticeMetric.runDuration(frameCount: photos.count)
        )
        // 칸은 처음에 한 번에 만든다. 도착할 때마다 이 딕셔너리를 건드리면 필름 전체가 다시 그려진다.
        slots = Dictionary(
            photos.map { ($0.id, PrintNoticePhotoSlot()) },
            uniquingKeysWith: { first, _ in first }
        )
        refreshCanPull()

        // 홈이 미리 받아 둘 때와 같은 값을 봐야 캐시가 맞는다 (`PrintNoticeFilmMetric`).
        let pointSize = PrintNoticeFilmMetric.photoPointSize

        await withTaskGroup(of: LoadedPhoto.self) { group in
            var started = 0

            for photo in photos {
                if started >= Const.concurrency, let loaded = await group.next() {
                    store(loaded)
                }
                let id = photo.id
                let url = photo.previewURL
                group.addTask {
                    await LoadedPhoto(
                        id: id,
                        uiImage: try? loader.image(from: url, pointSize: pointSize, scale: scale)
                    )
                }
                started += 1
            }

            for await loaded in group {
                store(loaded)
            }
        }
    }

    /// 들고 있던 사진을 놓는다. 안내가 끝나면 부른다.
    ///
    /// 놓지 않으면 로더의 메모리 캐시가 같은 이미지를 비우려 해도 여기서 붙들고 있어 해제되지 않는다.
    /// 방 하나가 72장이면 70MB쯤 된다.
    func clear() {
        slots.removeAll()
        canPull = false
        total = 0
        loadedCount = 0
        order = []
        loadedIDs = []
        leadingReady = 0
        startedAt = nil
    }

    /// 받은 사진을 제 칸에 넣는다. 딕셔너리가 아니라 칸 안의 값만 바뀐다.
    private func store(_ loaded: LoadedPhoto) {
        guard let uiImage = loaded.uiImage else { return }
        slots[loaded.id]?.image = Image(uiImage: uiImage)
        loadedCount += 1
        loadedIDs.insert(loaded.id)
        // 앞에서부터 이어진 자리까지만 센다. 중간이 비면 거기서 멈춘다.
        while leadingReady < order.count, loadedIDs.contains(order[leadingReady]) {
            leadingReady += 1
        }
        refreshCanPull()
    }

    /// 한 번 열리면 다시 닫지 않는다 — 당기던 중에 잠기면 손가락을 따라오던 필름이 멈춘다.
    private func refreshCanPull() {
        guard !canPull, isPullable else { return }
        canPull = true
    }

    /// 지금 당기게 해도 필름이 사진을 앞지르지 않는지. 판단은 ``PrintNoticePullGate``가 한다.
    private var isPullable: Bool {
        guard let startedAt else { return false }
        return gate.isOpen(
            total: total,
            leadingReady: leadingReady,
            loaded: loadedCount,
            elapsed: Date.now.timeIntervalSince(startedAt)
        )
    }

    private enum Const {
        /// 한 번에 받는 장수. 늘리면 빨리 채워지지만 요청이 몰려 첫 칸이 늦어진다.
        static let concurrency = 3
        /// 열기 전에 반드시 채워 둘 앞 칸 수 — 멈춰 있는 동안 보이는 칸(1.3칸)에 여유를 더한 값.
        static let minReadyFrames = 4
    }
}

/// 미리 받기 한 건의 결과.
private struct LoadedPhoto: Sendable {
    let id: Photo.ID
    let uiImage: UIImage?
}
