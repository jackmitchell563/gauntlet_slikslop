import SwiftUI

struct TopNavigationBar: View {
    enum FeedType {
        case following
        case forYou
        
        var title: String {
            switch self {
            case .following: return "Following"
            case .forYou: return "For You"
            }
        }
    }
    
    @Binding var selectedTab: FeedType
    var onSearchTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            
            // Following Tab
            TabButton(
                title: FeedType.following.title,
                isSelected: selectedTab == .following
            ) {
                withAnimation {
                    selectedTab = .following
                }
            }
            
            // For You Tab
            TabButton(
                title: FeedType.forYou.title,
                isSelected: selectedTab == .forYou
            ) {
                withAnimation {
                    selectedTab = .forYou
                }
            }
            
            Spacer()
            
            // Search Button
            Button(action: onSearchTapped) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .padding(.trailing, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundColor(.white)
                
                // Selection Indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 24, height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        TopNavigationBar(
            selectedTab: .constant(.forYou),
            onSearchTapped: {}
        )
    }
} 