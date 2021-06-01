import UIKit

// MARK: Class Definition

/// Label indented from the edge on the left and right.
internal class MarginLabel: UILabel {
    
    // MARK: Private Properties
    
    private var edgeInsets = UIEdgeInsets.init(top: 0.0, left: 5.0, bottom: 0.0, right: 5.0)
    
    // MARK: Properties Overriders
    
    override internal var intrinsicContentSize: CGSize {
        get {
            var size = super.intrinsicContentSize
            size.width += self.edgeInsets.left + self.edgeInsets.right
            size.height += self.edgeInsets.top + self.edgeInsets.bottom
            return size
        }
    }
    
    // MARK: Init Methods & Superclass Overriders
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.edgeInsets))
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var sizeThatFits = super.sizeThatFits(size)
        sizeThatFits.width += self.edgeInsets.left + self.edgeInsets.right
        sizeThatFits.height += self.edgeInsets.top + self.edgeInsets.bottom
        return sizeThatFits
    }
    
}
