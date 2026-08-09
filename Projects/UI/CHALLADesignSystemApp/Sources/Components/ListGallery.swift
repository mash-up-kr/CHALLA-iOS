import CHALLADesignSystem
import SwiftUI

/// Component > List 검수 화면.
/// `CHALLAListRow`·`CHALLAListSection`이 받을 수 있는 조합을 파라미터 단위로 나열한다.
/// 실제 화면(설정·테마 선택 등) 조립은 Feature 몫이라 여기서 재현하지 않는다.
struct ListGallery: View {

    // 스위치는 눌러봐야 확인되므로 섹션마다 독립된 상태를 쓴다
    // (공유하면 한쪽 조작이 다른 섹션에 나타나 검수를 오인시킨다)
    @State private var accessoryToggleOn = true
    @State private var accessoryToggleOff = false
    @State private var descriptionToggleOn = true
    @State private var descriptionToggleOff = false
    @State private var overflowToggle = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                accessorySection
                descriptionSection
                iconSection
                themeColorSection
                overflowSection
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("List")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// accessory 4종 + 토글. Zeplin 등록 컴포넌트(Arrow·Check)와 설정 화면용 변형(값 표시)을 전수 나열한다.
    private var accessorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Accessory")
            galleryCaption("arrow — List / Arrow")
            CHALLAListSection {
                CHALLAListRow("텍스트", icon: .setting) {}
            }
            galleryCaption("arrow + 값")
            CHALLAListSection {
                CHALLAListRow("텍스트", icon: .palette, accessory: .arrow(value: "레몬에이드")) {}
            }
            galleryCaption("check — List / Check (선택 / 미선택) · 우측 안여백 20")
            CHALLAListSection {
                CHALLAListRow("선택됨", icon: .circle, accessory: .check(isSelected: true)) {}
                CHALLAListRow("선택 안 됨", icon: .circle, accessory: .check(isSelected: false)) {}
            }
            galleryCaption("toggle — 스위치를 눌러야 바뀐다 (이름을 눌러도 안 바뀌어야 정상) · 우측 안여백 20")
            CHALLAListSection {
                CHALLAListRow("켜짐", icon: .bellSimple, isOn: $accessoryToggleOn)
                CHALLAListRow("꺼짐", icon: .bellSimple, isOn: $accessoryToggleOff)
            }
            galleryCaption("empty — 우측 요소 없음 (눌리지 않는 행)")
            CHALLAListSection {
                CHALLAListRow("텍스트", icon: .profile, accessory: .empty)
            }
        }
    }

    /// 설명이 붙으면 행 높이가 52 → 74로 커진다.
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Description")
            galleryCaption("설명 없음 (높이 52) / 설명 있음 (높이 74)")
            CHALLAListSection {
                CHALLAListRow("서비스 알림", isOn: $descriptionToggleOff)
                CHALLAListRow("서비스 알림", description: "인화 대기, 인화 완료 등", isOn: $descriptionToggleOn)
            }
            galleryCaption("설명 + arrow 조합")
            CHALLAListSection {
                CHALLAListRow("계정 관리", description: "로그아웃 · 회원 탈퇴", icon: .profile) {}
            }
        }
    }

    /// icon · iconColor 파라미터.
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Icon")
            galleryCaption("아이콘 없음 / 있음")
            CHALLAListSection {
                CHALLAListRow("아이콘 없는 행") {}
                CHALLAListRow("아이콘 있는 행", icon: .setting) {}
            }
            galleryCaption("iconColor 오버라이드 — 기본은 Label.neutral")
            CHALLAListSection {
                CHALLAListRow("기본 색", icon: .circle) {}
                CHALLAListRow("팔레트 색", icon: .circle, iconColor: CHALLAColor.Primary.pink) {}
            }
        }
    }

    /// themeColor 파라미터 — 값 글자와 스위치 켜짐 배경이 이 색을 따른다.
    private var themeColorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Theme Color")
            galleryCaption("기본값 defaultTheme(레몬에이드) / 오버라이드")
            CHALLAListSection {
                CHALLAListRow("기본", icon: .palette, accessory: .arrow(value: "레몬에이드")) {}
                CHALLAListRow(
                    "오버라이드",
                    icon: .palette,
                    accessory: .arrow(value: "라즈베리"),
                    themeColor: CHALLAColor.Primary.pink
                ) {}
            }
            galleryCaption("스위치 켜짐 배경도 같은 색 — 색 대조용이라 눌러도 꺼지지 않는다")
            CHALLAListSection {
                CHALLAListRow("레몬에이드", icon: .circle, iconColor: CHALLAColor.Primary.yellow,
                              themeColor: CHALLAColor.Primary.yellow, isOn: .constant(true))
                CHALLAListRow("라즈베리", icon: .circle, iconColor: CHALLAColor.Primary.pink,
                              themeColor: CHALLAColor.Primary.pink, isOn: .constant(true))
                CHALLAListRow("사이다", icon: .circle, iconColor: CHALLAColor.Primary.sky,
                              themeColor: CHALLAColor.Primary.sky, isOn: .constant(true))
            }
        }
    }

    /// 고정 높이(52·74)를 넘길 수 있는 입력 — 말줄임으로 잘리고 행이 겹치지 않아야 한다.
    private var overflowSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            galleryTitle("Overflow")
            galleryCaption("긴 제목 — 줄바꿈 없이 말줄임, 아래 행과 겹치지 않아야 한다")
            CHALLAListSection {
                CHALLAListRow("카메라 및 마이크 접근 권한 설정 화면으로 이동", icon: .camera) {}
                CHALLAListRow("알림", icon: .bellSimple) {}
            }
            galleryCaption("긴 제목 + 값 — 제목이 우선이라 값이 먼저 잘린다")
            CHALLAListSection {
                CHALLAListRow(
                    "카메라 및 마이크 접근 권한 설정",
                    icon: .camera,
                    accessory: .arrow(value: "아주 긴 테마 이름 레몬에이드")
                ) {}
            }
            galleryCaption("긴 제목 + 긴 설명 (높이 74 유지)")
            CHALLAListSection {
                CHALLAListRow(
                    "카메라 및 마이크 접근 권한 설정",
                    description: "인화 대기, 인화 완료, 방 초대, 촬영 알림 등 모든 알림",
                    icon: .bellSimple,
                    isOn: $overflowToggle
                )
            }
        }
    }

    private func galleryTitle(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.large.bold)
            .foregroundStyle(CHALLAColor.Label.strong)
    }

    private func galleryCaption(_ text: String) -> some View {
        Text(text)
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Label.alternative)
    }
}

#Preview {
    NavigationStack {
        ListGallery()
    }
}
