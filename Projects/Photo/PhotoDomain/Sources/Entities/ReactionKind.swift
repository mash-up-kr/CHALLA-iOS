import Foundation

/// 사진에 남길 수 있는 리액션 종류. 시안의 10종이 전부이며 순서도 시안의 리액션 바 순서다.
///
/// 이모지 글리프는 화면이 정한다 — 도메인은 어떤 뜻의 리액션인지만 안다.
/// `rawValue`는 서버 리액션 API(`/api/v1/chats/reaction`의 `content`, 자유 문자열)로 그대로 보낸다.
public enum ReactionKind: String, Sendable, Equatable, CaseIterable {
    case heart
    case sparkle
    case thumbsUp
    case poop
    case skull
    case medal
    case question
    case huh
    case loveEyes
    case fire
}
