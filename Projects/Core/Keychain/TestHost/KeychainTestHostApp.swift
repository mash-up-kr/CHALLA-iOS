import SwiftUI

/// KeychainTests 전용 빈 호스트 앱.
/// 유닛테스트가 앱 프로세스에 호스트되어야 키체인(SecItem) 접근 엔타이틀먼트를 얻는다.
/// 직접 실행할 일은 없다.
@main
struct KeychainTestHostApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Keychain Test Host")
        }
    }
}
