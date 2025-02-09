import UIKit
import SwiftUI
import Combine
import FirebaseAuth

/// Main view controller for the login screen
class LoginViewController: UIViewController {
    // MARK: - Properties
    
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    private var completion: ((Bool) -> Void)?
    
    // Override status bar style
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - UI Components
    
    private lazy var containerView: UIHostingController<LoginContentView> = {
        let contentView = LoginContentView { [weak self] success in
            self?.handleAuthResult(success)
        }
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        return hostingController
    }()
    
    // MARK: - Lifecycle
    
    init(completion: ((Bool) -> Void)? = nil) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Add hosting controller
        addChild(containerView)
        view.addSubview(containerView.view)
        containerView.didMove(toParent: self)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.view.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Auth Handling
    
    private func handleAuthResult(_ success: Bool) {
        if success {
            completion?(true)
            dismiss(animated: true)
        } else {
            completion?(false)
        }
    }
}

// MARK: - Login Content View

/// SwiftUI view containing the login form
private struct LoginContentView: View {
    // MARK: - Properties
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""  // For sign up
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var showLoginElements = false
    @FocusState private var focusedField: Field?
    
    // Add offset state for logo movement
    @State private var logoOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0
    @State private var logoOpacityOverride: Double = 1.0  // New state for logo opacity
    
    let onComplete: (Bool) -> Void
    
