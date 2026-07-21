# @Animatable macro

커스텀 `View` 또는 `Shape`의 속성이 SwiftUI animation에 참여하도록 하려면, 해당 타입이 `Animatable` protocol을 따르게 하세요. protocol requirement인 `animatableData`를 직접 작성하지 않으려면 `@Animatable` macro를 사용하세요:

```swift
@Animatable
struct CoolShape: Shape {
    var width: CGFloat
    var angle: Angle
    // ...
}
```

속성이 `animatableData`에 참여할 수 없는 경우, `@Animatable` macro는 해당 속성에 `@AnimatableIgnored`를 표시하거나 `VectorArithmetic` 또는 `Animatable` protocol을 따르도록 제안하는 error를 발생시킵니다:

```swift
@Animatable
struct CoolShape: Shape {
    var width: CGFloat
    var angle: Angle
    var isOpaque: Bool // ❌ 'animatableData'를 자동으로 synthesize할 수 없습니다.
                       // '@AnimatableIgnored'로 이 속성을 표시하세요.
                       // 이 속성의 타입이 'Animatable' 또는 'VectorArithmetic'을 따르게 하세요.
}
```

이 속성의 변경 사항을 animate해야 한다면, 해당 타입이 `Animatable` 또는 `VectorArithmetic` protocol을 따르게 하세요. 그렇지 않다면 `@AnimatableIgnored` macro를 사용해 이 속성을 `animatableData`에서 제외하세요:

```swift
@Animatable
struct CoolShape: Shape {
    var width: CGFloat
    var angle: Angle
    @AnimatableIgnored var isOpaque: Bool // Bool 속성을 'animatableData'에서 제외
}
```

# `animatableData`를 구현해야 하는 경우

interpolated value가 normalization, clamping, 또는 derived value를 구동하는 것처럼 stored property와 1:1로 대응되지 않는 custom logic이 필요할 때는 명시적인 `animatableData`를 사용하세요.

deployment target >= 26.0인 경우 `AnimatableValues`를 사용하세요:

```swift
// long-running animation에서 값이 무한정 누적되지 않도록 animation 동안 `phase`가
// 0..<2π 범위를 유지해야 하고, 매 tick마다
// `amplitude`가 `maxAmplitude`로 clamp되어야 하는 wave shape.
struct WaveShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat
    var maxAmplitude: CGFloat

    var animatableData: AnimatableValues<CGFloat, CGFloat> {
        get { AnimatableValues(amplitude, phase) }
        set {
            amplitude = min(max(newValue.value.0, 0), maxAmplitude)
            phase = newValue.value.1.truncatingRemainder(dividingBy: 2 * .pi)
        }
    }

    // ...
}
```

이전 deployment target의 경우 `AnimatablePair`를 사용하세요:

```swift
struct WaveShape: Shape {
    var amplitude: CGFloat
    var phase: CGFloat
    var maxAmplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(amplitude, phase) }
        set {
            amplitude = min(max(newValue.first, 0), maxAmplitude)
            phase = newValue.second.truncatingRemainder(dividingBy: 2 * .pi)
        }
    }

    // ...
}
```
