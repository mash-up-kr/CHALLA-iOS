import ProjectDescription

let tuist = Tuist(
    // 원격 바이너리 캐시·selective testing 공유용 Tuist 서버 프로젝트 핸들.
    // 이게 있어야 tuist cache/test 가 원격 캐시를 읽고 쓴다. 인증은 CI 의 TUIST_CONFIG_TOKEN,
    // 로컬은 `tuist auth login`.
    fullHandle: "mashup-challa/ios",
    project: .tuist(
        compatibleXcodeVersions: .all,
        swiftVersion: "6.0"
    )
)
