import UIKit

/// 테스트 픽스처 이미지를 런타임에 생성한다.
/// 번들 리소스를 쓰지 않으므로 테스트 타깃에 리소스 설정이 필요 없고, 크기·내용이 결정적이다.
enum TestImageFactory {

    enum Failure: Error {
        case jpegEncodingFailed
    }

    /// 지정 픽셀 크기의 JPEG 데이터를 생성한다 (scale 1 → 포인트 == 픽셀).
    /// 단색이면 JPEG 특성상 극단적으로 압축되므로, 실제 사진에 가깝게 색 블록을 섞는다.
    static func jpegData(pixelWidth: Int, pixelHeight: Int) throws -> Data {
        let size = CGSize(width: pixelWidth, height: pixelHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height / 2))
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: size.width / 2, y: size.height / 2,
                                width: size.width / 2, height: size.height / 2))
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw Failure.jpegEncodingFailed
        }
        return data
    }
}
