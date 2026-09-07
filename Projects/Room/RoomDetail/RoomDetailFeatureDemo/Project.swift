import ProjectDescription
import ProjectDescriptionHelpers

/// 데모앱은 앱 조립 지점이므로 예외적으로 Data(Mock/실 구현)를 주입할 수 있다 (아키텍처 규칙 2의 유일한 예외).
let project = Project.makeAppProject(
    name: "RoomDetailFeatureDemo",
    displayName: "CHALLA RoomDetail 데모",
    bundleId: "\(Environment.bundleIdPrefix).roomdetailfeature.demo",
    marketingVersion: "1.0.0",
    buildNumber: "1",
    usesAPIEnvironment: false, // InMemory 저장소만 쓴다 — 서버 주소 불필요
    dependencies: [
        .roomDetailFeature, .roomDomain,
        // TODO: PhotoData가 생기면 가짜 사진 조회 대신 실구현을 주입한다.
        .photoDomain,
        .photoLibrary, // 촬영 진입이 묻는 사진첩 권한을 값으로 갈아끼운다 (데모에 시스템 팝업을 띄우지 않는다)
        .roomData, // 데모앱은 조립 지점이라 Data 직접 의존 허용 (아키텍처 규칙 2의 예외)
        .composableArchitecture
    ]
)
