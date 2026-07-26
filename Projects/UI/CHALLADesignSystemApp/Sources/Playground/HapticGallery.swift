import CHALLADesignSystem
import SwiftUI

/// Playground > Haptic 체험 화면.
/// iOS가 제공하는 햅틱 종류를 직접 눌러보고 화면·상황별로 어떤 진동을 쓸지 고르기 위한 제안 도구다.
/// 여기서 선택이 확정되면 CHALLAHaptic 토큰으로 승격한다 (별도 이슈).
///
/// ⚠️ 시뮬레이터는 진동을 재생하지 못한다 — 실기기에서 확인할 것.
struct HapticGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                notice
                hapticSection(
                    "Impact — 물리적 충돌감",
                    caption: "버튼 탭·셔터처럼 무언가를 '건드린' 순간에 쓴다",
                    items: [
                        ("light — 가볍게 톡", .impact(weight: .light)),
                        ("medium — 중간", .impact(weight: .medium)),
                        ("heavy — 묵직하게", .impact(weight: .heavy)),
                        ("soft — 뭉툭하고 부드럽게", .impact(flexibility: .soft)),
                        ("rigid — 짧고 단단하게", .impact(flexibility: .rigid))
                    ]
                )
                hapticSection(
                    "Notification — 결과 알림",
                    caption: "작업이 끝난 순간에 쓴다 (예: 인화 완료 / 업로드 실패)",
                    items: [
                        ("success — 성공 (두 번 통통)", .success),
                        ("warning — 주의", .warning),
                        ("error — 실패 (세 번 드르륵)", .error)
                    ]
                )
                hapticSection(
                    "Selection — 값 변경",
                    caption: "피커를 돌리거나 옵션을 넘길 때 틱틱 걸리는 느낌",
                    items: [
                        ("selection — 틱", .selection)
                    ]
                )
            }
            .padding(20)
        }
        .background(CHALLAColor.Background.surface)
        .navigationTitle("Haptic")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notice: some View {
        Text("시뮬레이터에서는 진동이 재생되지 않아요 — 실기기에서 확인해주세요")
            .challaFont(.body.xsmall.bold)
            .foregroundStyle(CHALLAColor.Status.cautionary)
    }

    private func hapticSection(
        _ title: String,
        caption: String,
        items: [(name: String, feedback: SensoryFeedback)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .challaFont(.body.large.bold)
                .foregroundStyle(CHALLAColor.Label.strong)
            Text(caption)
                .challaFont(.body.xsmall.bold)
                .foregroundStyle(CHALLAColor.Label.alternative)
            ForEach(items, id: \.name) { item in
                HapticButton(title: item.name, feedback: item.feedback)
            }
        }
    }
}

/// 누를 때마다 지정된 햅틱을 재생하는 버튼.
/// sensoryFeedback은 trigger 값이 "바뀔 때" 재생되므로, 탭마다 카운터를 올려 트리거한다.
private struct HapticButton: View {
    let title: String
    let feedback: SensoryFeedback

    @State private var tapCount = 0

    var body: some View {
        HStack {
            CHALLATextButton(title, variant: .neutral, size: .medium) {
                tapCount += 1
            }
            .sensoryFeedback(feedback, trigger: tapCount)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        HapticGallery()
    }
}
