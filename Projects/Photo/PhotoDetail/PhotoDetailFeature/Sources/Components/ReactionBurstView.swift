import PhotoDomain
import SwiftUI

/// 리액션을 남기면 그 이모지가 사진 위에 "와라라락" 흩뿌려지며 팝했다가 사라지는 애니메이션.
///
/// 사진 전체(중앙에 몰리게)에 여러 개가 서로 다른 크기·각도로 튀어나오고 페이드아웃한다.
/// 상위 뷰가 `.id(burst.id)`로 감싸 매번 새로 만들면, 같은 종류를 연달아 눌러도 처음부터 다시 튀고 겹쳐 쌓인다.
/// 순수 표현이라 탭을 가로채지 않는다(`allowsHitTesting(false)`).
struct ReactionBurstView: View {

    let kind: ReactionKind

    /// 위로 떠오르며 각도가 바뀌는 단계.
    @State private var lifted = false
    /// 사라지는 단계.
    @State private var faded = false

    /// 뷰 갱신 시 난수가 재생성되지 않도록 위치와 각도를 유지한다.
    @State private var particles: [Particle] = (0 ..< Metric.count).map { _ in Particle.random() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    kind.emoji.stickerImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: particle.size, height: particle.size)
                        .scaleEffect(lifted ? 1 : Metric.initialScale)
                        .rotationEffect(.degrees(lifted ? particle.baseAngle + particle.spin : particle.baseAngle))
                        .offset(y: lifted ? -particle.rise : 0)
                        .opacity(faded ? 0 : 1)
                        // 떠오름·회전(easeOut)과 페이드(easeIn, 조금 늦게)를 분리해 "나와서 → 올라가며 → 사라짐" 순서를 만든다.
                        .animation(.easeOut(duration: Metric.riseDuration).delay(particle.delay), value: lifted)
                        .animation(.easeIn(duration: Metric.fadeDuration).delay(particle.delay + Metric.fadeDelay), value: faded)
                        .position(x: particle.xRatio * geo.size.width, y: particle.yRatio * geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            lifted = true
            faded = true
        }
    }

    /// 이모지 한 조각의 위치·각도·상승량·시작 지연.
    private struct Particle: Identifiable {
        let id = UUID()
        let xRatio: CGFloat
        let yRatio: CGFloat
        let size: CGFloat
        /// 처음 각도.
        let baseAngle: Double
        /// 떠오르는 동안 바뀌는 각도 변화량.
        let spin: Double
        /// 위로 떠오르는 거리(pt).
        let rise: CGFloat
        let delay: Double

        static func random() -> Particle {
            Particle(
                // 사진 전체에 흩되 가운데로 몰리게 — 두 난수의 평균이 0.5 부근에 모인다.
                xRatio: (.random(in: 0 ... 1) + .random(in: 0.2 ... 0.8)) / 2,
                yRatio: (.random(in: 0 ... 1) + .random(in: 0.2 ... 0.8)) / 2,
                size: Metric.size,
                baseAngle: .random(in: -15 ... 15),
                spin: .random(in: -25 ... 25),
                rise: .random(in: 50 ... 100),
                delay: .random(in: 0 ... 0.18)
            )
        }
    }

    private enum Metric {
        /// 한 번에 튀어나오는 이모지 수.
        static let count = 8
        static let initialScale: CGFloat = 0.4
        /// 붙는 스티커와 같은 크기 (`ReactionSticker` / `PhotoCard`의 stickerSize와 동일).
        static let size: CGFloat = 82
        /// 위로 빠르게 올라가는 시간(초) — 딱딱 튀어 오르는 느낌.
        static let riseDuration: Double = 0.5
        /// 사라지기 시작하는 지연(초) — 다 올라간 뒤.
        static let fadeDelay: Double = 0.45
        /// 사라지는 시간(초) — 서서히가 아니라 바로 사라지게 짧게.
        static let fadeDuration: Double = 0.12
    }
}
