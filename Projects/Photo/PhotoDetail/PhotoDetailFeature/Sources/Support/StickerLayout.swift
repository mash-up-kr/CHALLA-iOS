import Foundation
import PhotoDomain

/// 리액션 스티커의 자리를 관리한다.
/// 유저당 하나, 사진에 최대 3명분, 사진마다 정해진 세트(A·B)에 놓는다. 자리는 State에 저장해 떼도 안 바뀐다.
public enum StickerLayout {

    /// 한 사진에 붙는 스티커 최대 개수 = 먼저 남긴 유저 3명분 (정책 #71).
    static let maxCount = 3

    /// 저장된 자리(slot)로 스티커 위치를 만든다. 자리 없는 리액션은 그리지 않는다.
    public static func placements(
        for photo: Photo,
        slots: [String: Int]
    ) -> [(reaction: PhotoReaction, placement: StickerPlacement)] {
        let positions = anchorSet(for: photo.id)
        return photo.reactions.compactMap { reaction in
            slots[slotKey(photo.id, reaction.id)].map { (reaction, positions[$0]) }
        }
    }

    /// 유저별 스티커에 자리를 배정한다. 기존 자리는 유지, 새 유저에 빈 자리, 없어진 유저는 반납.
    /// 먼저 남긴 3명까지만 자리를 받고, 그 뒤 유저는 스티커가 안 붙는다(이모지 자체는 서버·채팅에 남는다).
    static func assignSlots(for photos: some Sequence<Photo>, previous: [String: Int]) -> [String: Int] {
        var result: [String: Int] = [:]

        for photo in photos {
            // 처음 남긴 순서를 유지한다 — 먼저 남긴 3명이 자리를 차지한다.
            let keys = photo.reactions.map { slotKey(photo.id, $0.id) }
            var used = Set<Int>()

            // 이미 배정된 자리는 유지한다.
            for key in keys {
                if let slot = previous[key] {
                    result[key] = slot
                    used.insert(slot)
                }
            }
            // 자리가 없는 유저에 빈 자리를 준다. 자리가 다 차면(3개) 건너뛴다.
            for key in keys where result[key] == nil {
                guard let slot = (0 ..< maxCount).first(where: { !used.contains($0) }) else { continue }
                result[key] = slot
                used.insert(slot)
            }
        }
        return result
    }

    private static func slotKey(_ photoID: String, _ reactionID: String) -> String {
        "\(photoID)|\(reactionID)"
    }

    /// 사진마다 세트를 고정으로 고른다. hashValue는 실행마다 바뀌어서 id 바이트 합의 짝/홀로 정한다.
    private static func anchorSet(for photoID: String) -> [StickerPlacement] {
        stableHash(photoID).isMultiple(of: 2) ? Positions.caseA : Positions.caseB
    }

    private static func stableHash(_ text: String) -> Int {
        text.utf8.reduce(0) { $0 + Int($1) }
    }
}

// MARK: - 스티커 자리 (사진 크기 대비 비율 0~1)

private enum Positions {
    /// 좌측 상단 · 우측 중앙 · 좌측 하단
    static let caseA = [
        StickerPlacement(xRatio: 0.24, yRatio: 0.24, angleDegrees: -10),
        StickerPlacement(xRatio: 0.80, yRatio: 0.50, angleDegrees: 8),
        StickerPlacement(xRatio: 0.26, yRatio: 0.80, angleDegrees: -8)
    ]
    /// 우측 상단 · 좌측 중앙 · 우측 하단
    static let caseB = [
        StickerPlacement(xRatio: 0.80, yRatio: 0.24, angleDegrees: 10),
        StickerPlacement(xRatio: 0.24, yRatio: 0.50, angleDegrees: -8),
        StickerPlacement(xRatio: 0.78, yRatio: 0.80, angleDegrees: 8)
    ]
}
