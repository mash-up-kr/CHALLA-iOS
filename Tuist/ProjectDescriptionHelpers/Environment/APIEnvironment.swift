import Foundation

/// `Configs/Shared.xcconfig`(gitignore)를 읽어 매니페스트(`tuist generate`) 단계에서 쓰는 백엔드 서버 값.
///
/// 서버 주소는 공개하지 않는 값이라 팀 ID·카카오 키와 같은 로컬 전용 파일에 둔다
/// (`Shared.xcconfig.template`를 복사해 생성).
/// `API_SCHEME`/`API_HOST`/`API_PORT`는 앱 타깃 Info.plist에도 `$(API_HOST)` 형태로 주입되지만,
/// ATS `NSExceptionDomains`의 도메인은 plist의 dictionary key라 빌드 타임 치환을 신뢰할 수 없다.
/// 그래서 ATS 예외만은 이 타입이 같은 파일을 직접 읽어 리터럴로 박아 넣는다 — `Shared.xcconfig` 한 곳만
/// 고치면 baseURL과 ATS 예외가 항상 같이 바뀐다 (`makeAppProject`가 소비).
enum APIEnvironment {

    static var scheme: String { value(for: "API_SCHEME") }
    static var host: String { value(for: "API_HOST") }

    private static func value(for key: String) -> String {
        let xcconfigURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // APIEnvironment.swift → Environment/
            .deletingLastPathComponent()   // Environment/ → ProjectDescriptionHelpers/
            .deletingLastPathComponent()   // ProjectDescriptionHelpers/ → Tuist/
            .deletingLastPathComponent()   // Tuist/ → 저장소 루트
            .appendingPathComponent("Configs/Shared.xcconfig")

        guard let content = try? String(contentsOf: xcconfigURL, encoding: .utf8) else {
            fatalError(
                "Configs/Shared.xcconfig를 읽을 수 없습니다: \(xcconfigURL.path)\n"
                + "Configs/Shared.xcconfig.template를 Shared.xcconfig로 복사한 뒤 값을 채우세요."
            )
        }

        // `.newlines`로 쪼개 CRLF도 처리하고, xcconfig 줄 끝 주석(`KEY = value // comment`)도 잘라낸다.
        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix(key) else { continue }
            let afterKey = line.dropFirst(key.count).trimmingCharacters(in: .whitespacesAndNewlines)
            guard afterKey.hasPrefix("=") else { continue }
            var value = afterKey.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            if let commentRange = value.range(of: "//") {
                value = value[..<commentRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return value
        }

        fatalError(
            "Configs/Shared.xcconfig에서 \(key)를 찾을 수 없습니다.\n"
            + "Shared.xcconfig.template의 백엔드 서버 항목을 참고해 값을 채우세요."
        )
    }
}
