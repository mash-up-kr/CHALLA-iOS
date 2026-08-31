import Foundation

/// 기기 사진첩 쓰기 프로토콜. 권한 요청까지 구현 안에서 처리하고, 거부되면 `PhotoError.permissionDenied`를 던진다.
public protocol PhotoLibraryWriting: Sendable {

    func save(imageData: Data) async throws
}
