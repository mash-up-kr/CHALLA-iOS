import Foundation

/// 커스텀 폰트(SUIT/Dirtyline)를 iOS에 등록한다. 앱 진입점(@main)의 init에서 한 번 호출한다.
public enum CHALLAFontRegister {
    public static func register() {
        CHALLADesignSystemFontFamily.registerAllCustomFonts()
    }
}