    private enum Field {
        case email, password, confirmPassword
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with Sakura Animation
                SakuraAnimation(logoOpacityOverride: logoOpacityOverride) { 
                    // Logo animation completed, wait 1 second then show login elements
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showLoginElements = true
                        }
                    }
                }
                .opacity(backgroundOpacity)
                .allowsHitTesting(false)  // Prevent animation from blocking interaction
                
                VStack {
                    Spacer()
                    
                    // Sign In View
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            if showSignUp {
                                // Header for Sign Up
                                VStack(spacing: 8) {
                                    Text("Create Account")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.customText)
                                    
                                    Text("Join SlikSlop today")
                                        .font(.subheadline)
                                        .foregroundColor(.customSubtitle)
                                }
                                .padding(.bottom, 8)
                            }
                            
                            // Email field
                            AuthTextField(
                                title: "Email",
                                placeholder: "Enter your email",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                            .focused($focusedField, equals: .email)
                            
                            // Password field
                            AuthTextField(
                                title: showSignUp ? "Create Password" : "Password",
                                placeholder: showSignUp ? "Create a password" : "Enter your password",
                                text: $password,
                                isSecure: true,
                                textContentType: showSignUp ? .newPassword : .password
                            )
                            .focused($focusedField, equals: .password)
                            
                            // Confirm Password field (Sign Up only)
                            if showSignUp {
                                AuthTextField(
                                    title: "Confirm Password",
                                    placeholder: "Confirm your password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    textContentType: .newPassword
                                )
                                .focused($focusedField, equals: .confirmPassword)
                            }
                            
                            // Error message
                            AuthErrorLabel(error: errorMessage)
                        }
                        
                        VStack(spacing: 12) {
                            // Main Button (Sign In/Up)
                            AuthButton(
                                title: showSignUp ? "Sign Up" : "Sign In",
                                isLoading: isLoading
                            ) {
                                if showSignUp {
                                        await signUp()
                                } else {
                                        await signIn()
                                }
                            }
                            
                            if !showSignUp {
                                // Forgot Password button (Login only)
                                AuthSecondaryButton(title: "Forgot Password?") {
                                    showForgotPassword = true
                                }
                            }
                            
                            // Toggle Sign In/Up button
                            HStack {
                                Text(showSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.customSubtitle)
                                
                                AuthSecondaryButton(title: showSignUp ? "Sign In" : "Sign Up") {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        showSignUp.toggle()
                                        // Clear fields and errors when switching
                                        email = ""
                                        password = ""
                                        confirmPassword = ""
                                        errorMessage = nil
                                        focusedField = nil
                                    }
                                    // Animate logo opacity
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        logoOpacityOverride = showSignUp ? 0.0 : 1.0
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)
                    .opacity(showLoginElements ? 1 : 0)
                    .offset(y: showLoginElements ? 60 : 80)
                    
                    Spacer()
                        .frame(height: 240)
                }
                .contentShape(Rectangle()) // Make entire view tappable
                .onTapGesture {
                    focusedField = nil // Unfocus on tap outside
                }
            }
        }
        .background(Color.customBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showForgotPassword) {
            Text("Forgot Password") // TODO: Implement ForgotPasswordView
        }
        .onChange(of: focusedField) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                backgroundOpacity = focusedField == nil ? 1.0 : 0.0
            }
        }
    }
    
    // MARK: - Actions
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await AuthService.shared.signIn(email: email, password: password)
            print("✅ LoginView - User signed in successfully: \(result.user.uid)")
            onComplete(true)
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
            onComplete(false)
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            onComplete(false)
        }
        
        isLoading = false
    }
    
    private func signUp() async {
        guard validateSignUpInputs() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await AuthService.shared.signUp(email: email, password: password)
            print("✅ SignUpView - User created successfully: \(result.user.uid)")
            onComplete(true)
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
            onComplete(false)
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            onComplete(false)
        }
        
        isLoading = false
    }
    
    private func validateSignUpInputs() -> Bool {
        // Validate email
        if email.isEmpty {
            errorMessage = "Please enter your email"
            return false
        }
        
        // Validate password
        if password.isEmpty {
            errorMessage = "Please enter a password"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        // Validate password confirmation
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
}

// MARK: - Sign Up View

/// SwiftUI wrapper for SignUpViewController
struct SignUpView: UIViewControllerRepresentable {
    var onComplete: ((Bool) -> Void)?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let signUpVC = SignUpViewController(completion: onComplete)
        let navController = UINavigationController(rootViewController: signUpVC)
        navController.setNavigationBarHidden(true, animated: false)
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
}

// MARK: - Sign Up View Controller

/// Main view controller for the sign up screen
class SignUpViewController: UIViewController {
    // MARK: - Properties
    
    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    private var completion: ((Bool) -> Void)?
    
    // MARK: - UI Components
    
    private lazy var containerView: UIHostingController<SignUpContentView> = {
        let contentView = SignUpContentView(
            onComplete: { [weak self] success in
                self?.handleAuthResult(success)
            },
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        let hostingController = UIHostingController(rootView: contentView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        return hostingController
    }()
    
    // MARK: - Lifecycle
    
    init(completion: ((Bool) -> Void)? = nil) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Add hosting controller
        addChild(containerView)
        view.addSubview(containerView.view)
        containerView.didMove(toParent: self)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            containerView.view.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Auth Handling
    
    private func handleAuthResult(_ success: Bool) {
        if success {
            completion?(true)
            dismiss(animated: true)
        } else {
            completion?(false)
        }
    }
}

// MARK: - Sign Up Content View

/// SwiftUI view containing the sign up form
private struct SignUpContentView: View {
    // MARK: - Properties
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onComplete: (Bool) -> Void
    let onDismiss: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.customText)
                    
                    Text("Join SlikSlop today")
                        .font(.subheadline)
                        .foregroundColor(.customSubtitle)
                }
                .padding(.top, 60)
                
                VStack(spacing: 16) {
                    // Email field
                    AuthTextField(
                        title: "Email",
                        placeholder: "Enter your email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    
                    // Password field
                    AuthTextField(
                        title: "Password",
                        placeholder: "Create a password",
                        text: $password,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                    
                    // Confirm Password field
                    AuthTextField(
                        title: "Confirm Password",
                        placeholder: "Confirm your password",
                        text: $confirmPassword,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                    
                    // Error message
                    AuthErrorLabel(error: errorMessage)
                }
                
                VStack(spacing: 12) {
                    // Sign Up button
                    AuthButton(
                        title: "Sign Up",
                        isLoading: isLoading
                    ) {
                        await signUp()
                    }
                    
                    // Back to Login button
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(.customSubtitle)
                        
                        AuthSecondaryButton(title: "Sign In") {
                            onDismiss()
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.customBackground)
    }
    
    // MARK: - Actions
    
    private func signUp() async {
        guard validateInputs() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await AuthService.shared.signUp(email: email, password: password)
            print("✅ SignUpView - User created successfully: \(result.user.uid)")
            onComplete(true)
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
            onComplete(false)
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            onComplete(false)
        }
        
        isLoading = false
    }
    
    private func validateInputs() -> Bool {
        // Validate email
        if email.isEmpty {
            errorMessage = "Please enter your email"
            return false
        }
        
        // Validate password
        if password.isEmpty {
            errorMessage = "Please enter a password"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        // Validate password confirmation
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
} 