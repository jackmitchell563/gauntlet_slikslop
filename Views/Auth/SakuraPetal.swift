import SwiftUI

/// A custom shape representing a sakura (cherry blossom) petal
struct SakuraPetal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Scale factors to fit the petal in the rect
        let width = rect.width
        let height = rect.height
        
        // Create a petal shape using bezier curves
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        
        // Top right curve
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.4),
            control1: CGPoint(x: width * 0.7, y: height * 0.1),
            control2: CGPoint(x: width * 0.9, y: height * 0.2)
        )
        
        // Bottom right curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width * 1.1, y: height * 0.6),
            control2: CGPoint(x: width * 0.8, y: height * 0.9)
        )
        
        // Bottom left curve
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.4),
            control1: CGPoint(x: width * 0.2, y: height * 0.9),
            control2: CGPoint(x: width * -0.1, y: height * 0.6)
        )
        
        // Top left curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control1: CGPoint(x: width * 0.1, y: height * 0.2),
            control2: CGPoint(x: width * 0.3, y: height * 0.1)
        )
        
        return path
    }
} 