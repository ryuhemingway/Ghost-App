import AppKit
import CoreText
import Foundation

enum FontRegistry {
    static func registerFonts() {
        let fonts: [(name: String, ext: String)] = [
            ("SourceSerifPro-Regular", "otf"),
            ("SourceSerifPro-Semibold", "otf"),
            ("SourceSerifPro-Bold", "otf"),
            ("HKGrotesk-Regular", "otf"),
            ("HKGrotesk-Medium", "otf"),
            ("HKGrotesk-SemiBold", "otf"),
        ]

        for font in fonts {
            registerFont(named: font.name, extension: font.ext)
        }
    }

    private static func registerFont(named name: String, extension ext: String) {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Fonts"
        ) ?? Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources/Fonts"
        ) ?? Bundle.main.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources/Fonts"
        ) ?? Bundle.main.url(
            forResource: name,
            withExtension: ext
        ) else {
            return
        }

        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let error {
            print("Font registration skipped for \(name): \(error.takeRetainedValue())")
        }
    }
}
