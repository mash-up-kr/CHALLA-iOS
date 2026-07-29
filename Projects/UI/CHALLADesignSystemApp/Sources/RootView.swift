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
                    NavigationLink("TextField") {
                        TextFieldGallery()
                    }
                    NavigationLink("Top Navigation") {
                        TopNavigationGallery()
                    }
                    NavigationLink("Drawer") {
                        DrawerGallery()
                    }
                    NavigationLink("Film Card") {
                        FilmCardGallery()
                    }
                    NavigationLink("Card Item") {
                        CardItemGallery()
                    }
                }

                // 아직 토큰이 아닌 것들의 체험·제안 공간. 디자이너 선택이 확정되면 토큰으로 승격한다.
                Section("Playground") {
                    NavigationLink("Haptic") {
                        HapticGallery()
                    }
                }
            }
            .navigationTitle("CHALLA 디자인 시스템")
        }
    }
}

#Preview {
    RootView()
}
