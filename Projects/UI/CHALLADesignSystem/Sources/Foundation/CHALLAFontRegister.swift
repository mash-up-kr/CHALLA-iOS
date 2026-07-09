import Foundation

/// CHALLA 커스텀 폰트(SUIT/Dirtyline)를 iOS에 등록한다.
/// 폰트를 사용하는 앱(검수앱/실앱)은 진입점(@main)의 init에서 `register()`를 한 번 호출해야 한다.
/// (내부적으로 Tuist가 생성한 registerAllCustomFonts()를 감싼다.)
public enum CHALLAFontRegister {
    public static func register() {
        CHALLADesignSystemFontFamily.registerAllCustomFonts()
    }
}
