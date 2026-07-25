import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Foundation") {
                    NavigationLink("Color") {
                        ColorGallery()
                    }
                    NavigationLink("Typography") {
                        TypographyGallery()
                    }
                    NavigationLink("Icon") {
                        IconGallery()
                    }
                }

                Section("Component") {
                    NavigationLink("Button") {
                        ButtonGallery()
                    }
                }
            }
            .navigationTitle("CHALLA 디자인 시스템")
        }
        // 토큰이 다크 기준 고정 hex라 검수 화면도 다크로 고정한다 (본 앱 정책과는 별개)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
