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
        case despised = "Despised"    // -100% to -67%
        case hated = "Hated"          // -66% to -34%
        case disliked = "Disliked"    // -33% to -1%
        case neutral = "Neutral"      // 0%
        case liked = "Liked"          // 1% to 33%
        case adored = "Adored"        // 34% to 66%
        case loved = "Loved"          // 67% to 100%
        
        static func from(percentage: Double) -> RelationshipDescriptor {
            switch percentage {
            case ..<(-66.67): return .despised
            case ..<(-33.33): return .hated
            case ..<0: return .disliked
            case 0: return .neutral
            case ..<33.33: return .liked
            case ..<66.67: return .adored
            default: return .loved
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