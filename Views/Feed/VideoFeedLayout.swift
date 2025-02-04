import UIKit

class VideoFeedLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }
    
    private func setupLayout() {
        scrollDirection = .vertical
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        
        // Get the current page based on the proposed offset
        let pageHeight = collectionView.bounds.height
        let currentPage = proposedContentOffset.y / pageHeight
        
        // Determine target page based on velocity and current position
        var targetPage = currentPage
        if abs(velocity.y) > 0.3 {
            targetPage = velocity.y > 0 ? ceil(currentPage) : floor(currentPage)
        } else {
            targetPage = round(currentPage)
        }
        
        // Calculate final target offset
        let targetOffset = max(0, min(
            targetPage * pageHeight,
            collectionView.contentSize.height - collectionView.bounds.height
        ))
        
        return CGPoint(x: 0, y: targetOffset)
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        
        // Ensure each cell takes up the full width and height of the collection view
        attributes?.forEach { attribute in
            if attribute.representedElementCategory == .cell {
                attribute.frame = CGRect(
                    x: 0,
                    y: attribute.frame.origin.y,
                    width: collectionView?.bounds.width ?? attribute.frame.width,
                    height: collectionView?.bounds.height ?? attribute.frame.height
                )
            }
        }
        
        return attributes
    }
} 