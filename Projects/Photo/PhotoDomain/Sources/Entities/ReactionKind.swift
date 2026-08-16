import Foundation

/// 사진에 남길 수 있는 리액션 종류. 시안의 5종이 전부이며 순서도 시안 순서다.
///
/// 이모지 글리프는 화면이 정한다 — 도메인은 어떤 뜻의 리액션인지만 안다.
public enum ReactionKind: String, Sendable, Equatable, CaseIterable {
    case medal
    case heart
    case poop
    case clap
    case skull
}
