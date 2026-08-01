import Foundation

/// `Configs/Shared.xcconfig`(gitignore)를 읽어 매니페스트(`tuist generate`) 단계에서 쓰는 백엔드 서버 값.
///
/// 같은 값이 앱 타깃 Info.plist에는 `$(API_HOST)` 형태로 주입되지만, ATS `NSExceptionDomains`의
/// 도메인은 plist의 dictionary key라 빌드 타임 치환이 통하지 않는다.
/// 그래서 ATS 예외만은 이 타입이 같은 파일을 직접 읽어 리터럴로 박아 넣는다.
enum APIEnvironment {

    static var scheme: String {
        value(for: "API_SCHEME")
    }

    static var host: String {
        value(for: "API_HOST")
    }

    /// 매니페스트는 작업 디렉터리를 보장받지 못하므로, 이 파일 위치에서 위로 올라가며
    /// 저장소 루트 표식(`Tuist.swift`)을 찾는다 — 이 파일이 옮겨져도 깨지지 않는다.
    private static let xcconfigURL: URL = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Tuist.swift").path) {
                return directory.appendingPathComponent("Configs/Shared.xcconfig")
            }
            directory = directory.deletingLastPathComponent()
        }
        fatalError("저장소 루트(Tuist.swift가 있는 디렉터리)를 찾을 수 없습니다: \(#filePath)")
    }()

    private static func value(for key: String) -> String {
        guard let content = try? String(contentsOf: xcconfigURL, encoding: .utf8) else {
            fatalError(
                "Configs/Shared.xcconfig를 읽을 수 없습니다: \(xcconfigURL.path)\n"
                    + "Configs/Shared.xcconfig.template를 Shared.xcconfig로 복사한 뒤 값을 채우세요."
            )
        }

        // `.newlines`로 쪼개야 CRLF로 저장된 xcconfig도 읽힌다.
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
