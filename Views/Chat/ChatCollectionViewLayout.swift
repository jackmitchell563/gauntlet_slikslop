import UIKit

/// Custom layout for chat messages
class ChatCollectionViewLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }
    
    private func setupLayout() {
        minimumInteritemSpacing = 8
        minimumLineSpacing = 8
        sectionInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        scrollDirection = .vertical
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        
        // Ensure proper z-index for overlapping cells
        attributes?.forEach { attribute in
            attribute.zIndex = attribute.indexPath.item
        }
        
        return attributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        // Invalidate layout when width changes (e.g., rotation)
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
} 