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

    /// Xcode Cloud처럼 CI가 서명을 직접 관리하는 환경인지 (`TUIST_CLOUD_SIGNING`).
    ///
    /// Xcode Cloud는 클라우드 관리 인증서·프로파일로 서명하며 **자동 서명을 전제한다**.
    /// `.manual`이 지정한 이름의 프로파일은 러너에 없으므로, 그대로 두면 Archive가
    /// "No profile matching ..." 으로 실패한다. 그래서 이 환경에서만 manual을 automatic으로 낮춘다.
    ///
    /// 변수를 켜는 곳은 `ci_scripts/ci_post_clone.sh` 하나뿐이다 — 로컬과 GitHub Actions CI는
    /// 설정하지 않으므로 기존 동작(지정 프로파일로 예측 가능한 서명)이 그대로 유지된다.
    /// (`ProjectDescription.` 명시: 우리 헬퍼의 Environment enum과 이름이 겹침)
    private static var prefersCIManagedSigning: Bool {
        ProjectDescription.Environment.cloudSigning.getBoolean(default: false)
    }

    /// `.manual`이 위 이유로 자동 서명으로 강등된 상태인지.
    private var isDowngradedToAutomatic: Bool {
        switch self {
        case .automatic: false
        case .manual: Self.prefersCIManagedSigning
        }
    }

    /// 두 설정 모두에 공통으로 들어가는 값.
    var baseSettings: SettingsDictionary {
        switch self {
        case .automatic:
            ["CODE_SIGN_STYLE": "Automatic"]
        case .manual:
            if isDowngradedToAutomatic {
                ["CODE_SIGN_STYLE": "Automatic"]
            } else {
                ["CODE_SIGN_STYLE": "Manual"]
            }
        }
    }

    var debugSettings: SettingsDictionary {
        switch self {
        case .automatic:
            [:]
        case let .manual(debugProfile, _):
            if isDowngradedToAutomatic {
                Self.cloudManagedSettings(identity: "Apple Development")
            } else {
                Self.deviceSettings(profile: debugProfile, identity: "Apple Development")
            }
        }
    }

    var releaseSettings: SettingsDictionary {
        switch self {
        case .automatic:
            [:]
        case let .manual(_, releaseProfile):
            if isDowngradedToAutomatic {
                Self.cloudManagedSettings(identity: "Apple Distribution")
            } else {
                Self.deviceSettings(profile: releaseProfile, identity: "Apple Distribution")
            }
        }
    }

    /// 프로파일·인증서는 실기기 빌드에만 건다. 프로파일이 없는 CI에서도 시뮬레이터 빌드는 돌아야 하기 때문.
    ///
    /// 시뮬레이터는 ad-hoc(`-`)으로 서명한다. 서명을 아예 끄면(`CODE_SIGNING_ALLOWED=NO`)
    /// entitlements가 바이너리에 embed되지 않아, `com.apple.developer.applesignin`이 빠진 채로 실행된다
    /// → Apple 로그인이 `ASAuthorizationError.unknown(1000)`으로, Keychain 저장이 `errSecMissingEntitlement`로 실패한다.
    private static func deviceSettings(profile: String, identity: String) -> SettingsDictionary {
        [
            "PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]": .string(profile),
            "CODE_SIGN_IDENTITY[sdk=iphoneos*]": .string(identity),
            "CODE_SIGN_IDENTITY[sdk=iphonesimulator*]": "-"
        ]
    }

    /// 강등됐을 때 쓰는 설정. `deviceSettings`에서 프로파일 지정만 뺀 형태다.
    ///
    /// `PROVISIONING_PROFILE_SPECIFIER`는 **반드시 빠져야** 한다 — 자동 서명에 프로파일 지정이
    /// 남아 있으면 Xcode가 거부한다. 프로파일은 Xcode Cloud가 발급해 주므로 이름을 지정할 필요도 없다.
    ///
    /// 반면 `CODE_SIGN_IDENTITY[sdk=iphoneos*]`는 **남겨야 한다.** Tuist가 타깃 기본값으로
    /// `CODE_SIGN_IDENTITY = "iPhone Developer"`를 넣는데, sdk 한정 키가 없으면 그 개발용 신원이
    /// 실기기 빌드에 적용된다 — 배포 아카이브를 개발 인증서로 서명하려다 실패한다.
    ///
    /// 시뮬레이터 ad-hoc(`-`)은 서명 방식과 무관한 entitlements embed 장치라 그대로 둔다(위 주석 참고).
    private static func cloudManagedSettings(identity: String) -> SettingsDictionary {
        [
            "CODE_SIGN_IDENTITY[sdk=iphoneos*]": .string(identity),
            "CODE_SIGN_IDENTITY[sdk=iphonesimulator*]": "-"
        ]
    }
}
