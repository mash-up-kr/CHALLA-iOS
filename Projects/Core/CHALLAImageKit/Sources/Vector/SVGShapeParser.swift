import CoreGraphics
import Foundation

/// ``SVGShapeParser/parse(_:)`` 실패 사유.
public enum VectorDrawingError: Error, Sendable, Equatable {

    case invalidEncoding

    /// `viewBox`도 `width`/`height`도 읽지 못해 좌표계를 정할 수 없다.
    case missingSize

    case noShapes
}

/// SVG 바이트를 ``VectorDrawing``으로 읽는다.
///
/// 서버 스티커가 쓰는 좁은 부분집합만 다룬다 — `<rect>`와 직선 명령(M·L·H·V·Z)뿐인 `<path>`.
/// 문법이 이만큼 좁아 `XMLParser` 대신 문자 스캔으로 처리한다(전체를 메모리에 올리는 수 KB 파일이다).
/// 모르는 명령(곡선 등)이 섞이면 **그 서브패스만** 버려서, 도안이 바뀌어도 화면이 통째로 비지 않게 한다.
public struct SVGShapeParser: Sendable {

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    public func parse(_ data: Data) throws -> VectorDrawing {
        guard let source = String(data: data, encoding: .utf8) else {
            throw VectorDrawingError.invalidEncoding
        }

        let tags = Self.tags(in: source[...])

        guard
            let svg = tags.first(where: { $0.name == "svg" }),
            let viewBox = Self.viewBox(in: svg.body)
        else {
            throw VectorDrawingError.missingSize
        }

        var subpaths: [[CGPoint]] = []

        for tag in tags {
            switch tag.name {
            case "rect":
                if let rectangle = Self.rectangle(in: tag.body) {
                    subpaths.append(rectangle)
                }

            case "path":
                if let commands = Self.attribute("d", in: tag.body) {
                    subpaths.append(contentsOf: Self.subpaths(fromPathData: commands))
                }

            default:
                break
            }
        }

        guard !subpaths.isEmpty else {
            throw VectorDrawingError.noShapes
        }

        // viewBox의 min-x/min-y는 좌표 원점 이동이다. VectorDrawing은 원점 (0,0)만 다루므로 여기서 흡수한다.
        if viewBox.origin != .zero {
            subpaths = subpaths.map { points in
                points.map {
                    CGPoint(
                        x: $0.x - viewBox.origin.x,
                        y: $0.y - viewBox.origin.y
                    )
                }
            }
        }

        return VectorDrawing(size: viewBox.size, subpaths: subpaths)
    }
}

// MARK: - Tag Scanning

private extension SVGShapeParser {

    struct Tag {
        let name: Substring
        /// 여는 태그에서 이름 뒤 속성 부분.
        let body: Substring
    }

    /// 그 안의 도형이 화면에 그려지지 않는 컨테이너.
    ///
    /// 특히 `clipPath`는 viewBox 전체를 덮는 `<rect>`를 담고 있어서, 이걸 그리면
    /// nonzero 감김 때문에 스티커가 통짜 사각형이 된다.
    static let ignoredContainers: Set<String> = ["defs", "clipPath", "mask", "symbol"]

    /// 여는 태그를 문서 순서대로 훑는다. 중첩·닫는 태그는 도형 순서에 영향이 없어 무시한다.
    static func tags(in source: Substring) -> [Tag] {
        var result: [Tag] = []
        var index = source.startIndex

        while let open = source[index...].firstIndex(of: "<") {
            var cursor = source.index(after: open)

            guard cursor < source.endIndex else { break }

            // 닫는 태그·주석·선언은 도형이 아니다.
            guard source[cursor].isLetter else {
                index = cursor
                continue
            }

            let nameStart = cursor

            while cursor < source.endIndex, source[cursor].isLetter || source[cursor].isNumber || source[cursor] == "-" {
                cursor = source.index(after: cursor)
            }

            let name = source[nameStart ..< cursor]

            guard let close = source[cursor...].firstIndex(of: ">") else { break }

            let body = source[cursor ..< close]
            index = source.index(after: close)

            let isSelfClosing = body.last == "/"

            if !isSelfClosing, ignoredContainers.contains(String(name)) {
                guard let end = source.range(of: "</\(name)", range: index ..< source.endIndex) else { break }

                index = end.upperBound
                continue
            }

            result.append(Tag(name: name, body: body))
        }

        return result
    }

