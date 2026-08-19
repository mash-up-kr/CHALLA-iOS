@testable import CameraFeature
import Foundation
import Testing

// MARK: - LUT 등록

/// 등록 성공 여부가 카메라 진입 여부를 가른다 — 진입 버튼이 이 반환값으로 판단한다.
struct CameraFilterCatalogTests {

    @Test("정상 .cube는 등록되고 필터를 만들 수 있다")
    func registersValidCube() {
        let id = "정상필터"

        #expect(CameraFilterCatalog.register(cubeData: Data(CameraFeatureTestFixtures.validCubeText.utf8), for: id))
        #expect(CameraFilterCatalog.lutFilter(id: id) != nil)
    }

    @Test("깨진 .cube는 등록되지 않는다")
    func rejectsBrokenCube() {
        let id = "깨진필터"

        #expect(!CameraFilterCatalog.register(cubeData: Data("깨진 파일".utf8), for: id))
        #expect(CameraFilterCatalog.lutFilter(id: id) == nil)
    }
}
