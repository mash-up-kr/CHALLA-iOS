import CHALLANetwork
import Foundation
import PhotoDomain

/// `PhotoRepository`의 실서버 구현.
/// 실패는 전부 `PhotoError`로 정규화해 던진다 (`DefaultPhotoUploader`와 같은 규약).
public struct DefaultPhotoRepository: PhotoRepository {

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    /// 방의 사진을 찍힌 순서대로 돌려준다(목록만). `hasNext`가 없을 때까지 페이지를 이어 받는다.
    /// 리액션(스티커·칩 띠)은 목록 응답에 없으므로 담지 않는다 — 사진을 펼칠 때 `reactions(forPhotoID:)`로 따로 받는다.
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
                // 빈 페이지거나 다음이 없으면 종료 — 서버가 hasNext를 계속 true로 줘도 무한 루프에 빠지지 않게.
                guard slice.hasNext, !slice.photos.isEmpty else { break }
                page += 1
            }

            // 표시 불가능한 장(이미지 URL 없음)은 건너뛴다 — 한 장 때문에 목록이 통째로 실패하지 않게.
            return items.compactMap { $0.toDomain() }
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 사진 한 장의 리액션을 상세(`chats`)에서 받아 온다.
    /// 목록엔 리액션이 없어, 사진을 펼칠 때만 그 한 장을 부른다(안 본 사진은 요청하지 않아 1+N을 피한다).
    public func reactions(forPhotoID photoID: String) async throws -> PhotoReactions {
        guard let id = Int64(photoID) else { throw PhotoError.unknown }
        do {
            let detail = try await client.request(
                PhotoEndpoint.detail(photoID: id),
                as: BaseResponseDTO<GetPhotoDetailEnvelopeDTO>.self
            ).unwrap()
            let data = detail.photo.reactionData()
            return PhotoReactions(stickers: data.stickers, reactedKindsByUser: data.kindsByUser)
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 사진에 이모지 리액션을 남긴다.
    ///
    /// 서버에 해제(삭제) API가 없어 `isOn == false`(해제)는 처리하지 않는다 — 호출부가 UI에서 이미 막는다.
    /// 서버 응답은 갱신 사진을 주지 않으므로 성공 여부만 확인하고, 화면 갱신은 호출부의 낙관적 반영에 맡긴다.
    public func setReaction(roomID: Int64, photoID: String, kind: ReactionKind, isOn: Bool) async throws {
        guard isOn else { return }
        guard let photoIDValue = Int64(photoID) else { throw PhotoError.unknown }

        do {
            // 리액션은 응답 본문(data)을 쓰지 않는다 — 서버가 data를 비워 줘도 성공으로 본다(성공 플래그만 확인).
            // `unwrap()`은 data가 nil이면 실패로 던져서, 낙관적으로 붙인 스티커가 되돌려지는 문제가 있었다.
            let response = try await client.request(
                ChatEndpoint.reaction(
                    CreateReactionRequestDTO(roomID: roomID, photoID: photoIDValue, content: kind.rawValue)
                ),
                as: BaseResponseDTO<CreateReactionResponseDTO>.self
            )
            guard response.success else { throw PhotoError.server(message: response.message) }
        } catch {
            throw PhotoError.normalized(error)
        }
    }

    /// 원본 이미지 바이트. 사진첩 저장에 쓴다 — 표시용이 아니라 원본이므로 다운샘플하지 않고 그대로 받는다.
    public func imageData(for photo: Photo) async throws -> Data {
        do {
            let (data, _) = try await URLSession.shared.data(from: photo.imageURL)
            return data
        } catch let error as URLError where error.code == .cancelled {
            // 취소를 network 오류로 바꾸면 "네트워크 확인" 얼럿이 잘못 뜬다 — 취소는 취소로 올린다.
            throw CancellationError()
        } catch {
            throw PhotoError.network
        }
    }

    private enum Const {
        /// 한 방 최대 장수(72)를 한두 번에 받도록 크게 잡는다.
        static let pageSize = 50
        /// 페이지 순회 상한 — 서버가 hasNext를 계속 true로 줘도 무한 요청에 빠지지 않게 (50 × 20 = 1000장).
        static let maxPages = 20
    }
}
