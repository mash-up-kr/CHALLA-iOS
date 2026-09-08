import Foundation

/// `updateCover` 본문의 재료. 사진은 이미 업로드를 마친 URL이어야 한다 — 업로드는 `UploadRoomCoverImageUseCase`가 따로 한다.
public struct RoomCoverDraft: Equatable, Sendable {

    public var imageURL: URL?
    public var stickerID: Int64?
    public var colorID: Int64?

    public init(imageURL: URL? = nil, stickerID: Int64? = nil, colorID: Int64? = nil) {
        self.imageURL = imageURL
        self.stickerID = stickerID
        self.colorID = colorID
    }

    /// 화면이 그리는 커버를 그대로 서버에 싣는 초안. 커버 수정 화면과 App(스와이프 pop 저장)이 같은 변환을 쓴다.
    public init(cover: RoomCover) {
        self.init(imageURL: cover.imageURL, stickerID: cover.sticker?.id, colorID: cover.sticker?.color.id)
    }
}
