import UIKit

/// View that shows a typing animation
class TypingIndicatorView: UIView {
    // MARK: - Properties
    
    private var isAnimating = false
    
    // MARK: - UI Components
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var dots: [UIView] = (0..<3).map { _ in
        let dot = UIView()
        dot.backgroundColor = .systemGray3
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        return dot
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(stackView)
        dots.forEach { stackView.addArrangedSubview($0) }
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 44),
            stackView.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        dots.forEach { dot in
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
        }
    }
    
    // MARK: - Animation
    
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1, 1.4, 1]
        animation.keyTimes = [0, 0.5, 1]
        animation.duration = 0.6
        animation.repeatCount = .infinity
        
        for (index, dot) in dots.enumerated() {
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.2
            dot.layer.add(animation, forKey: "typing")
        }
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        
        dots.forEach { $0.layer.removeAllAnimations() }
    }
} 