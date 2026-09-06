import CHALLAImageKit
import CHALLANetwork
import Foundation
import PhotoDomain

/// 사진 조회·리액션 API와 원본 다운로드를 제공한다.
public struct DefaultPhotoRepository: PhotoRepository {

    private let client: any HTTPClient
    private let imageDownloader: ImageDataBatchDownloader

    public init(client: any HTTPClient, imageDownloader: ImageDataBatchDownloader = ImageDataBatchDownloader()) {
        self.client = client
        self.imageDownloader = imageDownloader
    }

    /// 모든 페이지를 조회해 촬영 순으로 반환한다. 리액션은 상세 조회에서 별도로 받는다.
    public func photos(inRoom roomID: Int64) async throws -> [Photo] {
        do {
            var items: [ListPhotosResponseDTO] = []
            var page = 0
            while page < Const.maxPages {
                let slice = try await client.request(
                    PhotoEndpoint.list(roomID: roomID, page: page, size: Const.pageSize),
                    as: BaseResponseDTO<ListPhotosSliceResponseDTO>.self
                ).unwrap()
                items.append(contentsOf: slice.photos)
                guard slice.hasNext, !slice.photos.isEmpty else { break }
                page += 1
            }

            // 촬영 시각이 같으면 숫자 ID로 정렬한다. 문자열 비교는 10을 9보다 앞에 둔다.
            return items.compactMap { $0.toDomain() }
                .sorted {
                    ($0.capturedAt, Int64($0.id) ?? 0) < ($1.capturedAt, Int64($1.id) ?? 0)
                }
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 사진 상세의 채팅 목록에서 이모지 리액션을 조회한다.
    public func reactions(inRoom roomID: Int64, photoID: String) async throws -> PhotoReactions {
        guard let id = Int64(photoID) else { throw PhotoError.unknown }
        do {
            let detail = try await client.request(
                PhotoEndpoint.detail(roomID: roomID, photoID: id),
                as: BaseResponseDTO<GetPhotoDetailEnvelopeDTO>.self
            ).unwrap()
            let data = detail.photo.reactionData()
            return PhotoReactions(stickers: data.stickers, reactedKindsByUser: data.kindsByUser)
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 이모지 리액션을 등록하고 삭제에 사용할 채팅 ID를 반환한다.
    @discardableResult
    public func setReaction(roomID: Int64, photoID: String, kind: ReactionKind) async throws -> Int64? {
        guard let photoIDValue = Int64(photoID) else { throw PhotoError.unknown }

        do {
            // 성공 응답의 data가 없어도 등록은 성공으로 처리한다.
            let response = try await client.request(
                ChatEndpoint.reaction(
                    CreateReactionRequestDTO(roomID: roomID, photoID: photoIDValue, content: kind.rawValue)
                ),
                as: BaseResponseDTO<CreateReactionResponseDTO>.self
            )
            guard response.success else { throw PhotoError.server(message: response.message) }
            return response.data?.chat?.chatId
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 채팅 ID로 이모지 리액션을 삭제한다.
    public func deleteReaction(chatID: Int64) async throws {
        do {
            let response = try await client.request(
                ChatEndpoint.deleteReaction(chatID: chatID),
                as: BaseResponseDTO<DeleteReactionResponseDTO>.self
            )
            guard response.success else { throw PhotoError.server(message: response.message) }
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 사진첩 저장용 원본 데이터를 반환한다.
    public func imageData(for photo: Photo) async throws -> Data {
        for await result in imageDownloader.stream(urls: [photo.imageURL]) {
            switch result {
            case let .success(data):
                return data
            case let .failure(error):
                if error == .cancelled {
                    throw CancellationError()
                }
                throw PhotoError.network
            }
        }
        try Task.checkCancellation()
        throw PhotoError.unknown
    }

    /// 원본을 병렬로 다운로드하고 입력 순서대로 반환한다.
    public func imageDataStream(for photos: [Photo]) -> AsyncStream<Result<Data, PhotoError>> {
        // 다운로더가 주는 스트림을 그대로 돌려준다. 다른 AsyncStream에 옮겨 담으면
        // 기본 버퍼가 무제한이라 저장 속도와 무관하게 원본이 쌓인다.
        imageDownloader.stream(urls: photos.map(\.imageURL), mapError: Self.photoError(from:))
    }

    /// 다운로드 오류를 도메인 오류로 변환한다.
    private static func photoError(from error: ImageLoadingError) -> PhotoError {
        error == .cancelled ? .unknown : .network
    }

    private enum Const {
        static let pageSize = 50
        /// 잘못된 hasNext 응답으로 인한 무한 요청을 막는다.
        static let maxPages = 20
    }
}
