import CHALLAImageKit
import SwiftUI

/// 원격 이미지를 표시하는 DS 비동기 이미지 뷰. 내부적으로 `ImageLoader`(다운샘플+2단 캐시)를 쓴다.
///
/// 뷰가 배치된 크기(pt)와 화면 배율을 스스로 측정해 로더에 넘기므로 호출부는 URL만 주면 된다.
/// 모든 화면은 시스템 `AsyncImage` 대신 이 뷰를 쓴다.
public struct CHALLAAsyncImage<Content: View, Placeholder: View>: View {

    // MARK: - 프로퍼티와 init

    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @Environment(\.challaImageLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var phase: CHALLAAsyncImagePhase = .empty
    /// 배치된 크기를 정수 pt로 올려 기록한다 (`ImageLoadSize.quantized`).
    @State private var measuredSize: CGSize = .zero
    /// 화면에 실린 이미지의 크기. 이보다 커질 때만 다시 받는다.
    @State private var loadedSize: CGSize?

    /// - Parameters:
    ///   - url: 원격 이미지 URL. nil이면 placeholder만 표시한다.
    ///   - content: 성공 시 이미지를 어떻게 표시할지.
    ///   - placeholder: 로딩 중·실패 시 표시할 뷰.
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            if let image = phase.image {
                content(image)
                    .transition(.opacity) // 성공 전환 시 불투명도 교차(페이드인)
            } else {
                placeholder()
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            measuredSize = ImageLoadSize.quantized(newSize)
        }
        // 크기는 id에 넣지 않는다 — 넣으면 배치가 다시 잡힐 때마다 로드를 새로 걸어,
        // 칸이 많은 화면에서는 한 장당 여러 번 호출되며 로더가 밀린다.
        .task(id: LoadInput(url: url, isMeasured: isMeasured, scale: displayScale)) {
            await load()
        }
        // 이미 실린 것보다 커졌을 때만 다시 받는다.
        .task(id: grownSize) {
            if grownSize != nil {
                await load()
            }
        }
    }

    /// 배치 크기가 정해졌는지. 레이아웃 전에는 0이라 로드할 수 없다.
    private var isMeasured: Bool {
        measuredSize.width > 0 && measuredSize.height > 0
    }

    /// 이미 실린 이미지보다 커진 크기. 커지지 않았으면 nil이라 재로드가 걸리지 않는다.
    private var grownSize: CGSize? {
        guard let loadedSize,
              ImageLoadSize.needsReload(loaded: loadedSize, requested: measuredSize)
        else { return nil }
        return measuredSize
    }

    // MARK: - 로드

    /// 로드의 입력값 묶음. 하나라도 바뀌면 `.task(id:)`가 이전 작업을 취소하고 다시 로드한다.
    private struct LoadInput: Equatable {
        let url: URL?
        let isMeasured: Bool
        let scale: CGFloat
    }

    private func load() async {
        let size = measuredSize

        // 레이아웃 전(크기 0)이거나 url·로더가 없으면 로드하지 않는다 — placeholder 유지.
        guard let url, let loader,
              size.width > 0, size.height > 0
        else { return }

        do {
            let uiImage = try await loader.image(
                from: url,
                pointSize: size,
                scale: displayScale
            )
            loadedSize = size
            withAnimation(.easeInOut(duration: AsyncImageMetric.fadeInDuration)) {
                phase = .success(Image(uiImage: uiImage))
            }
        } catch ImageLoadingError.cancelled {
            // 스크롤로 셀이 재사용되면 url이 바뀌고, .task(id:)가 이전 url의 로드를 취소한 뒤
            // 새 url로 다시 시작한다. 이 블록에 오는 건 그렇게 취소된 이전 로드의 결과다.
            //
            // phase를 갱신하지 않는다 — 이 뷰는 이미 새 url을 로드하고 있어서,
            // 여기서 이전 결과를 쓰면 새 이미지가 도착할 때까지 지난 사진이 보이게 된다.
        } catch is CancellationError {
            // 로더가 취소를 .cancelled로 바꾸므로 지금은 도달하지 않는다.
            // 빼면 나중에 취소가 아래 catch로 흘러 로드 실패로 기록된다.
        } catch {
            // 취소가 아닌 실제 실패(HTTP 오류·재시도 소진·손상 이미지 등)만 기록한다.
            // 실패 시 표시는 placeholder 유지 — 별도 실패 UI를 두지 않는 것이 #25 결정.
            phase = .failure(error)
        }
    }
}

// MARK: - 기본형

public extension CHALLAAsyncImage where Content == Image, Placeholder == Color {

    /// 기본형 — 로딩 중·실패 시 DS 배경색 박스, 성공 시 resizable 이미지를 페이드인.
    /// 표시 방식(fill/fit)과 크기는 호출부의 `.frame`·`.aspectRatio`가 정한다.
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { CHALLAColor.Background.level2 }
        )
    }
}

// MARK: - Figma 실측값

private enum AsyncImageMetric {
    /// 성공 전환 페이드인 길이. 시안 육안 근사값 — 디자이너 검수로 확정한다.
    static let fadeInDuration: TimeInterval = 0.25
}
