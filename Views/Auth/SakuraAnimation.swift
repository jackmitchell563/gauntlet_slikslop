import SwiftUI

/// A view that displays animated sakura petals in a helix pattern
struct SakuraAnimation: View {
    // MARK: - Properties
    
    /// Number of petals to display
    private let petalCount = 50
    
    /// Animation states for each petal
    @State private var petals: [PetalState]
    
    /// Timer for continuous animation
    @State private var timer: Timer?
    
    /// Time since animation started
    @State private var elapsedTime: Double = 0
    
    /// Whether all petals have reached their final orbit
    @State private var isSettled = false
    
    /// Opacity of the logo
    @State private var logoOpacity: Double = 0
    
    /// Logo scale (1.0 is normal size)
    @State private var logoScale: Double = 1.0
    
    /// Orbit expansion multiplier
    @State private var orbitExpansion: Double = 1.0
    
    /// Logo vertical offset
    @State private var logoOffset: CGFloat = 0
    
    /// Callback for when logo animation completes
    let onLogoAnimationComplete: () -> Void
    
    /// Additional opacity control for logo only
    let logoOpacityOverride: Double
    
    // MARK: - Initialization
    
    init(logoOpacityOverride: Double = 1.0, onLogoAnimationComplete: @escaping () -> Void) {
        self.logoOpacityOverride = logoOpacityOverride
        self.onLogoAnimationComplete = onLogoAnimationComplete
        _petals = State(initialValue: (0..<petalCount).map { PetalState(index: $0) })
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            // Main container
            Color.clear // Use clear background to fill GeometryReader
                .overlay {
                    // Petals Container (stays centered)
                    ZStack {
                        ForEach(petals.indices, id: \.self) { index in
                            if petals[index].isActive {
                                PetalView(state: $petals[index])
                                    .position(
                                        x: geometry.size.width / 2 + petals[index].radius * cos(petals[index].angle),
                                        y: geometry.size.height / 2 + petals[index].radius * sin(petals[index].angle)
                                    )
                            }
                        }
                    }
                }
                .overlay {
                    // Logo Container (moves independently)
                    VStack {
                        Spacer()
                        Text("SlikSlop")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.customText)
                            .opacity(logoOpacity * logoOpacityOverride)
                            .scaleEffect(logoScale)
                        Spacer()
                    }
                    .offset(y: logoOffset)
                }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        // Update petal positions 60 times per second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            elapsedTime += 1.0/60.0
            
            var allPetalsSettled = true
            
            for index in petals.indices {
                // Only move petals that are ready
                if petals[index].readyToMove {
                    // Update angle (clockwise rotation with current speed multiplier)
                    petals[index].angle += petals[index].speed * 0.02 * petals[index].speedMultiplier
                    
                    // Decay speed multiplier towards 1.0
                    if petals[index].speedMultiplier > 1.0 {
                        petals[index].speedMultiplier = max(1.0, petals[index].speedMultiplier * 0.97)
                    }
                    
                    // Calculate target radius based on index and current orbit expansion
                    let targetRadius = Double(200 + index * 3) * orbitExpansion
                    
                    // If not at target radius, move outward with decay
                    if petals[index].radius < targetRadius {
                        let remainingDistance = targetRadius - petals[index].radius
                        let speed = max(0.1, remainingDistance * 0.05) // Decay speed as we approach target
                        petals[index].radius += speed
                        allPetalsSettled = false
                    }
                } else {
                    allPetalsSettled = false
                }
            }
            
            // If all petals have settled and logo hasn't started fading in
            if allPetalsSettled && !isSettled {
                isSettled = true
                // Animate logo fade in
                withAnimation(.easeIn(duration: 1.0)) {
                    logoOpacity = 1.0
                }
                // First notify about logo completion (triggers login elements)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Move logo up, shrink it, and expand orbit simultaneously
                    withAnimation(.easeOut(duration: 0.5)) {
                        logoOffset = -200
                        logoScale = 0.85 // Shrink to 75% of original size
                        orbitExpansion = 1.5 // Expand orbit by 50%
                    }
                    onLogoAnimationComplete()
                }
            }
        }
    }
}

// MARK: - Petal View

/// A view representing a single sakura petal
private struct PetalView: View {
    @Binding var state: PetalState
    
    var body: some View {
        SakuraPetal()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#ffc9ea").opacity(1.0),
                        Color(hex: "#ffc9ea").opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 15, height: 20)
            .rotationEffect(.degrees(state.rotation))
            .opacity(state.opacity)
            .onAppear {
                // First fade in the petal
                withAnimation(.easeIn(duration: 0.1)) {
                    state.opacity = 1.0
                }
                
                // After fade-in, start the rotation and mark as ready to move
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    state.readyToMove = true
                    withAnimation(.linear(duration: state.rotationDuration).repeatForever(autoreverses: false)) {
                        state.rotation += 360
                    }
                }
            }
    }
}

// MARK: - Petal State

/// Represents the state of a single petal
struct PetalState {
    /// Current angle in radians
    var angle: Double
    /// Distance from center
    var radius: Double
    /// Base movement speed
    var speed: Double
    /// Current speed multiplier (for initial burst)
    var speedMultiplier: Double
    /// Rotation angle in degrees
    var rotation: Double
    /// Duration of one full rotation
    var rotationDuration: Double
    /// Opacity of the petal
    var opacity: Double
    /// Whether the petal is active
    var isActive: Bool
    /// Whether the petal has finished fading in
    var readyToMove: Bool
    
    init(index: Int) {
        // Random starting angle
        angle = Double.random(in: 0...(2 * .pi))
        // Start at center
        radius = 0
        // Random movement speed (halved from original 0.5...1.5)
        speed = Double.random(in: 0.25...0.75)
        // Start with 20x speed
        speedMultiplier = 20.0
        // Random initial rotation
        rotation = Double.random(in: 0...360)
        // Random rotation duration
        rotationDuration = Double.random(in: 2...4)
        // Start fully transparent
        opacity = 0
        // Start active immediately
        isActive = true
        // Start not ready to move
        readyToMove = false
    }
} 
