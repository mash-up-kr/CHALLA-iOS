import Foundation
import Security

/// Security(SecItem) 기반 `Keychain` 구현. `kSecClassGenericPassword` 항목으로 저장한다.
///
/// `service`가 항목의 네임스페이스가 되고, `key`는 `kSecAttrAccount`에 대응한다.
/// 시뮬레이터·실기기 모두 동작한다 (키체인 공유 그룹 미사용).
///
/// SecItem API 자체가 스레드 안전해 `Sendable`을 그대로 만족한다.
public final class KeychainStore: Keychain {

    /// 항목을 구분하는 서비스 식별자 (예: `"com.challa.auth"`).
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func save(_ data: Data, for key: String) throws {
        // 기존 항목이 있으면 갱신, 없으면 추가한다 (upsert).
        //
        // 지우고 다시 넣는 방식은 쓰지 않는다 — 삭제까지만 성공하고 추가가 실패하면
        // 원래 있던 값마저 사라져(토큰 소실 → 강제 재로그인) 실패가 값 유실로 번진다.
        // update는 실패해도 기존 값이 그대로 남는다.
        let status = SecItemUpdate(
            baseQuery(for: key) as CFDictionary,
            attributesToWrite(data) as CFDictionary
        )

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            try add(data, for: key)
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func load(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func delete(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)

        // 지울 항목이 원래 없던 것도 "삭제된 상태"이므로 성공으로 간주한다.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 항목이 없을 때의 첫 저장.
    private func add(_ data: Data, for key: String) throws {
        var query = baseQuery(for: key)
        query.merge(attributesToWrite(data)) { _, new in new }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 저장 시 기록하는 값과 접근 정책 (add·update 공통).
    private func attributesToWrite(_ data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
            // 첫 잠금해제 이후 접근 가능 + 이 기기 한정(백업/iCloud 이전 제외).
            // 토큰 저장소 용도의 표준 조합 — 백그라운드(잠금 중) 접근이 필요해져도 실패하지 않는다.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    /// 모든 SecItem 호출이 공유하는 기본 쿼리.
    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
