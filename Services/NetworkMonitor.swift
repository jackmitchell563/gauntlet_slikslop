import Foundation
import Network

/// Represents different network conditions with associated speeds
enum NetworkCondition: Equatable {
    case wifi(speed: Int)      // Speed in bits per second
    case cellular(speed: Int)  // Speed in bits per second
    case poor
    case none
    
    var isExpensive: Bool {
        switch self {
        case .cellular: return true
        default: return false
        }
    }
    
    var estimatedSpeed: Int {
        switch self {
        case .wifi(let speed): return speed
        case .cellular(let speed): return speed
        case .poor: return 100_000  // 100 Kbps
        case .none: return 0
        }
    }
}

/// Monitors network conditions and provides updates
final class NetworkMonitor {
    // MARK: - Properties
    
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.slikslop.networkmonitor")
    
    private(set) var currentCondition: NetworkCondition = .none {
        didSet {
            if oldValue != currentCondition {
                handleNetworkConditionChange()
            }
        }
    }
    
    var handlers: [() -> Void] = []
    
    // MARK: - Initialization
    
    private init() {
        setupMonitor()
    }
    
    // MARK: - Setup
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateNetworkCondition(path)
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkCondition(_ path: NWPath) {
        // Determine network condition based on path
        let newCondition: NetworkCondition
        
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                // Estimate WiFi speed based on path properties
                let speed = estimateNetworkSpeed(path)
                newCondition = .wifi(speed: speed)
            } else if path.usesInterfaceType(.cellular) {
                // Estimate cellular speed based on path properties
                let speed = estimateNetworkSpeed(path)
                newCondition = .cellular(speed: speed)
            } else {
                newCondition = .poor
            }
        } else {
            newCondition = .none
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentCondition = newCondition
        }
    }
    
    private func estimateNetworkSpeed(_ path: NWPath) -> Int {
        // This is a simplified estimation. In a real app, you might want to:
        // 1. Use historical data
        // 2. Perform speed tests
        // 3. Consider signal strength
        // 4. Use carrier information
        
        if path.usesInterfaceType(.wifi) {
            return 10_000_000 // 10 Mbps default for WiFi
        } else if path.usesInterfaceType(.cellular) {
            return 5_000_000  // 5 Mbps default for cellular
        }
        return 1_000_000     // 1 Mbps default fallback
    }
    
    // MARK: - Network Condition Handling
    
    private func handleNetworkConditionChange() {
        print("📡 NetworkMonitor - Network condition changed to: \(describeCondition(currentCondition))")
        
        // Notify all registered handlers
        handlers.forEach { $0() }
    }
    
    // MARK: - Public Methods
    
    /// Register a handler to be called when network conditions change
    func addHandler(_ handler: @escaping () -> Void) {
        handlers.append(handler)
    }
    
    /// Remove all registered handlers
    func removeAllHandlers() {
        handlers.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func describeCondition(_ condition: NetworkCondition) -> String {
        switch condition {
        case .wifi(let speed):
            return "WiFi (\(formatSpeed(speed)))"
        case .cellular(let speed):
            return "Cellular (\(formatSpeed(speed)))"
        case .poor:
            return "Poor Connection"
        case .none:
            return "No Connection"
        }
    }
    
    private func formatSpeed(_ bps: Int) -> String {
        let mbps = Double(bps) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
} 