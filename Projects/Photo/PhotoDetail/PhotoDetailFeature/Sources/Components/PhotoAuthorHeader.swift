import CHALLADesignSystem
import Foundation
import PhotoDomain
import SwiftUI

/// 사진 상단의 촬영자 표시. 아바타·닉네임·촬영 시각.
struct PhotoAuthorHeader: View {

    // MARK: - 프로퍼티

    let author: PhotoAuthor
    let capturedAt: Date

    // MARK: - Body

    var body: some View {
        VStack(spacing: Metric.rowSpacing) {
            HStack(spacing: Metric.avatarSpacing) {
                // DS의 캐시 이미지 뷰. 캐러셀을 넘길 때 같은 아바타를 다시 받지 않는다.
                CHALLAAsyncImage(url: author.avatarURL) { image in
                    CHALLAAvatar(photo: image, size: Metric.avatarSize)
                } placeholder: {
                    CHALLAAvatar(photo: nil, size: Metric.avatarSize)
                }

                Text(author.nickname)
                    .challaFont(.body.medium.medium)
                    .foregroundStyle(CHALLAColor.Label.normal)
                    .lineLimit(1)
            }

            Text(Self.formatted(capturedAt))
                .challaFont(.body.small.medium)
                .foregroundStyle(CHALLAColor.defaultTheme)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 표기 규칙

    /// 시안 표기 "2026. 7.16. 14:34" — 월·일에 0을 채우지 않고 24시간제로 쓴다.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy. M.d. HH:mm"
        return formatter
    }()

    /// 사진 카드의 VoiceOver 문장도 같은 표기를 쓴다.
    static func formatted(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

// MARK: - Figma 실측값

private enum Metric {
    static let avatarSize: CGFloat = 22
    static let avatarSpacing: CGFloat = 8
    /// 시안 간격 6에서 두 글자 상자의 여백(2 + 1.5)을 뺀 값.
    static let rowSpacing: CGFloat = 6
        - CHALLATypography.body.medium.medium.lineBoxInset
        - CHALLATypography.body.small.medium.lineBoxInset
}