    /// 태그 속성값을 꺼낸다. 이름 앞이 공백인 것만 인정해 `stroke-width`가 `width`로 잡히지 않게 한다.
    static func attribute(_ name: String, in body: Substring) -> Substring? {
        var searchStart = body.startIndex

        while let found = body.range(of: name, range: searchStart ..< body.endIndex) {
            searchStart = found.upperBound

            if found.lowerBound > body.startIndex,
               !body[body.index(before: found.lowerBound)].isWhitespace {
                continue
            }

            var cursor = found.upperBound

            while cursor < body.endIndex, body[cursor].isWhitespace {
                cursor = body.index(after: cursor)
            }

            guard cursor < body.endIndex, body[cursor] == "=" else { continue }

            cursor = body.index(after: cursor)

            while cursor < body.endIndex, body[cursor].isWhitespace {
                cursor = body.index(after: cursor)
            }

            guard cursor < body.endIndex, body[cursor] == "\"" || body[cursor] == "'" else { continue }

            let quote = body[cursor]
            let valueStart = body.index(after: cursor)

            guard let valueEnd = body[valueStart...].firstIndex(of: quote) else { return nil }

            return body[valueStart ..< valueEnd]
        }

        return nil
    }

    static func number(_ text: Substring?) -> CGFloat? {
        guard let text else { return nil }

        // "12px" 처럼 단위가 붙어도 앞의 수만 읽는다.
        var scanner = NumberScanner(Array(text))
        return scanner.next()
    }

    static func viewBox(in body: Substring) -> CGRect? {
        if let box = attribute("viewBox", in: body) {
            var scanner = NumberScanner(Array(box))
            let values = scanner.remaining()

            if values.count >= 4, values[2] > 0, values[3] > 0 {
                return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
            }
        }

        guard
            let width = number(attribute("width", in: body)),
            let height = number(attribute("height", in: body)),
            width > 0,
            height > 0
        else {
            return nil
        }

        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    static func rectangle(in body: Substring) -> [CGPoint]? {
        guard
            let width = number(attribute("width", in: body)),
            let height = number(attribute("height", in: body)),
            width > 0,
            height > 0
        else {
            return nil
        }

        let originX = number(attribute("x", in: body)) ?? 0
        let originY = number(attribute("y", in: body)) ?? 0

        return [
            CGPoint(x: originX, y: originY),
            CGPoint(x: originX + width, y: originY),
            CGPoint(x: originX + width, y: originY + height),
            CGPoint(x: originX, y: originY + height)
        ]
    }
}

// MARK: - Path Data

private extension SVGShapeParser {

    /// `d` 속성을 닫힌 다각형 목록으로 읽는다.
    ///
    /// 지원 명령은 M·L·H·V·Z(대문자 절대, 소문자 상대)뿐이다. 그 밖의 명령이 나오면 진행 중인
    /// 서브패스를 버리고, 다음 서브패스(M 또는 Z 이후)부터 다시 담는다.
    static func subpaths(fromPathData data: Substring) -> [[CGPoint]] {
        var scanner = NumberScanner(Array(data))
        var accumulator = SubpathAccumulator()

        while let command = scanner.nextCommand() {
            switch command {
            case "M", "m":
                accumulator.move(isAbsolute: command == "M", from: &scanner)

            case "L", "l":
                accumulator.appendLines(isAbsolute: command == "L", from: &scanner)

            case "H", "h":
                accumulator.appendHorizontalLines(isAbsolute: command == "H", from: &scanner)

            case "V", "v":
                accumulator.appendVerticalLines(isAbsolute: command == "V", from: &scanner)

            case "Z", "z":
                accumulator.close()

            default:
                // 곡선 등 모르는 명령. 인자를 흘려보내고 이 서브패스만 버린다.
                _ = scanner.remaining()
                accumulator.drop()
            }
        }

        accumulator.flush()

        return accumulator.result
    }

    /// 명령을 훑는 동안의 서브패스 누적 상태.
    ///
    /// 버려진 서브패스(``drop()``)는 ``flush()`` 시점에 결과에서 빠지고, 그 다음 서브패스부터 다시 담긴다.
    struct SubpathAccumulator {

        // MARK: - Properties

