import SwiftUI

struct DashedBorderModifier: ViewModifier {
    var color: Color
    var lineWidth: CGFloat
    var cornerRadius: CGFloat
    var dash: [CGFloat]

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, dash: dash))
                .foregroundStyle(color)
        )
    }
}

extension View {
    func dashedBorder(
        color: Color,
        lineWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = 16,
        dash: [CGFloat] = [8, 5]
    ) -> some View {
        modifier(DashedBorderModifier(color: color, lineWidth: lineWidth, cornerRadius: cornerRadius, dash: dash))
    }
}
