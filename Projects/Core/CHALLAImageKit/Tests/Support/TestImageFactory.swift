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

    /// 픽셀 노이즈로 채운 JPEG을 생성한다 — 색 블록 이미지는 JPEG이 극단적으로 압축해
    /// 파일 크기 상한 테스트용 "큰 파일"을 만들 수 없어서, 압축이 안 먹히는 노이즈를 쓴다.
    /// 난수는 고정 시드 LCG라 결과가 결정적이다.
    static func noiseJPEGData(pixelWidth: Int, pixelHeight: Int, quality: CGFloat = 1.0) throws -> Data {
        var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        var seed: UInt64 = 0x5DEE_CE66
        for index in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            pixels[index] = UInt8(truncatingIfNeeded: seed >> 33)
            pixels[index + 1] = UInt8(truncatingIfNeeded: seed >> 41)
            pixels[index + 2] = UInt8(truncatingIfNeeded: seed >> 49)
            pixels[index + 3] = 255
        }

        let context = pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        guard let cgImage = context?.makeImage(),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
        else {
            throw Failure.jpegEncodingFailed
        }
        return data
    }
}
