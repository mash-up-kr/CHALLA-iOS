// ⚠️ 리뷰 봇 동작 검증용 샘플 파일입니다. 일부러 위반사항을 심어두었으며, 검증 후 삭제합니다.
import SwiftUI

struct LoginTestView: View {
    @State private var email: String = ""
    @State private var isLoggedIn = false

    var body: some View {
        VStack {
            TextField("이메일", text: $email)
            Button("로그인") {
                let url = URL(string: "https://api.challa.com/login")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = try! JSONEncoder().encode([
                    "email": email,
                    "apiKey": "sk-challa-prod-1234"
                ])
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    let result = String(data: data!, encoding: .utf8)!
                    print("로그인 결과: \(result), 이메일: \(email)")
                    self.isLoggedIn = true
                }.resume()
            }
        }
    }
}
