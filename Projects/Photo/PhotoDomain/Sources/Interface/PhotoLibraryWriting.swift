import Foundation

/// 기기 사진첩 쓰기 추상. 권한 요청까지 구현체 안에서 끝내고, 거부되면 `PhotoError.permissionDenied`를 던진다.
public protocol PhotoLibraryWriting: Sendable {

    func save(imageData: Data) async throws
}
