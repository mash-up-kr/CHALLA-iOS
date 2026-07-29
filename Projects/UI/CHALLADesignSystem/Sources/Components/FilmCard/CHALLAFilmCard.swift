import SwiftUI

/// 디자인 시스템 필름 낱장 카드.
/// 방의 사진 한 장(또는 빈 슬롯)을 필름 비율(3:4)로 보여준다.
/// Figma Type 4종 — 촬영 전(빈 슬롯) / 인화대기(blur) / 인화완료(선명) / 더보기(+N).
///
/// 사진은 이미 로드된 `Image`를 받는다 — URL 로딩은 호출부 책임이라
/// 이 컴포넌트는 네트워크의 존재를 모른다.
///
/// ```swift
/// CHALLAFilmCard(variant: .printed(photo: photo), slotNumber: 2, width: 82)  // 홈 카드: 폭 고정
/// CHALLAFilmCard(variant: .beforeCapture, slotNumber: 5)                     // 그리드: 부모 폭 따라감
/// ```
public struct CHALLAFilmCard: View {

    /// 낱장 상태 (Figma Type 속성).
    public enum Variant {
        /// 촬영 전 — 사진이 없는 빈 슬롯. dashed 테두리만 그린다.
        case beforeCapture
        /// 인화대기 — 사진이 있지만 아직 인화 중. blur로 가린다.
        case printing(photo: Image)
        /// 인화완료 — 사진을 선명하게 보여준다.
        case printed(photo: Image)
        /// 더보기 — 다 못 보여준 장수를 blur 사진 위에 "+N"으로 겹친다.
        case more(photo: Image, count: Int)
    }

    /// 가로:세로 필름 비율. 세로를 직접 받지 않고 항상 가로 ÷ 이 값으로 계산해
    /// 어떤 폭에서도 필름 모양이 깨지지 않게 한다. (Figma 실측 82 × 109.33 = 3:4)
    public static let aspectRatio: CGFloat = 3.0 / 4.0

    private let variant: Variant
    private let slotNumber: Int?
    private let width: CGFloat?

    /// - Parameters:
    ///   - variant: 낱장 상태 (Figma Type).
    ///   - slotNumber: 필름 순번. nil이면 숨긴다 (Figma '필름 숫자 순서' = false).
    ///     더보기 낱장은 Figma 스펙상 순번 없이 +N만 그린다.
    ///   - width: 가로 폭. nil이면 부모가 제안하는 폭을 그대로 채운다 (그리드용).
    ///     홈 카드처럼 크기가 시안에 고정된 곳에서만 값을 넘긴다.
    public init(variant: Variant, slotNumber: Int? = nil, width: CGFloat? = nil) {
        self.variant = variant
        self.slotNumber = slotNumber
        self.width = width
    }

    public var body: some View {
        if let width {
            card.frame(width: width, height: width / Self.aspectRatio)
        } else {
            card.aspectRatio(Self.aspectRatio, contentMode: .fit)
        }
    }

