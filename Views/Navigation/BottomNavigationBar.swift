import SwiftUI

struct BottomNavigationBar: View {
    enum Tab {
        case home
        case create
        case profile
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .create: return "plus"
            case .profile: return "person.fill"
            }
        }
    }
    
    @Binding var selectedTab: Tab
    @Namespace private var animation
    
    var body: some View {
        // Main container
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.0),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 140)
            .overlay(
                // Navigation items
                GeometryReader { geometry in
                    let width = geometry.size.width / 3
                    
                    ZStack {
                        // Bubble background
                        Circle()
                            .fill(Color.black)
                            .frame(width: 65, height: 65)
                            .offset(x: width * CGFloat([Tab.home, Tab.create, Tab.profile].firstIndex(of: selectedTab)!) - geometry.size.width/2 + width/2)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                        
                        // Buttons
                        HStack(spacing: 0) {
                            ForEach([Tab.home, Tab.create, Tab.profile], id: \.self) { tab in
                                TabButton(
                                    tab: tab,
                                    isSelected: selectedTab == tab,
                                    namespace: animation,
                                    action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedTab = tab
                                        }
                                    }
                                )
                                .frame(width: width)
                            }
                        }
                    }
                }
            )
            .ignoresSafeArea()
    }
}

private struct TabButton: View {
    let tab: BottomNavigationBar.Tab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if tab == .create {
                    // Special styling for create button
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 22 : 20))
                        .foregroundColor(.white)
                        .frame(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40)
                        .background(Color.pink)
                        .clipShape(Circle())
                        .shadow(color: .pink.opacity(0.3), radius: isSelected ? 10 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 26 : 22))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }
            .frame(height: 50)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            Spacer()
            BottomNavigationBar(selectedTab: .constant(.home))
        }
    }
} 