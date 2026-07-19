import SwiftUI

/// CHALLANetwork 검수 진입 화면.
/// 인터셉터 구성만 다른 두 가지 실행 화면으로 나눠 들어간다.
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("요청 실행") {
                    NavigationLink("기본 (로깅만)") {
                        EndpointDemoView(useAuth: false)
                    }
                    NavigationLink("인증 인터셉터 포함") {
                        EndpointDemoView(useAuth: true)
                    }
                }

                Section("대상 서버") {
                    LabeledContent("Base URL", value: "jsonplaceholder.typicode.com")
                        .font(.footnote)
                }

                Section {
                    Text("각 버튼은 CHALLANetwork의 DefaultHTTPClient로 실제 HTTP 요청을 보냅니다. (인터넷 연결 필요)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("CHALLANetwork")
        }
    }
}

#Preview {
    RootView()
}
