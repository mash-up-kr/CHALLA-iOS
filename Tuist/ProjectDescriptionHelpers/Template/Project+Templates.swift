import ProjectDescription

public extension Project {

    /// 프레임워크 모듈 하나를 담은 프로젝트를 생성한다.
    /// - 이 프로젝트가 담는 타깃의 product(static/dynamic)는 `makeModuleTarget`이 hasResource로 자동 결정.
    /// - Parameters:
    ///   - name: 모듈 이름 (= 프로젝트/타깃 이름)
    ///   - hasResource: 리소스(폰트/애셋) 유무
    ///   - hasTests: 테스트 타깃(<모듈명>Tests, Tests/** 규약) 포함 여부
    ///   - dependencies: 이 모듈(타깃)이 의존하는 대상 (호출부에서 헬퍼로 명시)
    /// - Swift 언어 모드는 `.challaBase()`가 6.0으로 고정한다 (프로젝트별로 낮출 수 없다).
    static func makeModule(
        name: String,
        hasResource: Bool = false,
        hasTests: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Project {
        var targets = [
            Target.makeModuleTarget(
                name: name,
                hasResource: hasResource,
                dependencies: dependencies
            )
        ]
        if hasTests {
            targets.append(Target.makeTestTarget(name: name))
        }

        return Project(
            name: name,
            organizationName: Environment.organizationName,
            options: .options(
                defaultKnownRegions: ["en", "ko"],
                developmentRegion: "ko"
            ),
            settings: .challaBase(),
            targets: targets,
            // 리소스가 있을 때만 폰트 접근자/등록 코드를 자동 생성한다.
            // (otf/ttf 폴더를 스캔해 <모듈>FontFamily + registerAllCustomFonts() 를 Derived에 생성)
            resourceSynthesizers: hasResource ? [.fonts()] : []
        )
    }

    /// 실행 가능한 앱(.app) 하나를 담은 프로젝트를 생성한다.
    /// - 디자인 시스템 앱(CHALLADesignSystemApp) / 실서비스앱(CHALLAApp) / 피처 데모앱 등에 공통 사용.
    /// - 라이브러리(makeModule)와 달리 표시이름·번들ID를 직접 받는다(앱은 App Store 고유 식별 필요).
    /// - Parameters:
    ///   - name: 앱 타깃 이름 (예: CHALLADesignSystemApp)
    ///   - displayName: 홈화면/TestFlight 표시 이름 (한글 가능, 예: "CHALLA 디자인 시스템")
    ///   - bundleId: 앱 번들 ID (예: com.challa.designsystem)
    ///   - marketingVersion: 사용자에게 보이는 버전 (앱마다 독립 — 디자인 시스템 앱과 서비스앱은 별개 앱)
    ///   - buildNumber: 빌드 번호 — 로컬 기본값. CI(Xcode Cloud)에서는 TUIST_BUILD_NUMBER 환경변수가 우선
    ///     (ci_post_clone.sh가 CI_BUILD_NUMBER를 넘겨 업로드마다 자동 증가 — 수동 +1 커밋 불필요)
    ///   - additionalInfoPlist: 앱별 추가 Info.plist 항목 (URL 스킴 등). 기본 항목과 겹치면 이 값이 이긴다
    ///   - entitlements: 앱 엔타이틀먼트 (예: Sign in with Apple). 없으면 nil
    ///   - usesAPIEnvironment: true면 백엔드 서버 Info.plist 값(`API_SCHEME`/`API_HOST`/`API_PORT`)과
    ///     필요 시 ATS 예외를 자동으로 주입한다 (`Configs/Shared.xcconfig` 기준). 서버를 호출하는 앱만 켠다.
    ///   - dependencies: 앱이 의존하는 대상 (디자인 시스템 앱=DS 모듈, 데모앱=피처+데이터 등)
    /// - Swift 언어 모드는 `Environment.swiftVersion`(6.0)으로 고정한다 (앱별로 낮출 수 없다).
    static func makeAppProject(
        name: String,
        displayName: String,
        bundleId: String,
        marketingVersion: String,
        buildNumber: String,
        additionalInfoPlist: [String: Plist.Value] = [:],
        entitlements: Entitlements? = nil,
        usesAPIEnvironment: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Project {
        var infoPlist: [String: Plist.Value] = [
            "CFBundleDisplayName": .string(displayName),
            "UILaunchScreen": .dictionary([:]),
            "UISupportedInterfaceOrientations": .array([
                .string("UIInterfaceOrientationPortrait")
            ]),
            "ITSAppUsesNonExemptEncryption": .boolean(false)
        ]
        if usesAPIEnvironment {
            infoPlist.merge(apiEnvironmentInfoPlist) { _, new in new }
        }
        infoPlist.merge(additionalInfoPlist) { _, new in new }

        // 빌드 번호: TUIST_BUILD_NUMBER 환경변수가 있으면(CI) 그 값, 없으면(로컬) 파라미터 값.
        // xcconfig 주입이 아닌 generate 시점 결정이라 빌드 설정 우선순위(base > xcconfig)에 안 밀린다.
        // (ProjectDescription. 명시: 우리 헬퍼의 Environment enum과 이름이 겹침)
        let resolvedBuildNumber = ProjectDescription.Environment.buildNumber.getString(default: buildNumber)

        // 서명·버전 빌드 설정. DEVELOPMENT_TEAM과 백엔드 서버 값은 Configs/Shared.xcconfig에서 주입.
        let settings: Settings = .settings(
            base: [
                "CODE_SIGN_STYLE": "Automatic",
                "MARKETING_VERSION": .string(marketingVersion),
                "CURRENT_PROJECT_VERSION": .string(resolvedBuildNumber),
                "SWIFT_VERSION": .string(Environment.swiftVersion)
            ],
            configurations: [
                .debug(name: .debug, xcconfig: .relativeToRoot("Configs/Shared.xcconfig")),
                .release(name: .release, xcconfig: .relativeToRoot("Configs/Shared.xcconfig"))
            ]
        )

        return Project(
            name: name,
            organizationName: Environment.organizationName,
            options: .options(
                defaultKnownRegions: ["en", "ko"],
                developmentRegion: "ko"
            ),
            targets: [
                .target(
                    name: name,
                    destinations: Environment.destinations,
                    product: .app,
                    bundleId: bundleId,
                    deploymentTargets: Environment.deploymentTarget,
                    infoPlist: .extendingDefault(with: infoPlist),
                    sources: ["Sources/**"],
                    resources: ["Resources/**"],
                    entitlements: entitlements,
                    dependencies: dependencies,
                    settings: settings
                )
            ]
        )
    }

    /// 백엔드 서버를 호출하는 앱 타깃 공통 Info.plist 조각.
    /// `API_SCHEME`/`API_HOST`/`API_PORT` 값은 `Configs/Shared.xcconfig`(gitignore) → `$(API_HOST)` 형태로
    /// 빌드 타임에 주입된다.
    /// ATS 예외는 scheme이 `http`일 때만 붙는다 — `Shared.xcconfig`를 `https`로 바꾸면 다음 generate부터 자동으로 사라진다.
    private static var apiEnvironmentInfoPlist: [String: Plist.Value] {
        var plist: [String: Plist.Value] = [
            "API_SCHEME": .string("$(API_SCHEME)"),
            "API_HOST": .string("$(API_HOST)"),
            "API_PORT": .string("$(API_PORT)")
        ]
        if APIEnvironment.scheme == "http" {
            plist["NSAppTransportSecurity"] = .dictionary([
                "NSExceptionDomains": .dictionary([
                    APIEnvironment.host: .dictionary([
                        "NSExceptionAllowsInsecureHTTPLoads": .boolean(true),
                        "NSIncludesSubdomains": .boolean(true)
                    ])
                ])
            ])
        }
        return plist
    }
}