        private(set) var result: [[CGPoint]] = []

        private var points: [CGPoint] = []
        private var current = CGPoint.zero
        private var start = CGPoint.zero
        private var isDropped = false

        // MARK: - Methods

        mutating func flush() {
            defer {
                points = []
                isDropped = false
            }

            guard !isDropped else { return }

            // 마지막 점이 시작점과 같으면 closeSubpath와 겹치므로 버린다.
            var closed = points
            if let first = closed.first, let last = closed.last, first == last, closed.count > 1 {
                closed.removeLast()
            }

            guard closed.count >= 3 else { return }

            result.append(closed)
        }

        mutating func move(isAbsolute: Bool, from scanner: inout NumberScanner) {
            flush()

            guard let first = scanner.nextPoint() else { return }

            current = isAbsolute ? first : CGPoint(x: current.x + first.x, y: current.y + first.y)
            start = current
            points = [current]

            // M 뒤에 이어지는 좌표쌍은 SVG 규격상 암묵적 L이다.
            appendLines(isAbsolute: isAbsolute, from: &scanner)
        }

        mutating func appendLines(isAbsolute: Bool, from scanner: inout NumberScanner) {
            while let next = scanner.nextPoint() {
                current = isAbsolute ? next : CGPoint(x: current.x + next.x, y: current.y + next.y)
                points.append(current)
            }
        }

        mutating func appendHorizontalLines(isAbsolute: Bool, from scanner: inout NumberScanner) {
            while let value = scanner.next() {
                current = CGPoint(x: isAbsolute ? value : current.x + value, y: current.y)
                points.append(current)
            }
        }

        mutating func appendVerticalLines(isAbsolute: Bool, from scanner: inout NumberScanner) {
            while let value = scanner.next() {
                current = CGPoint(x: current.x, y: isAbsolute ? value : current.y + value)
                points.append(current)
            }
        }

        mutating func close() {
            flush()
            current = start
        }

        mutating func drop() {
            isDropped = true
        }
    }
}

// MARK: - Number Scanner

/// 숫자와 명령 문자만 구분하는 최소 스캐너. 공백·쉼표는 구분자로 흘려보낸다.
private struct NumberScanner {

    private let characters: [Character]
    private var index = 0

    init(_ characters: [Character]) {
        self.characters = characters
    }

    /// 다음 명령 문자. 숫자가 남아 있어도 명령을 만날 때까지 건너뛰지 않고 nil을 돌려준다.
    mutating func nextCommand() -> Character? {
        skipSeparators()

        guard index < characters.count, characters[index].isLetter else { return nil }

        defer { index += 1 }
        return characters[index]
    }

    mutating func next() -> CGFloat? {
        skipSeparators()

        let begin = index

        if index < characters.count, characters[index] == "+" || characters[index] == "-" {
            index += 1
        }

        var hasDigits = false

        while index < characters.count, characters[index].isNumber {
            index += 1
            hasDigits = true
        }

        if index < characters.count, characters[index] == "." {
            index += 1

            while index < characters.count, characters[index].isNumber {
                index += 1
                hasDigits = true
            }
        }

        guard hasDigits else {
            index = begin
            return nil
        }

        if index < characters.count, characters[index] == "e" || characters[index] == "E" {
            let exponentStart = index
            index += 1

            if index < characters.count, characters[index] == "+" || characters[index] == "-" {
                index += 1
            }

            var hasExponentDigits = false

            while index < characters.count, characters[index].isNumber {
                index += 1
                hasExponentDigits = true
            }

            if !hasExponentDigits {
                index = exponentStart
            }
        }

        guard let value = Double(String(characters[begin ..< index])) else {
            index = begin
            return nil
        }

        return CGFloat(value)
    }

    mutating func nextPoint() -> CGPoint? {
        let begin = index

        guard let pointX = next() else { return nil }

        guard let pointY = next() else {
            index = begin
            return nil
        }

        return CGPoint(x: pointX, y: pointY)
    }

    /// 다음 명령 문자를 만날 때까지의 숫자들.
    mutating func remaining() -> [CGFloat] {
        var values: [CGFloat] = []

        while let value = next() {
            values.append(value)
        }

        return values
    }

    private mutating func skipSeparators() {
        while index < characters.count, characters[index].isWhitespace || characters[index] == "," {
            index += 1
        }
    }
}
