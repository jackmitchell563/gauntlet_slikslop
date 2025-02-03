# UI Components

## Overview

The UI components directory contains reusable React Native components that maintain consistent styling and behavior across the app. These components are designed with nature-themed aesthetics and optimal mobile user experience.

## Core Components

### VideoCard
- **Purpose**: Displays individual videos in feeds
- **Usage**: Primary content display component
- **Props**:
  - video: Video metadata and URL
  - onLike: Like handler
  - onComment: Comment handler
- **Example**:
```javascript
export const VideoCard = ({ video, onLike, onComment }) => {
    return (
        <Card>
            <VideoPlayer url={video.url} />
            <InteractionBar
                likes={video.likes}
                comments={video.comments}
                onLike={() => onLike(video.id)}
                onComment={() => onComment(video.id)}
            />
            <CreatorInfo user={video.creator} />
        </Card>
    );
};
```

### ProfileHeader
- **Purpose**: Displays user profile information
- **Usage**: Profile page header component
- **Props**:
  - user: User profile data
  - stats: Engagement statistics
- **Example**:
```javascript
export const ProfileHeader = ({ user, stats }) => {
    return (
        <Header>
            <Avatar source={user.avatar} />
            <UserInfo
                name={user.name}
                bio={user.bio}
                stats={stats}
            />
            <ActionButtons />
        </Header>
    );
};
```

### FeedContainer
- **Purpose**: Manages feed layout and scrolling
- **Usage**: Container for video feeds
- **Props**:
  - videos: List of video items
  - onEndReached: Infinite scroll handler
- **Example**:
```javascript
export const FeedContainer = ({ videos, onEndReached }) => {
    return (
        <FlatList
            data={videos}
            renderItem={({ item }) => <VideoCard video={item} />}
            onEndReached={onEndReached}
            onEndReachedThreshold={0.5}
        />
    );
};
```

### InteractionBar
- **Purpose**: Handles user interactions with content
- **Usage**: Part of VideoCard component
- **Props**:
  - likes: Like count
  - comments: Comment count
  - onLike: Like handler
  - onComment: Comment handler
- **Example**:
```javascript
export const InteractionBar = ({ likes, comments, onLike, onComment }) => {
    return (
        <Bar>
            <LikeButton count={likes} onPress={onLike} />
            <CommentButton count={comments} onPress={onComment} />
            <ShareButton />
        </Bar>
    );
};
```

## Design System

### 1. Colors
```javascript
export const colors = {
    primary: '#2E7D32',     // Forest Green
    secondary: '#1B5E20',   // Dark Green
    accent: '#81C784',      // Light Green
    background: '#F1F8E9',  // Nature White
    text: '#212121',        // Almost Black
    textLight: '#757575',   // Gray
    error: '#D32F2F',       // Error Red
    success: '#388E3C'      // Success Green
};
```

### 2. Typography
```javascript
export const typography = {
    h1: {
        fontSize: 24,
        fontWeight: 'bold',
        lineHeight: 32
    },
    body: {
        fontSize: 16,
        lineHeight: 24
    },
    caption: {
        fontSize: 12,
        lineHeight: 16
    }
};
```

### 3. Spacing
```javascript
export const spacing = {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
};
```

## Best Practices

1. **Component Structure**
   - Keep components small and focused
   - Use composition over inheritance
   - Implement proper prop validation
   - Document component APIs

2. **Performance**
   - Implement proper memoization
   - Optimize re-renders
   - Lazy load components
   - Use proper list virtualization

3. **Accessibility**
   - Include proper ARIA labels
   - Support screen readers
   - Implement keyboard navigation
   - Maintain proper contrast

4. **Responsiveness**
   - Use flexible layouts
   - Implement proper scaling
   - Handle orientation changes
   - Support different screen sizes

## Integration Example

```javascript
// Feed screen implementation
const FeedScreen = () => {
    const [videos, setVideos] = useState([]);
    
    const handleLike = async (videoId) => {
        try {
            await likeVideo(videoId);
            // Update UI optimistically
        } catch (error) {
            // Handle error and revert UI
        }
    };
    
    const handleComment = (videoId) => {
        navigation.navigate('Comments', { videoId });
    };
    
    return (
        <SafeAreaView style={styles.container}>
            <FeedContainer
                videos={videos}
                onLike={handleLike}
                onComment={handleComment}
                onEndReached={loadMoreVideos}
            />
        </SafeAreaView>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: colors.background
    }
});
```

## Common Issues and Solutions

1. **Performance**
   - Problem: Laggy video feed scrolling
   - Solution: Implement proper list virtualization

2. **Layout**
   - Problem: Inconsistent component sizing
   - Solution: Use standardized spacing system

3. **State Management**
   - Problem: Complex component state
   - Solution: Implement proper state management

4. **Responsiveness**
   - Problem: Layout issues on different devices
   - Solution: Use flexible layouts and proper scaling

## Component Guidelines

1. **Naming Conventions**
   - Use PascalCase for components
   - Use camelCase for props
   - Use descriptive names
   - Follow consistent patterns

2. **File Structure**
   - One component per file
   - Group related components
   - Include index exports
   - Maintain proper imports

3. **Documentation**
   - Document props
   - Include usage examples
   - Explain complex logic
   - Note dependencies

4. **Testing**
   - Write unit tests
   - Test edge cases
   - Include integration tests
   - Test accessibility 