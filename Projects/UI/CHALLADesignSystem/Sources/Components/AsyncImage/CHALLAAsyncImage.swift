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
    @State private var measuredSize: CGSize = .zero

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
            measuredSize = newSize // 배치된 크기가 확정·변경되면 기록 → LoadInput 변경 → 재로드
        }
        .task(id: LoadInput(url: url, size: measuredSize, scale: displayScale)) {
            await load() // 입력이 바뀌면 이전 로드를 취소하고 다시 로드. 뷰 소멸 시 자동 취소.
        }
    }

    // MARK: - 로드

    /// 로드의 입력값 묶음. 하나라도 바뀌면 `.task(id:)`가 이전 작업을 취소하고 다시 로드한다.
    private struct LoadInput: Equatable {
        let url: URL?
        let size: CGSize
        let scale: CGFloat
    }

    private func load() async {
        // 레이아웃 전(크기 0)이거나 url·로더가 없으면 로드하지 않는다 — placeholder 유지.
        guard let url, let loader,
              measuredSize.width > 0, measuredSize.height > 0
        else { return }

        do {
            let uiImage = try await loader.image(
                from: url,
                pointSize: measuredSize,
                scale: displayScale
            )
            // 취소된 요청이 여기까지 결과를 들고 올 수 있다(로더의 메모리 히트는 취소 확인 없이 반환).
            // 그대로 쓰면 재사용된 셀의 현재 요청 화면을 낡은 이미지로 덮어쓴다 — 여기서 차단.
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: AsyncImageMetric.fadeInDuration)) {
                phase = .success(Image(uiImage: uiImage))
            }
        } catch ImageLoadingError.cancelled {
            // 취소된 요청의 결과. 상태에 쓰면 재사용된 셀의 현재 요청을 덮어쓰므로 버린다.
        } catch is CancellationError {
            // 로더의 번역을 거치지 않은 원시 취소가 새어 나온 경우의 안전망 — 같은 이유로 버린다.
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
