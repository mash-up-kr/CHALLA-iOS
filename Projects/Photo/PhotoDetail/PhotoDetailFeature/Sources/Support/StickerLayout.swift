import Foundation
import PhotoDomain

/// 사진 ID와 스티커 표시 ID로 위치를 계산한다.
public enum StickerLayout {

    public static func placements(
        for photo: Photo
    ) -> [(reaction: PhotoReaction, placement: StickerPlacement)] {
        photo.reactions.map { ($0, placement(photoID: photo.id, reaction: $0)) }
    }

    /// 자리를 정하는 키. 리액션 id는 쓰지 않는다 — 서버 응답 전에는 `local-…`,
    /// 다시 조회하면 `chat-…`이라 같은 스티커가 화면을 나갔다 오면 다른 자리로 옮겨간다.
    /// 유저·종류 조합은 그 사이에도 바뀌지 않고, 같은 종류 재탭을 막고 있어 사진 안에서 겹치지도 않는다.
    private static func layoutKey(_ reaction: PhotoReaction) -> String {
        "\(reaction.userID)|\(reaction.kind.rawValue)"
    }

    /// 좌표와 각도마다 구분 문자열을 붙여 계산한다.
    private static func placement(photoID: String, reaction: PhotoReaction) -> StickerPlacement {
        let key = "\(photoID)|\(layoutKey(reaction))"

        return StickerPlacement(
            xRatio: ratio(key, salt: "x", from: Metric.minX, to: Metric.maxX),
            yRatio: ratio(key, salt: "y", from: Metric.minY, to: Metric.maxY),
            angleDegrees: Double(stableHash(key + "angle") % 31) - 15
        )
    }

    private static func ratio(_ key: String, salt: String, from: Double, to: Double) -> Double {
        let steps = Int((to - from) * 100)
        return from + Double(stableHash(key + salt) % steps) / 100
    }

    private enum Metric {
        /// 스티커(82pt)가 카드 밖으로 잘리지 않는 가로 범위.
        static let minX = 0.20
        static let maxX = 0.80
        /// 위쪽은 촬영자 표시를 피해 더 내려 잡는다.
        static let minY = 0.28
        static let maxY = 0.80
    }

    /// 실행마다 값이 달라지는 Swift hashValue 대신 고정 해시를 사용한다.
    private static func stableHash(_ text: String) -> Int {
        text.utf8.reduce(0) { $0 &* 31 &+ Int($1) } & 0x00FF_FFFF
    }
}
