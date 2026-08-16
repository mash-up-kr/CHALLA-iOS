import Foundation
import RoomDomain

extension RoomListResponseDTO.RoomDTO {

    /// 서버 목록 응답 한 줄을 `RoomCard`로 변환한다.
    /// `createdAt`·`expiresAt` 파싱에 실패하면 `RoomError.unknown`을 던지고, 호출부(목록 조회)가 함께 실패한다.
    func toDomain() throws -> RoomCard {
        guard let createdAt = ServerDate.parse(createdAt),
              let expiresAt = ServerDate.parse(expiresAt)
        else {
            throw RoomError.unknown
        }

        return RoomCard(
            room: Room(
                id: id,
                title: title,
                status: status.toDomain,
                totalPhotoCount: totalPhotoCount,
                remainedPhotoCount: remainedPhotoCount,
                createdAt: createdAt,
                expiresAt: expiresAt,
                // 촬영 중에는 null이 정상 (인화 대기부터 완료 예정 시각). 파싱 실패 시 이 값만 nil로 두고 방은 유지한다.
                photoPrintCompletedAt: photoPrintCompletedAt.flatMap(ServerDate.parse)
            ),
            memberCount: memberCount,
            thumbnailURLs: thumbnailImageUrls.compactMap(URL.init(string:))
        )
    }
}

extension RoomStatusDTO {

    var toDomain: Room.Status {
        switch self {
        case .shooting: return .shooting
        case .printPending: return .printWaiting
        case .printCompleted: return .printed
        }
    }
}

/// 서버 날짜 문자열을 `Date`로 바꾼다.
/// 백엔드 확정(2026-08-13): 타임존 표기 없이 UTC 기준으로 내려온다 — 예: "2026-08-03T13:38:42.959736".
enum ServerDate {

    /// 구체적인 형식부터 시도한다. 소수점 초는 자릿수가 다르거나(마이크로초 6 · 밀리초 3) 생략될 수 있다.
    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", // 실제 응답 형식 (마이크로초)
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss" //         소수점 초가 0이면 생략될 수 있다
    ]

    /// `DateFormatter`는 생성 비용이 커 미리 만들어 재사용한다.
    private static let formatters: [DateFormatter] = formats.map { format in
        let formatter = DateFormatter()
        formatter.dateFormat = format
        // 사용자 기기 설정(12시간제·다른 달력)의 영향을 받지 않는 고정 로케일.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }

    static func parse(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
