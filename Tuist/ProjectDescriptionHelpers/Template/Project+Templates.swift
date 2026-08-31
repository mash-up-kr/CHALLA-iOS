import ProjectDescription

public extension Project {

    /// 프레임워크 모듈 하나를 담은 프로젝트를 생성한다.
    /// - 이 프로젝트가 담는 타깃의 product(static/dynamic)는 `makeModuleTarget`이 정한다.
    /// - Parameters:
    ///   - name: 모듈 이름 (= 프로젝트/타깃 이름)
    ///   - hasResource: 리소스(폰트/애셋) 유무
    ///   - product: 산출물 형태를 직접 정한다. nil이면 자동 결정 —
    ///     어떤 모듈에 지정해야 하는지는 `Target.makeModuleTarget` 주석 참고
    ///   - hasTests: 테스트 타깃(<모듈명>Tests, Tests/** 규약) 포함 여부
    ///   - dependencies: 이 모듈(타깃)이 의존하는 대상 (호출부에서 헬퍼로 명시)
    ///   - testDependencies: 테스트에서만 필요한 의존 (`Tests/Support`의 목이 쓰는 타입 등)
    /// - Swift 언어 모드는 `.challaBase()`가 6.0으로 고정한다 (프로젝트별로 낮출 수 없다).
    static func makeModule(
        name: String,
        hasResource: Bool = false,
        product: Product? = nil,
        hasTests: Bool = false,
        dependencies: [TargetDependency] = [],
        testDependencies: [TargetDependency] = []
    ) -> Project {
        var targets = [
            Target.makeModuleTarget(
                name: name,
                hasResource: hasResource,
                product: product,
                dependencies: dependencies
            )
        ]
        if hasTests {
            targets.append(
                Target.makeTestTarget(name: name, additionalDependencies: testDependencies)
            )
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
    ///   - releaseEntitlements: Release 구성에서만 쓸 엔타이틀먼트. nil이면 `entitlements`를 두 구성 모두 쓴다.
    ///     배포앱은 `aps-environment`가 Debug=development / Release=production 으로 갈려야 해서 필요하다
    ///     (App Store 프로파일은 production만 포함 → development인 채로 아카이브하면 서명이 거부된다)
    ///   - hasTests: 테스트 타깃(<앱이름>Tests, Tests/** 규약) 포함 여부.
    ///     실배포앱은 조립(화면 전이·의존성 배선) 자체가 검증 대상이라 켠다. 데모·검수앱은 끈다
    ///   - signing: 서명 방식. 기본은 자동이고, 팀 프로파일을 직접 지정할 때만 `.manual`을 쓴다
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
        releaseEntitlements: Entitlements? = nil,
        hasTests: Bool = false,
        signing: AppSigning = .automatic,
        usesAPIEnvironment: Bool = false,
        dependencies: [TargetDependency] = []
    ) -> Project {
        var infoPlist: [String: Plist.Value] = [
            "CFBundleDisplayName": .string(displayName),
            // 버전 두 키는 반드시 빌드 설정을 참조해야 한다.
            // Tuist의 기본 Info.plist는 "1.0"/"1"을 리터럴로 넣는데, 그러면 아래 appSettings가
            // 정한 MARKETING_VERSION·CURRENT_PROJECT_VERSION을 아무도 읽지 않는다.
            // 그 상태로는 CI의 빌드 번호 자동 증가가 앱에 반영되지 않아, 두 번째 업로드부터
            // App Store Connect가 빌드 번호 중복으로 거부한다.
            "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
            "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
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

        var targets: [Target] = [
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
                settings: appSettings(
                    marketingVersion: marketingVersion,
                    buildNumber: buildNumber,
                    signing: signing,
                    releaseEntitlements: releaseEntitlements
                )
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
            targets: targets
        )
    }

    /// 서명·버전 빌드 설정. DEVELOPMENT_TEAM과 백엔드 서버 값은 `Configs/Shared.xcconfig`에서 주입한다.
    private static func appSettings(
        marketingVersion: String,
        buildNumber: String,
        signing: AppSigning,
        releaseEntitlements: Entitlements? = nil
    ) -> Settings {
        // 빌드 번호: TUIST_BUILD_NUMBER 환경변수가 있으면(CI) 그 값, 없으면(로컬) 파라미터 값.
        // xcconfig 주입이 아닌 generate 시점 결정이라 빌드 설정 우선순위(base > xcconfig)에 안 밀린다.
        // (ProjectDescription. 명시: 우리 헬퍼의 Environment enum과 이름이 겹침)
        let resolvedBuildNumber = ProjectDescription.Environment.buildNumber.getString(default: buildNumber)

        // 마케팅 버전도 같은 방식. ci_post_clone.sh 가 릴리즈 태그(v1.2.0)에서 뽑아 넘긴다.
        // 태그 없는 빌드(release/* 브랜치 등)와 로컬에서는 파라미터 값이 그대로 쓰인다.
        let resolvedMarketingVersion = ProjectDescription.Environment.marketingVersion
            .getString(default: marketingVersion)

        var base: SettingsDictionary = [
            "MARKETING_VERSION": .string(resolvedMarketingVersion),
            "CURRENT_PROJECT_VERSION": .string(resolvedBuildNumber),
            "SWIFT_VERSION": .string(Environment.swiftVersion),
            // Firebase·GoogleUtilities는 static framework로 링크된다. -ObjC가 없으면 링커가
            // 카테고리만 든 오브젝트 파일을 버려서, 호출 시점에 unrecognized selector로 앱이 죽는다
            // (예: GDT 업로드가 부르는 +[NSData gul_dataByGzippingData:error:]).
            "OTHER_LDFLAGS": .array(["$(inherited)", "-ObjC"])
        ]
        base.merge(signing.baseSettings) { _, new in new }

        // Release 전용 엔타이틀먼트는 구성 레벨에서 타깃 기본값(entitlements: 가 설정한 값)을 덮어쓴다.
        // 타깃에는 파일을 하나만 걸 수 있고, .dictionary로 바꾸면 generate가 매번 Derived에 다시 써서
        // "Entitlements file was modified during the build"로 빌드가 깨진다(CHALLAApp Project.swift 주석).
        // 경로는 SRCROOT(= 프로젝트 디렉터리) 기준 상대경로이고, 구성 설정이 xcconfig보다 우선한다.
        var releaseSettings = signing.releaseSettings
        if let releaseEntitlements {
            // `.dictionary`·`.variable`은 path가 nil이라 그냥 두면 Release가 Debug 엔타이틀먼트를
            // 그대로 쓰게 된다 — 이 파라미터가 막으려던 바로 그 사고(development로 배포)를 조용히 낸다.
            guard let path = releaseEntitlements.path?.pathString else {
                fatalError("releaseEntitlements는 .file(path:)만 지원한다. 받은 값: \(releaseEntitlements)")
            }
            releaseSettings["CODE_SIGN_ENTITLEMENTS"] = .string(path)
        }

        return .settings(
            base: base,
            configurations: [
                .debug(
                    name: .debug,
                    settings: signing.debugSettings,
                    xcconfig: .relativeToRoot("Configs/Shared.xcconfig")
                ),
                .release(
                    name: .release,
                    settings: releaseSettings,
                    xcconfig: .relativeToRoot("Configs/Shared.xcconfig")
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
