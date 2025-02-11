import UIKit

/// A circular view that displays relationship status with a gradient progress bar and descriptive text
class RelationshipStatusView: UIView {
    
    // MARK: - Types
    
    private enum Constants {
        static let circleSize: CGFloat = 120  // Increased to accommodate profile image
        static let strokeWidth: CGFloat = 4   // Reduced for a more subtle look
        static let animationDuration: TimeInterval = 0.3
    }
    
    enum RelationshipDescriptor: String {
        case archnemeses = "Archnemeses"  // -100%
        case nemeses = "Nemeses"      // -99.9% to -50%
        case enemies = "Enemies"      // -50% to -30.1%
        case adversaries = "Adversaries"  // -30% to -10.1%
        case acquaintances = "Acquaintances"    // -10% to 10%
        case friends = "Friends"             // 10.1% to 30%
        case closeFriends = "Close Friends"    // 30.1% to 50%
        case partners = "Partners"          // 50.1% to 99.9%
        case soulmates = "Soulmates"      // 100%
        
        static func from(percentage: Double) -> RelationshipDescriptor {
            switch percentage {
            case -100: return .archnemeses
            case -99.9...(-50): return .nemeses
            case -49.9...(-30): return .enemies
            case -29.9...(-10): return .adversaries
            case -9.9...9.9: return .acquaintances
            case 10...29.9: return .friends
            case 30...49.9: return .closeFriends
            case 50...99.9: return .partners
            default: return .soulmates
            }
        }
    }
    
    // MARK: - Properties
    
    /// The relationship value from -1000 to 1000
    var relationshipValue: Int = 0 {
        didSet {
            print("📱 RelationshipStatusView - Received relationship value: \(relationshipValue)")
            updateUI(animated: true)
        }
    }
    
    /// Tracks whether the current progress path is clockwise
    private var isClockwise: Bool = true
    
    // MARK: - UI Components
    
    private let baseCircleLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        setupCircleLayers()
        updateUI(animated: false)
    }
    
    private func setupCircleLayers() {
        // Base circle (gray background)
        baseCircleLayer.fillColor = nil
        baseCircleLayer.strokeColor = UIColor.systemGray4.cgColor
        baseCircleLayer.lineWidth = Constants.strokeWidth
        layer.addSublayer(baseCircleLayer)
        
        // Progress layer (will be masked by gradient)
        progressLayer.fillColor = nil
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineWidth = Constants.strokeWidth
        progressLayer.strokeEnd = 0
        progressLayer.lineCap = .round
        
        // Gradient layer
        gradientLayer.colors = positiveGradientColors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.mask = progressLayer
        layer.addSublayer(gradientLayer)
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Constants.strokeWidth / 2
        
        // Create circle path
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,  // Start from top
            endAngle: 3 * .pi / 2,  // Full circle
            clockwise: true
        )
        
        // Update layer paths and frames
        baseCircleLayer.path = circlePath.cgPath
        progressLayer.path = circlePath.cgPath
        
        // Update gradient layer frame to match the circle bounds
        let gradientFrame = CGRect(
            x: center.x - radius - Constants.strokeWidth/2,
            y: center.y - radius - Constants.strokeWidth/2,
            width: (radius + Constants.strokeWidth/2) * 2,
            height: (radius + Constants.strokeWidth/2) * 2
        )
        gradientLayer.frame = gradientFrame
    }
    
    // MARK: - Updates
    
    private func updateUI(animated: Bool) {
        let percentage = valueToPercentage(relationshipValue)
        let descriptor = RelationshipDescriptor.from(percentage: percentage)
        
        print("📱 RelationshipStatusView - Updating UI with percentage: \(percentage)%, descriptor: \(descriptor.rawValue)")
        
        // Update colors and direction
        let isPositive = percentage >= 0
        let colors = isPositive ? positiveGradientColors : negativeGradientColors
        let startAngle: CGFloat = -.pi / 2  // Top
        let endAngle: CGFloat = startAngle + (isPositive ? 1 : -1) * (2 * .pi)
        
        // Update progress path if direction changed
        if isPositive != isClockwise {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius = min(bounds.width, bounds.height) / 2 - Constants.strokeWidth / 2
            let path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: isPositive
            )
            progressLayer.path = path.cgPath
            isClockwise = isPositive
        }
        
        // Update gradient
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = colors
        animation.duration = animated ? Constants.animationDuration : 0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.colors = colors
        
        if animated {
            gradientLayer.add(animation, forKey: "gradientAnimation")
        }
        
        // Update progress
        let progress = abs(percentage) / 100.0
        let progressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        progressAnimation.fromValue = progressLayer.strokeEnd
        progressAnimation.toValue = progress
        progressAnimation.duration = animated ? Constants.animationDuration : 0
        progressAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.strokeEnd = progress
        
        if animated {
            progressLayer.add(progressAnimation, forKey: "progressAnimation")
        }
        
        // Update accessibility
        accessibilityLabel = "Relationship status: \(descriptor.rawValue), \(String(format: "%.1f", percentage))%"
    }
    
    // MARK: - Helpers
    
    private func valueToPercentage(_ value: Int) -> Double {
        // Convert -1000...1000 to -100...100
        let percentage = Double(value) / 10.0
        print("📱 RelationshipStatusView - Converting \(value) to percentage: \(percentage)%")
        return percentage
    }
    
    private var positiveGradientColors: [CGColor] {
        [
            UIColor.systemGreen.withAlphaComponent(0.8).cgColor,
            UIColor.systemGreen.cgColor
        ]
    }
    
    private var negativeGradientColors: [CGColor] {
        [
            UIColor.systemRed.withAlphaComponent(0.8).cgColor,
            UIColor.systemRed.cgColor
        ]
    }
}

// MARK: - Accessibility

extension RelationshipStatusView {
    override var accessibilityTraits: UIAccessibilityTraits {
        get { .updatesFrequently }
        set { }
    }
} 