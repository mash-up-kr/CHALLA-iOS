import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Foundation") {
                    Text("준비 중")
                        .foregroundStyle(.secondary)
                }

                Section("Component") {
                    Text("준비 중")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("CHALLA 디자인 시스템")
        }
    }
}

#Preview {
    RootView()
}
