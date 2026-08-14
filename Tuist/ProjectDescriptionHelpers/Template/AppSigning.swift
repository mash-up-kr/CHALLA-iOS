import ProjectDescription

/// 앱 타깃의 코드 서명 방식.
///
/// 프레임워크·데모앱까지 한꺼번에 바꾸면 프로파일을 지원하지 않는 타깃이 빌드를 거부하므로,
/// 앱 프로젝트마다 따로 고른다.
public enum AppSigning {

    /// Xcode가 프로파일을 알아서 만들고 갱신한다. 데모·검수앱처럼 배포하지 않는 앱에 쓴다.
    case automatic

    /// Apple Developer 포털에 만들어 둔 팀 프로파일을 직접 지정한다.
    /// capability를 추가해도 Xcode가 프로파일을 새로 만들려 하지 않아 서명 결과가 예측 가능하다.
    /// 대신 팀원 각자가 두 프로파일을 내려받아 두어야 한다.
    case manual(debugProfile: String, releaseProfile: String)

    /// 두 설정 모두에 공통으로 들어가는 값.
    var baseSettings: SettingsDictionary {
        switch self {
        case .automatic:
            ["CODE_SIGN_STYLE": "Automatic"]
        case .manual:
            [
                "CODE_SIGN_STYLE": "Manual",
                // 시뮬레이터 빌드는 서명하지 않는다. 프로파일이 없는 CI에서도 테스트가 돌아야 한다.
                "CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]": "NO"
            ]
        }
    }

    var debugSettings: SettingsDictionary {
        switch self {
        case .automatic:
            [:]
        case let .manual(debugProfile, _):
            [
                "PROVISIONING_PROFILE_SPECIFIER": .string(debugProfile),
                "CODE_SIGN_IDENTITY": "Apple Development"
            ]
        }
    }

    var releaseSettings: SettingsDictionary {
        switch self {
        case .automatic:
            [:]
        case let .manual(_, releaseProfile):
            [
                "PROVISIONING_PROFILE_SPECIFIER": .string(releaseProfile),
                "CODE_SIGN_IDENTITY": "Apple Distribution"
            ]
        }
    }
}
