@testable import PhotoLibrary
import Photos
import Testing

@Suite("PhotoLibraryAuthorization")
struct PhotoLibraryAuthorizationTests {

    @Test(
        "PHAuthorizationStatus를 그대로 옮겨 담는다",
        arguments: zip(
            [
                PHAuthorizationStatus.authorized,
                .limited,
                .denied,
                .restricted,
                .notDetermined
            ],
            [
                PhotoLibraryAuthorization.authorized,
                .limited,
                .denied,
                .restricted,
                .notDetermined
            ]
        )
    )
    func mapsSystemStatus(system: PHAuthorizationStatus, expected: PhotoLibraryAuthorization) {
        #expect(PhotoLibraryAuthorization(system) == expected)
    }

    @Test(
        "피커를 열 수 있는 상태는 authorized·limited 둘뿐",
        arguments: [
            (PhotoLibraryAuthorization.authorized, true),
            (.limited, true),
            (.denied, false),
            (.restricted, false),
            (.notDetermined, false)
        ]
    )
    func allowsPicking(authorization: PhotoLibraryAuthorization, expected: Bool) {
        #expect(authorization.allowsPicking == expected)
    }

    @Test(
        "사진첩에 저장할 수 있는 상태도 authorized·limited 둘뿐",
        arguments: [
            (PhotoLibraryAuthorization.authorized, true),
            (.limited, true),
            (.denied, false),
            (.restricted, false),
            (.notDetermined, false)
        ]
    )
    func allowsSaving(authorization: PhotoLibraryAuthorization, expected: Bool) {
        #expect(authorization.allowsSaving == expected)
    }
}
