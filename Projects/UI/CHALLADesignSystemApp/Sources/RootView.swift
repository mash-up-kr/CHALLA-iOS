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
                    NavigationLink("AsyncImage") {
                        AsyncImageGallery()
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
                    NavigationLink("Main Background") {
                        MainBackgroundGallery()
                    }
                    NavigationLink("Photo Count Selector") {
                        PhotoCountSelectorGallery()
                    }
                    NavigationLink("List") {
                        ListGallery()
                    }
                    NavigationLink("Film Card") {
                        FilmCardGallery()
                    }
                    NavigationLink("Card Item") {
                        CardItemGallery()
                    }
                    NavigationLink("Print Card") {
                        PrintCardGallery()
                    }
                    NavigationLink("Profile Bar") {
                        ProfileBarGallery()
                    }
                    NavigationLink("Loading Dots") {
                        LoadingDotsGallery()
                    }
                    NavigationLink("Toast") {
                        ToastGallery()
                    }
                    NavigationLink("SnackBar") {
                        SnackBarGallery()
                    }
                    NavigationLink("Tooltip") {
                        TooltipGallery()
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