    private var card: some View {
        photoLayer
            .clipShape(RoundedRectangle(cornerRadius: CHALLARadius.medium))
            .overlay(alignment: .bottomLeading) { numberLabel }
            .overlay { moreLabel }
            .overlay { border }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - 레이어

    @ViewBuilder
    private var photoLayer: some View {
        switch variant {
        case .beforeCapture:
            Color.clear
        case .printed(let photo):
            fillPhoto(photo, blurred: false)
        case .printing(let photo), .more(let photo, _):
            fillPhoto(photo, blurred: true)
        }
    }

    /// 사진을 낱장 크기에 꽉 채운다.
    /// scaledToFill은 짧은 변을 맞추느라 긴 변이 카드 밖으로 넘치므로,
    /// Color.clear가 카드 크기를 잡고 사진은 overlay로 얹어 넘친 만큼 잘라낸다.
    /// blur는 잘라내기 전에 걸어야 가장자리가 투명하게 번지지 않는다.
    private func fillPhoto(_ photo: Image, blurred: Bool) -> some View {
        Color.clear
            .overlay {
                photo
                    .resizable()
                    .scaledToFill()
                    .blur(radius: blurred ? FilmCardMetric.photoBlurRadius : 0)
            }
            .clipped()
            .overlay {
                if blurred {
                    CHALLAColor.Static.white.opacity(FilmCardMetric.veilOpacity)
                }
            }
    }

    /// 필름 순번 (왼쪽 아래). 촬영 전엔 빈 슬롯이라 어두운 색을 쓴다.
    @ViewBuilder
    private var numberLabel: some View {
        if let slotNumber, !isMore {
            Text("\(slotNumber)")
                .challaFont(.body.large.bold)
                .foregroundStyle(isBeforeCapture ? CHALLAColor.Label.disabled : CHALLAColor.Label.subtle)
                .padding(FilmCardMetric.numberPadding)
        }
    }

    /// 더보기의 "+N" (중앙).
    @ViewBuilder
    private var moreLabel: some View {
        if case .more(_, let count) = variant {
            Text("+\(count)")
                .challaFont(.body.medium.medium)
                .foregroundStyle(CHALLAColor.Static.white)
                .shadow(
                    color: CHALLAColor.Static.black.opacity(FilmCardMetric.moreShadowOpacity),
                    radius: FilmCardMetric.moreShadowRadius
                )
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: CHALLARadius.medium)
            .strokeBorder(
                isBeforeCapture ? CHALLAColor.Line.normal : CHALLAColor.Line.neutral,
                style: StrokeStyle(
                    lineWidth: FilmCardMetric.borderWidth,
                    dash: isBeforeCapture ? FilmCardMetric.dashPattern : []
                )
            )
    }

    // MARK: - 상태 판별

    private var isBeforeCapture: Bool {
        if case .beforeCapture = variant { return true }
        return false
    }

    private var isMore: Bool {
        if case .more = variant { return true }
        return false
    }

    private var accessibilityDescription: String {
        let order = slotNumber.map { "\($0)번 " } ?? ""
        return switch variant {
        case .beforeCapture: "\(order)촬영 전 필름"
        case .printing: "\(order)인화 대기 중 필름"
        case .printed: "\(order)인화 완료 필름"
        case .more(_, let count): "사진 \(count)장 더 있음"
        }
    }
}

// MARK: - Figma 실측값

private enum FilmCardMetric {
    /// 순번 글자의 왼쪽·아래 여백 (Figma 실측 9 / 9.33 → 9로 통일).
    static let numberPadding: CGFloat = 9
    /// 인화대기·더보기 사진의 blur 강도.
    /// Figma backdrop-blur 27px — SwiftUI blur와 수치 체계가 달라 시각 근사값. 디자이너 검수로 확정한다.
    static let photoBlurRadius: CGFloat = 13.5
    /// blur 위에 얹는 흰색 막 (Figma rgba(255,255,255,0.05)).
    static let veilOpacity: Double = 0.05
    /// "+N" 글자 그림자 (Figma text-shadow 0 0 8 / 25%).
    static let moreShadowOpacity: Double = 0.25
    static let moreShadowRadius: CGFloat = 4
    static let borderWidth: CGFloat = 1
    /// 촬영 전 dashed 패턴. Figma에 수치가 없어 시안 육안 근사값 — 디자이너 검수로 확정한다.
    static let dashPattern: [CGFloat] = [4, 4]
}

#Preview {
    let sampleURL = URL(string: "https://picsum.photos/seed/challa/300/400")

    HStack(spacing: 24) {
        CHALLAFilmCard(variant: .beforeCapture, slotNumber: 1)
        AsyncImage(url: sampleURL) { photo in
            CHALLAFilmCard(variant: .printing(photo: photo), slotNumber: 2)
        } placeholder: {
            ProgressView()
        }
        AsyncImage(url: sampleURL) { photo in
            CHALLAFilmCard(variant: .printed(photo: photo), slotNumber: 3)
        } placeholder: {
            ProgressView()
        }
        AsyncImage(url: sampleURL) { photo in
            CHALLAFilmCard(variant: .more(photo: photo, count: 21))
        } placeholder: {
            ProgressView()
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CHALLAColor.Background.surface)
}
