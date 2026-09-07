import Foundation
import RoomDomain
import Testing

@Suite("RoomJoinAnnouncement — 참여 안내 문구 규칙")
struct RoomJoinAnnouncementTests {

    // MARK: - 닉네임 말줄임

    @Test("8자까지는 그대로 둔다")
    func keepsShortNickname() {
        #expect(RoomJoinAnnouncement.nickname("여덟자짜리닉네임") == "여덟자짜리닉네임")
    }

    @Test("8자를 넘으면 8자까지만 남기고 말줄임한다")
    func truncatesLongNickname() {
        #expect(RoomJoinAnnouncement.nickname("아홉자가넘는닉네임입니다") == "아홉자가넘는닉네…")
    }

    @Test("빈 닉네임은 그대로 둔다")
    func keepsEmptyNickname() {
        #expect(RoomJoinAnnouncement.nickname("") == "")
    }

    // MARK: - 주격 조사

    @Test("받침이 있으면 '이'")
    func usesIWhenFinalConsonant() {
        #expect(RoomJoinAnnouncement.subjectParticle(after: "성현") == "이")
        #expect(RoomJoinAnnouncement.subjectParticle(after: "토마토님들") == "이")
    }

    @Test("받침이 없으면 '가'")
    func usesGaWhenNoFinalConsonant() {
        #expect(RoomJoinAnnouncement.subjectParticle(after: "연주") == "가")
        #expect(RoomJoinAnnouncement.subjectParticle(after: "토마토") == "가")
    }

    @Test("말줄임된 닉네임은 말줄임표 앞 글자로 판단한다")
    func ignoresEllipsis() {
        let truncated = RoomJoinAnnouncement.nickname("아홉자가넘는닉네임입니다") // …앞 글자가 '네'
        #expect(RoomJoinAnnouncement.subjectParticle(after: truncated) == "가")
    }

    @Test("숫자로 끝나면 읽는 소리의 받침을 따른다")
    func usesReadingForDigits() {
        #expect(RoomJoinAnnouncement.subjectParticle(after: "유저1") == "이") // 일
        #expect(RoomJoinAnnouncement.subjectParticle(after: "유저2") == "가") // 이
        #expect(RoomJoinAnnouncement.subjectParticle(after: "유저8") == "이") // 팔
        #expect(RoomJoinAnnouncement.subjectParticle(after: "유저9") == "가") // 구
    }

    @Test("판단할 글자가 없으면 '가'로 둔다")
    func fallsBackToGa() {
        #expect(RoomJoinAnnouncement.subjectParticle(after: "") == "가")
    }
}

@Suite("RoomMemberJoined — 내 알림 판별")
struct RoomMemberJoinedTests {

    private func joined(userID: Int64?, nickname: String) -> RoomMemberJoined {
        RoomMemberJoined(roomID: 1, roomTitle: "강릉", userID: userID, nickname: nickname, profileImageURL: nil)
    }

    @Test("userId가 같으면 내 알림이다")
    func mineWhenUserIDMatches() {
        #expect(joined(userID: 7, nickname: "누구든").isMe(userID: 7))
        #expect(!joined(userID: 8, nickname: "연준").isMe(userID: 7))
    }

    @Test("닉네임이 같아도 userId가 다르면 남의 알림이다 (동명이인)")
    func notMineWhenOnlyNicknameMatches() {
        #expect(!joined(userID: 8, nickname: "연준").isMe(userID: 7))
    }

    @Test("userId가 없으면 남의 알림으로 본다 — 알림을 버리지는 않는다")
    func notMineWhenUserIDMissing() {
        #expect(!joined(userID: nil, nickname: "연준").isMe(userID: 7))
    }
}
