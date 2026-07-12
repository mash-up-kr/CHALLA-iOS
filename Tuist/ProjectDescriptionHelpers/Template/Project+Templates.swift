import ProjectDescription

public extension Project {
    
    /// 프레임워크 모듈 하나를 담은 프로젝트를 생성한다.
    /// - 이 프로젝트가 담는 타깃의 product(static/dynamic)는 `makeModuleTarget`이 hasResource로 자동 결정.
    /// - Parameters:
    ///   - name: 모듈 이름 (= 프로젝트/타깃 이름)
    ///   - hasResource: 리소스(폰트/애셋) 유무
    ///   - hasTests: 테스트 타깃(<모듈명>Tests, Tests/** 규약) 포함 여부
    ///   - dependencies: 이 모듈(타깃)이 의존하는 대상 (호출부에서 헬퍼로 명시)
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
    ///   - marketingVersion: 사용자에게 보이는 버전 (앱마다 독립)
    ///   - buildNumber: 빌드 번호 (같은 버전 안에서 업로드마다 증가)
    ///   - dependencies: 앱이 의존하는 대상 (디자인 시스템 앱=DS 모듈, 데모앱=피처+데이터 등)
    static func makeAppProject(
        name: String,
        displayName: String,
        bundleId: String,
        marketingVersion: String,
        buildNumber: String,
        dependencies: [TargetDependency] = []
    ) -> Project {
        let infoPlist: [String: Plist.Value] = [
            "CFBundleDisplayName": .string(displayName),
            "UILaunchScreen": .dictionary([:]),
            "UISupportedInterfaceOrientations": .array([
                .string("UIInterfaceOrientationPortrait")
            ]),
            "ITSAppUsesNonExemptEncryption": .boolean(false)
        ]

        // 서명·버전 빌드 설정. DEVELOPMENT_TEAM은 Configs/Shared.xcconfig에서 주입.
        let settings: Settings = .settings(
            base: [
                "CODE_SIGN_STYLE": "Automatic",
                "MARKETING_VERSION": .string(marketingVersion),
                "CURRENT_PROJECT_VERSION": .string(buildNumber)
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
                    dependencies: dependencies,
                    settings: settings
                )
            ]
        )
    }
}
