import ProjectDescription
import ProjectDescriptionHelpers

/// 리소스가 없어 기본값은 static이지만 dynamic으로 지정한다.
/// CHALLADesignSystem(dynamic)과 CHALLAApp이 각각 이 모듈을 링크하는데, static이면
/// 양쪽에 코드가 복사돼 ImageLoadingError 타입이 두 벌 생긴다. 그러면 로더가 던진 취소를
/// 뷰의 catch가 잡지 못해 정상 취소가 실패로 기록되고, 재시도할 계기가 없어 그 자리가
/// 빈 칸으로 남는다 (#90).
let project = Project.makeModule(
    name: "CHALLAImageKit",
    product: .framework,
    hasTests: true
)
