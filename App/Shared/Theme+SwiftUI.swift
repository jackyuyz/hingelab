import SwiftUI
import ThemeKit

extension ThemeColor {
    var swiftUI: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension View {
    func hingelabStageBackground(_ theme: any ThemeProviding) -> some View {
        background(theme.color(.stageBackground).swiftUI.ignoresSafeArea())
    }
}
