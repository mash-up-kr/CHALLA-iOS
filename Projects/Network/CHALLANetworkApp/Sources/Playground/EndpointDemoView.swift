import SwiftUI

/// 샘플 엔드포인트 목록을 버튼으로 나열하고, 실행 결과를 아래에 보여준다.
struct EndpointDemoView: View {

    let useAuth: Bool
    @State private var runner: RequestRunner

    init(useAuth: Bool) {
        self.useAuth = useAuth
        _runner = State(initialValue: RequestRunner(useAuth: useAuth))
    }

    private let samples: [(title: String, endpoint: SampleEndpoint)] = [
        ("GET /posts — requestPlain", .posts),
        ("GET /posts/1 — 단건", .post(id: 1)),
        ("GET /posts?userId=1 — URLEncoding", .postsByUser(userId: 1)),
        ("POST /posts — requestJSONEncodable", .createPost(title: "필름", body: "인화 대기중", userId: 1)),
        ("GET /this-path-does-not-exist — 404", .notFound)
    ]

    var body: some View {
        List {
            Section("요청 (원본 Response)") {
                ForEach(samples, id: \.title) { sample in
                    Button(sample.title) {
                        Task { await runner.run(sample.endpoint) }
                    }
                    .font(.callout)
                }
            }

            Section("디코딩 (map)") {
                Button("GET /posts → [SamplePostDTO] 디코딩") {
                    Task { await runner.runDecoded() }
                }
                .font(.callout)
            }

            Section("결과") {
                OutcomeView(outcome: runner.outcome)
            }
        }
        .navigationTitle(useAuth ? "인증 포함" : "기본")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 실행 결과 표시.
private struct OutcomeView: View {
    let outcome: RequestRunner.Outcome

    var body: some View {
        switch outcome {
        case .idle:
            Text("위 버튼을 눌러 요청을 보내보세요.")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("요청 중…")
            }
        case let .success(status, body):
            resultBody(badge: "\(status)", tint: .green, text: body)
        case let .failure(message):
            resultBody(badge: "실패", tint: .red, text: message)
        }
    }

    private func resultBody(badge: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(badge)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        EndpointDemoView(useAuth: false)
    }
}
