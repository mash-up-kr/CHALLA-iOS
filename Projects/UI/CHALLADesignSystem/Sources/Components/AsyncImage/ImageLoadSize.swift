import CoreGraphics

/// ``CHALLAAsyncImage``가 어느 크기로 이미지를 받을지 정하는 규칙.
///
/// 배치 크기는 레이아웃이 확정되는 동안 여러 번 바뀐다. 그때마다 로드를 새로 걸면 한 장에
/// 여러 번 요청이 나가고, 취소된 로드는 화면을 갱신하지 않아(#25 결정) 이미지가 늦게 뜨거나
/// 아예 뜨지 않는다. 아래 두 규칙이 요청 수를 한 장당 한 번으로 줄인다.
enum ImageLoadSize {

    /// 측정값을 정수 pt로 올린다. 82.33과 82.67이 모두 83이 되어 같은 요청으로 모인다.
    /// 내림이 아니라 올림인 이유는 표시 크기보다 작게 받으면 확대되면서 흐려지기 때문이다.
    static func quantized(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    /// 이미 받아 둔 이미지가 있을 때 다시 받을지 정한다 — 커진 경우만 받는다.
    ///
    /// 작아지면 뷰가 들고 있는 이미지를 축소해 그린다. 캐시를 조회하지도 않는다.
    /// 다시 받아도 화면이 나아지지 않고, 캐시 키가 `URL + 픽셀 크기`라 같은 사진이 크기마다 따로 저장된다.
    static func needsReload(loaded: CGSize, requested: CGSize) -> Bool {
        requested.width > loaded.width || requested.height > loaded.height
    }
}
