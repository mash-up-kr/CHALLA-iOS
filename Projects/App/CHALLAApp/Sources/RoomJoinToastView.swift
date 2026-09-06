import CHALLADesignSystem
import CHALLAImageKit
import RoomDomain
import SwiftUI

/// 방 참여 안내 토스트 — "{닉네임}이/가 {방 이름}에 참여했어요."
///
/// 문구를 통짜 문자열로 만들지 않는 이유: 말줄임 대상이 방 이름 하나뿐이다.
/// 한 덩어리로 두면 폭이 모자랄 때 끝의 "에 참여했어요."가 먼저 잘린다.
struct RoomJoinToastView: View {

    let joined: RoomMemberJoined

    private var nickname: String {
        RoomJoinAnnouncement.nickname(joined.nickname)
    }

    private var particle: String {
        RoomJoinAnnouncement.subjectParticle(after: nickname)
    }

    var body: some View {
        CHALLAToastSurface {
            HStack(spacing: CHALLAToastMetric.contentSpacing) {
                avatar
                message
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(nickname)\(particle) \(joined.roomTitle)에 참여했어요.")
        .accessibilityHint("두 번 탭하면 그 방으로 이동해요.")
        .onAppear {
            AccessibilityNotification.Announcement(
                "\(nickname)\(particle) \(joined.roomTitle)에 참여했어요."
            ).post()
        }
    }

    private var avatar: some View {
        CHALLAAvatar(photo: nil, size: CHALLAToastMetric.avatarSize)
            .overlay {
                if let url = joined.profileImageURL {
                    CHALLAAsyncImage(url: url)
                        .frame(width: CHALLAToastMetric.avatarSize, height: CHALLAToastMetric.avatarSize)
                        .clipShape(Circle())
                }
            }
    }

    /// 방 이름만 남는 폭에 맞춰 줄고, 앞뒤 문구는 항상 온전히 보인다.
    private var message: some View {
        HStack(spacing: 0) {
            Text("\(nickname)\(particle) ")
                .layoutPriority(1)
            Text(joined.roomTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("에 참여했어요.")
                .layoutPriority(1)
        }
        .challaFont(.body.small.medium)
        .foregroundStyle(CHALLAColor.Label.normal)
        .lineLimit(1)
    }
}

#Preview {
    VStack(spacing: 12) {
        RoomJoinToastView(joined: RoomMemberJoined(
            roomID: 1,
            roomTitle: "강릉 여행",
            nickname: "연준",
            profileImageURL: nil
        ))
        RoomJoinToastView(joined: RoomMemberJoined(
            roomID: 2,
            roomTitle: "아주아주 긴 방 이름이라 잘려야 하는 방",
            nickname: "아홉자가넘는닉네임입니다",
            profileImageURL: nil
        ))
    }
    .padding(40)
    .background(CHALLAColor.Background.surface)
}
