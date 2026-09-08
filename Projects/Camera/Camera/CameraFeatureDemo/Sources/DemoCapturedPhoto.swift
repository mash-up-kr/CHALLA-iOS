import Foundation
import UIKit

/// 촬영 연출 시나리오(`--state capturing`)가 뷰파인더에 고정해 보여줄 촬영본 대역.
///
/// 시뮬레이터에는 카메라가 없어 실제 촬영본을 만들 수 없다. 라이브 프리뷰(단색 그라디언트)와
/// 확실히 구분되는 그림을 그려 둬야 "연출 중에는 찍힌 한 장만 남는다"를 눈으로 확인할 수 있다.
enum DemoCapturedPhoto {

    static let jpegData: Data = {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.36, green: 0.42, blue: 0.30, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor(white: 1, alpha: 0.16).setFill()
            for row in 0 ..< 8 where row.isMultiple(of: 2) {
                context.fill(CGRect(x: 0, y: CGFloat(row) * 150, width: size.width, height: 150))
            }

            let title = "촬영본" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 120),
                .foregroundColor: UIColor.white
            ]
            let bounds = title.size(withAttributes: attributes)
            title.draw(
                at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2),
                withAttributes: attributes
            )
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }()
}
