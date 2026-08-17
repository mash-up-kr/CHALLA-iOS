import ComposableArchitecture
import Foundation
import PhotoData // 앱 조립 지점이라 Data를 직접 import 한다 (아키텍처 규칙 2의 예외)
import PhotoDomain
import RoomData
import RoomDomain

/// 의존성 조립 지점 — 데모앱에서 유일하게 Data 구현체를 만드는 곳.
///
/// 서버 대신 InMemory 구현을 꽂는다 — 로그인이 없는 데모앱은 토큰이 없어 실서버를 못 부른다.
/// 필터 LUT는 코드에서 생성한 목 .cube 데이터로 제공한다 — 실 LUT 원본은 서버에만 있고
/// 저장소에는 .cube 파일을 두지 않는다.
enum CompositionRoot {

    static func registerDependencies(for scenario: DemoScenario, into values: inout DependencyValues) {
        let roomRepository = InMemoryRoomRepository(cards: cards(for: scenario))
        values.fetchShootableRoomsUseCase = .live(repository: roomRepository)

        let filterRepository = InMemoryCameraFilterRepository(
            filters: Self.mockFilterList,
            lutDataByName: Self.mockLUTData
        )
        values.fetchCameraFiltersUseCase = .live(repository: filterRepository)
        values.loadFilterLUTUseCase = .live(repository: filterRepository)

        let uploader = InMemoryPhotoUploader(
            remainedPhotoCounts: remainedPhotoCounts(for: scenario)
        )
        values.uploadPhotoUseCase = .live(uploader: uploader)
    }

    // MARK: - 방 구성

    private static func cards(for scenario: DemoScenario) -> [RoomCard] {
        switch scenario.state {
        case .default:
            return [
                card(id: -1, title: "방이름방이름방이름1", remained: 6, total: 24),
                card(id: -2, title: "방이름방이름방이름2", remained: 6, total: 24),
                card(id: -3, title: "방이름방이름방이름3", remained: 3, total: 48),
                card(id: -4, title: "방이름방이름방이름4", remained: 3, total: 48),
                // 말줄임 확인용 — 시안 SelectRoom 3행이 긴 이름 케이스다
                card(id: -5, title: "방이름방이름방이름5방이름방이름방이름5", remained: 3, total: 48)
            ]
        case .error:
            return [card(id: -3, title: "방이름방이름방이름3", remained: 0, total: 48)]
        }
    }

    /// 업로더의 차감 시작값 — 방 목록과 같은 값에서 출발해야 화면 숫자와 어긋나지 않는다.
    private static func remainedPhotoCounts(for scenario: DemoScenario) -> [Int64: Int] {
        cards(for: scenario).reduce(into: [:]) { counts, card in
            counts[card.id] = card.room.remainedPhotoCount
        }
    }

    private static func card(id: Int64, title: String, remained: Int, total: Int) -> RoomCard {
        RoomCard(
            room: Room(
                id: id,
                title: title,
                status: .shooting, // shootable 목록의 전제 — InMemory 저장소가 이 상태만 내려준다
                totalPhotoCount: total,
                remainedPhotoCount: remained,
                createdAt: .now,
                expiresAt: .now.addingTimeInterval(Room.previewLifetime)
            ),
            memberCount: 4,
            thumbnailURLs: []
        )
    }

    // MARK: - 필터 구성

    /// 목 필터 한 개의 색감 정의 — 채널별 게인과 흑백 여부만으로 근사한다.
    private struct MockFilterSpec {
        let name: String
        let redGain: Float
        let greenGain: Float
        let blueGain: Float
        let monochrome: Bool

        init(_ name: String, red: Float, green: Float, blue: Float, monochrome: Bool = false) {
            self.name = name
            redGain = red
            greenGain = green
            blueGain = blue
            self.monochrome = monochrome
        }
    }

    /// 서버 camera-filters 응답을 흉내 낸 목 필터. 이름은 기존 기획값, 색감은 이름에서 유추한 근사치다.
    private static let mockFilterSpecs: [MockFilterSpec] = [
        MockFilterSpec("Black", red: 0.75, green: 0.75, blue: 0.75, monochrome: true),
        MockFilterSpec("Gray", red: 1, green: 1, blue: 1, monochrome: true),
        MockFilterSpec("Cold", red: 0.85, green: 0.95, blue: 1.15),
        MockFilterSpec("Blue", red: 0.75, green: 0.9, blue: 1.25),
        MockFilterSpec("Warm", red: 1.15, green: 1, blue: 0.8),
        MockFilterSpec("Old", red: 1.1, green: 0.9, blue: 0.65, monochrome: true), // 세피아 — 흑백 위에 갈색조
        MockFilterSpec("Forest", red: 0.85, green: 1.1, blue: 0.85),
        MockFilterSpec("Sky", red: 0.9, green: 1.05, blue: 1.2),
        MockFilterSpec("Green", red: 0.8, green: 1.2, blue: 0.8),
        MockFilterSpec("Soft", red: 1.05, green: 1, blue: 1.05)
    ]

    private static var mockFilterList: [CameraFilter] {
        mockFilterSpecs.compactMap { spec in
            // InMemory 저장소는 이름으로 LUT를 찾으므로 URL은 형식만 갖춘 가짜 값이다.
            URL(string: "https://demo.invalid/luts/\(spec.name.lowercased()).cube")
                .map { CameraFilter(name: spec.name, fileURL: $0) }
        }
    }

    private static var mockLUTData: [String: Data] {
        mockFilterSpecs.reduce(into: [:]) { lutData, spec in
            lutData[spec.name] = mockCubeData(for: spec)
        }
    }

    /// 서버가 내려주는 것과 같은 규격의 .cube 텍스트를 2×2×2 최소 크기로 생성한다 —
    /// 꼭짓점 8개의 선형 보간이라 채널 게인·흑백 변환 표현에는 충분하다.
    private static func mockCubeData(for spec: MockFilterSpec) -> Data {
        var lines = ["LUT_3D_SIZE 2"]
        for blue: Float in [0, 1] {
            for green: Float in [0, 1] {
                for red: Float in [0, 1] { // .cube 규격 — R이 가장 빨리 돈다
                    var (outRed, outGreen, outBlue) = (red, green, blue)
                    if spec.monochrome {
                        let luma = 0.299 * red + 0.587 * green + 0.114 * blue
                        (outRed, outGreen, outBlue) = (luma, luma, luma)
                    }
                    lines.append(
                        "\(min(outRed * spec.redGain, 1))"
                            + " \(min(outGreen * spec.greenGain, 1))"
                            + " \(min(outBlue * spec.blueGain, 1))"
                    )
                }
            }
        }
        return Data(lines.joined(separator: "\n").utf8)
    }
}
