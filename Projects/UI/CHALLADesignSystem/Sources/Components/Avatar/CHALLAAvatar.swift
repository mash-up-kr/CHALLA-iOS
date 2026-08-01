import SwiftUI

/// 디자인 시스템 원형 아바타.
/// 프로필 바(30pt), 개별 상세 헤더·채팅 메시지(22pt), 멤버 팝오버 행(20pt)에서 재사용된다.
/// 사진이 없으면 회색 바탕에 person 아이콘을 놓은 기본 모습을 그린다.
///
/// ```swift
/// CHALLAAvatar(photo: memberPhoto, size: 30)
/// CHALLAAvatar(photo: nil, size: 20)   // 사진 없음 — 기본 모습
/// ```
public struct CHALLAAvatar: View {

    // MARK: - 프로퍼티와 init

    private let photo: Image?
    private let size: CGFloat

    /// - Parameters:
    ///   - photo: 프로필 사진. nil이면 기본 모습 (로딩 전·미설정 대응).
    ///   - size: 지름(pt). 쓰이는 화면마다 다르다 — 위 문서의 30/22/20이 현재 실측값.
    public init(photo: Image?, size: CGFloat) {
        self.photo = photo
        self.size = size
    }

    // MARK: - Body

    public var body: some View {
        CHALLAColor.Background.level2
            .overlay { content }
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var content: some View {
        if let photo {
            // 원 밖으로 넘친 부분은 body의 clipShape가 잘라낸다.
            photo
                .resizable()
                .scaledToFill()
        } else {
            // CHALLAIcon.image(size:)는 고정 크기 토큰만 받아서 에셋을 직접 그린다.
            Image(CHALLAIcon.person.rawValue, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: size * AvatarMetric.placeholderIconRatio)
                .foregroundStyle(CHALLAColor.Label.alternative)
        }
    }
}

// MARK: - Figma 실측값

private enum AvatarMetric {
    /// 사진 없을 때 person 아이콘이 지름에서 차지하는 비율 (시안 육안 근사값 — 디자이너 검수로 확정).
    static let placeholderIconRatio: CGFloat = 0.6
}

#Preview {
    HStack(spacing: 16) {
        AsyncImage(url: URL(string: "https://picsum.photos/seed/avatar/100")) { photo in
            CHALLAAvatar(photo: photo, size: 30)
        } placeholder: {
            ProgressView()
        }
        CHALLAAvatar(photo: nil, size: 30)
        CHALLAAvatar(photo: nil, size: 20)
    }
    .padding()
    .background(CHALLAColor.Background.surface)
}
