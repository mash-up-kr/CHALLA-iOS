import Foundation
import PhotoDomain

/// 사진에 달린 리액션을 스티커 자리에 배정한다.
///
/// 도메인이 아니라 화면 쪽에 둔다 — 격자도 비워 두는 구간도 전부 시안 레이아웃에서 나온 값이고,
/// 서버는 좌표를 주지 않는다. 서버가 좌표를 주기 시작하면 이 계산 대신 그 값을 쓴다.
public enum StickerLayout {

    /// 리액션마다 슬롯을 하나씩 나눠 줘 서로 겹치지 않게 한다.
    ///
    /// 자리를 리액션이 각자 정하면 서로를 몰라 같은 지점에 포개진다 — 실제로 그렇게 만들었다가
    /// 종류 두 개가 6pt 차이로 겹쳤다. 그래서 사진에 달린 목록 전체를 한 번에 본다.
    /// 슬롯보다 리액션이 많아지면 그때부터는 앞 슬롯에 다시 쌓인다.
    public static func placements(for photo: Photo) -> [(reaction: PhotoReaction, placement: StickerPlacement)] {
        var taken = Set<Int>()

        // id로 정렬해 배정 순서를 고정한다 — 서버가 리액션 목록 순서를 바꿔 줘도 스티커가 자리를 옮기지 않는다.
        return photo.reactions.sorted { $0.id < $1.id }.map { reaction in
            let seed = "\(photo.id)|\(reaction.id)"
            var slot = preferredSlot(seed: seed)

            // 찜한 자리가 이미 찼으면 빈 자리를 만날 때까지 옆으로 민다.
            for _ in 0 ..< Grid.slotCount where taken.contains(slot) {
                slot = (slot + 1) % Grid.slotCount
            }
            taken.insert(slot)

            return (reaction, placement(inSlot: slot, seed: seed))
        }
    }

    /// 사진을 나눈 슬롯 수. 스티커가 이 개수까지는 서로 겹치지 않는다.
    public static var slotCount: Int {
        Grid.slotCount
    }

    /// 해시가 고른 시작 슬롯.
    private static func preferredSlot(seed: String) -> Int {
        Int(fnv1a(seed) % UInt64(Grid.slotCount))
    }

    /// 슬롯 하나 안에서의 자리. 슬롯끼리 떨어져 있으므로 스티커도 겹치지 않는다.
    ///
    /// 무작위로 흩뿌리되 같은 입력이면 늘 같은 자리여야 화면을 다시 그릴 때 스티커가 옮겨 다니지 않는다.
    /// 실행할 때마다 시드가 바뀌는 `hashValue` 대신 값이 고정된 FNV-1a를 쓴다.
    private static func placement(inSlot slot: Int, seed: String) -> StickerPlacement {
        let hash = fnv1a(seed)
        let column = slot % Grid.columns
        let row = (slot / Grid.columns) % Grid.rows

        return StickerPlacement(
            xRatio: Grid.columnCenter(column) + jitter(hash, shift: 0, spread: Grid.jitterX),
            yRatio: Grid.rowCenter(row) + jitter(hash, shift: 16, spread: Grid.jitterY),
            angleDegrees: Grid.angleLower + (Grid.angleUpper - Grid.angleLower) * unit(hash, shift: 32)
        )
    }
}

// MARK: - Figma 실측값

/// 스티커가 놓이는 격자 (사진 358 × 477 · 스티커 한 변 82 기준).
///
/// - 슬롯 중심 간격이 스티커보다 넓어야 겹치지 않는다 — 가로 119 · 세로 105, 흔들림을 빼도 각각 94 · 86이 남는다.
/// - 세로는 사진 위쪽을 비운다. 거기 촬영자 표시가 얹혀서 스티커가 이름과 시각을 가린다.
private enum Grid {
    static let columns = 3
    static let rows = 3
    static var slotCount: Int {
        columns * rows
    }

    /// 슬롯 중심에서 흔들 수 있는 폭. 이웃 슬롯도 사진 가장자리도 침범하지 않는 선.
    static let jitterX = 0.035
    static let jitterY = 0.02

    /// 시안 실측 -12.1°를 가운데쯤에 두고 좌우로 흔든다.
    static let angleLower = -20.0
    static let angleUpper = 12.0

    /// 스티커가 놓이는 세로 구간. 위쪽 22%는 촬영자 표시 자리로 비워 둔다.
    private static let top = 0.22
    private static let bottom = 0.88

    static func columnCenter(_ index: Int) -> Double {
        (Double(index) + 0.5) / Double(columns)
    }

    static func rowCenter(_ index: Int) -> Double {
        top + (bottom - top) * (Double(index) + 0.5) / Double(rows)
    }
}

// MARK: - 결정적 난수

/// 해시의 16비트 구간 하나를 0~1로 편다.
private func unit(_ hash: UInt64, shift: UInt64) -> Double {
    Double((hash >> shift) & 0xFFFF) / Double(0xFFFF)
}

private func jitter(_ hash: UInt64, shift: UInt64, spread: Double) -> Double {
    (unit(hash, shift: shift) - 0.5) * 2 * spread
}

/// 문자열을 64비트로 섞는다 (FNV-1a). 플랫폼·실행 회차와 무관하게 같은 결과를 낸다.
///
/// 마지막 xor-fold는 FNV-1a의 하위 비트 확산이 약한 것을 보정한다 —
/// 앞부분이 같은 문자열끼리 하위 비트가 닮아서, 그대로 쓰면 값이 한쪽으로 몰린다.
private func fnv1a(_ string: String) -> UInt64 {
    let hash = string.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return hash ^ (hash >> 32)
}
