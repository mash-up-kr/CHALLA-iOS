import SettingDomain

extension SettingError {

    /// UseCase의 라이브 구현이 실패를 전부 `SettingError`로 정규화하지만,
    /// 그러지 못한 오류가 새어 나올 경우를 대비해 `.unknown`으로 감싼다.
    /// (화면이 조용히 아무 것도 하지 않는 것보다 얼럿이라도 뜨는 편이 낫다)
    static func normalized(_ error: any Error) -> SettingError {
        error as? SettingError ?? .unknown
    }
}

extension Result where Failure == any Error {

    /// `Result { try await ... }`의 실패를 `SettingError`로 좁힌다.
    func mapToSettingError() -> Result<Success, SettingError> {
        mapError(SettingError.normalized)
    }
}
