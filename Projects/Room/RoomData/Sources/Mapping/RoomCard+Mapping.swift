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
                // 인화 전 방에는 null이 정상. 값이 있는데 파싱에 실패하면 이 값만 nil로 두고 방은 유지한다.
                photoPrintCompletedAt: photoPrintCompletedAt.flatMap(ServerDate.parse)
            ),
            memberCount: memberCount,
            thumbnailURLs: thumbnailImageUrls.compactMap(URL.init(string:))
        )
    }
}

extension ShootableRoomListResponseDTO.ShootableRoomDTO {

    var toDomain: ShootableRoom {
        ShootableRoom(
            id: id,
            title: title,
            remainedPhotoCount: remainedPhotoCount,
            totalPhotoCount: totalPhotoCount
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

/// 서버 날짜 문자열을 `Date`로 바꾼다. 두 계열의 표기를 받는다:
/// 타임존 명시 ISO8601("2026-08-11T13:46:28.169Z")과 타임존 없는 표기("2026-08-11T12:34:56").
///
/// TODO: 백엔드 확인 — 실제 응답이 어느 표기인지 (스웨거 견본은 Z 포함, Spring LocalDateTime이면 Z 없음).
///       확인되면 안 쓰는 계열을 지운다. 타임존 없는 표기는 기준도 함께 확인 (그전까지 KST 가정).
enum ServerDate {

    /// 구체적인 형식부터 시도한다. `XXXXX`가 `Z`·`+09:00` 같은 타임존 표기를 받는다.
    /// (`ISO8601DateFormatter`를 쓰지 않는 이유 — `Sendable`이 아니라 Swift 6에서 static 공유가 막힌다.)
    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", // 타임존 + 소수점 초 (스웨거 견본 형식)
        "yyyy-MM-dd'T'HH:mm:ssXXXXX", //     타임존
        "yyyy-MM-dd'T'HH:mm:ss.SSS", //      타임존 없음 + 소수점 초
        "yyyy-MM-dd'T'HH:mm:ss" //           타임존 없음 (Spring LocalDateTime 기본)
    ]

    /// `DateFormatter`는 생성 비용이 커 미리 만들어 재사용한다.
    private static let formatters: [DateFormatter] = formats.map { format in
        let formatter = DateFormatter()
        formatter.dateFormat = format
        // 사용자 기기 설정(12시간제·다른 달력)의 영향을 받지 않는 고정 로케일.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
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
