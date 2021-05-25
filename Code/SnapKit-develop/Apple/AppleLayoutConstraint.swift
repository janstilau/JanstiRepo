import Foundation

//
//  NSLayoutConstraint.h
//  UIKit
//
//  Copyright (c) 2009-2018 Apple Inc. All rights reserved.
//

public struct UILayoutPriority : Hashable, Equatable, RawRepresentable {

    public init(_ rawValue: Float)

    public init(rawValue: Float)
}
extension UILayoutPriority {

    @available(iOS 6.0, *)
    public static let required: UILayoutPriority

    @available(iOS 6.0, *)
    public static let defaultHigh: UILayoutPriority // This is the priority level with which a button resists compressing its content.

    public static let dragThatCanResizeScene: UILayoutPriority // This is the appropriate priority level for a drag that may end up resizing the window's scene.

    public static let sceneSizeStayPut: UILayoutPriority // This is the priority level at which the window's scene prefers to stay the same size.  It's generally not appropriate to make a constraint at exactly this priority. You want to be higher or lower.

    public static let dragThatCannotResizeScene: UILayoutPriority // This is the priority level at which a split view divider, say, is dragged.  It won't resize the window's scene.

    @available(iOS 6.0, *)
    public static let defaultLow: UILayoutPriority // This is the priority level at which a button hugs its contents horizontally.

    @available(iOS 6.0, *)
    public static let fittingSizeLevel: UILayoutPriority // When you send -[UIView systemLayoutSizeFittingSize:], the size fitting most closely to the target size (the argument) is computed.  UILayoutPriorityFittingSizeLevel is the priority level with which the view wants to conform to the target size in that computation.  It's quite low.  It is generally not appropriate to make a constraint at exactly this priority.  You want to be higher or lower.
}

/* !TARGET_OS_IPHONE */

public var NSLAYOUTCONSTRAINT_H: Int32 { get }
extension NSLayoutConstraint {

    
    public enum Relation : Int {

        
        case lessThanOrEqual = -1

        case equal = 0

        case greaterThanOrEqual = 1
    }

    
    public enum Attribute : Int {

        
        case left = 1

        case right = 2

        case top = 3

        case bottom = 4

        case leading = 5

        case trailing = 6

        case width = 7

        case height = 8

        case centerX = 9

        case centerY = 10

        case lastBaseline = 11

        
        @available(iOS 8.0, *)
        case firstBaseline = 12

        
        @available(iOS 8.0, *)
        case leftMargin = 13

        @available(iOS 8.0, *)
        case rightMargin = 14

        @available(iOS 8.0, *)
        case topMargin = 15

        @available(iOS 8.0, *)
        case bottomMargin = 16

        @available(iOS 8.0, *)
        case leadingMargin = 17

        @available(iOS 8.0, *)
        case trailingMargin = 18

        @available(iOS 8.0, *)
        case centerXWithinMargins = 19

        @available(iOS 8.0, *)
        case centerYWithinMargins = 20

        
        case notAnAttribute = 0
    }

    
    public struct FormatOptions : OptionSet {

        public init(rawValue: UInt)

        
        public static var alignAllLeft: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllRight: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllTop: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllBottom: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllLeading: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllTrailing: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllCenterX: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllCenterY: NSLayoutConstraint.FormatOptions { get }

        public static var alignAllLastBaseline: NSLayoutConstraint.FormatOptions { get }

        @available(iOS 8.0, *)
        public static var alignAllFirstBaseline: NSLayoutConstraint.FormatOptions { get }

        
        public static var alignmentMask: NSLayoutConstraint.FormatOptions { get }

        
        /* choose only one of these three
         */
        public static var directionLeadingToTrailing: NSLayoutConstraint.FormatOptions { get } // default

        public static var directionLeftToRight: NSLayoutConstraint.FormatOptions { get }

        public static var directionRightToLeft: NSLayoutConstraint.FormatOptions { get }

        
        public static var directionMask: NSLayoutConstraint.FormatOptions { get }

        
        /* Valid only for vertical layouts. Between views with text content the value
         will be used to determine the distance from the last baseline of the view above
         to the first baseline of the view below. For views without text content the top
         or bottom edge will be used in lieu of the baseline position.
         The default spacing "]-[" will be determined from the line heights of the fonts
         involved in views with text content, when present.
         */
        @available(iOS 11.0, *)
        public static var spacingBaselineToBaseline: NSLayoutConstraint.FormatOptions { get }

        
        @available(iOS 11.0, *)
        public static var spacingMask: NSLayoutConstraint.FormatOptions { get }
    }
}

@available(iOS 6.0, *)
open class NSLayoutConstraint : NSObject {

    
    /* Create an array of constraints using an ASCII-art-like visual format string.  The values of the `metrics` dictionary should be NSNumber (or some other type that responds to -doubleValue and returns a double).
     */
    @available(iOS 6.0, *)
    open class func constraints(withVisualFormat format: String, options opts: NSLayoutConstraint.FormatOptions = [], metrics: [String : Any]?, views: [String : Any]) -> [NSLayoutConstraint]

    
    /* This macro is a helper for making view dictionaries for +constraintsWithVisualFormat:options:metrics:views:.
     NSDictionaryOfVariableBindings(v1, v2, v3) is equivalent to [NSDictionary dictionaryWithObjectsAndKeys:v1, @"v1", v2, @"v2", v3, @"v3", nil];
     */
    
    // not for direct use
    
    /* Create constraints explicitly.  Constraints are of the form "view1.attr1 = view2.attr2 * multiplier + constant"
     If your equation does not have a second view and attribute, use nil and NSLayoutAttributeNotAnAttribute.
     Use of this method is not recommended. Constraints should be created using anchor objects on views and layout guides.
     */
    @available(iOS 6.0, *)
    public convenience init(item view1: Any, attribute attr1: NSLayoutConstraint.Attribute, relatedBy relation: NSLayoutConstraint.Relation, toItem view2: Any?, attribute attr2: NSLayoutConstraint.Attribute, multiplier: CGFloat, constant c: CGFloat)

    
    /* If a constraint's priority level is less than required, then it is optional.  Higher priority constraints are met before lower priority constraints.
     Constraint satisfaction is not all or nothing.  If a constraint 'a == b' is optional, that means we will attempt to minimize 'abs(a-b)'.
     This property may only be modified as part of initial set up or when optional.  After a constraint has been added to a view, an exception will be thrown if the priority is changed from/to NSLayoutPriorityRequired.
     */
    
    open var priority: UILayoutPriority

    
    /* When a view is archived, it archives some but not all constraints in its -constraints array.  The value of shouldBeArchived informs the view if a particular constraint should be archived by the view.
     If a constraint is created at runtime in response to the state of the object, it isn't appropriate to archive the constraint - rather you archive the state that gives rise to the constraint.  Since the majority of constraints that should be archived are created in Interface Builder (which is smart enough to set this prop to YES), the default value for this property is NO.
     */
    open var shouldBeArchived: Bool

    
    /* accessors
     firstItem.firstAttribute {==,<=,>=} secondItem.secondAttribute * multiplier + constant
     Access to these properties is not recommended. Use the `firstAnchor` and `secondAnchor` properties instead.
     */
    unowned(unsafe) open var firstItem: AnyObject? { get }

    unowned(unsafe) open var secondItem: AnyObject? { get }

    open var firstAttribute: NSLayoutConstraint.Attribute { get }

    open var secondAttribute: NSLayoutConstraint.Attribute { get }

    
    /* accessors
     firstAnchor{==,<=,>=} secondAnchor * multiplier + constant
     */
    @available(iOS 10.0, *)
    @NSCopying open var firstAnchor: NSLayoutAnchor<AnyObject> { get }

    @available(iOS 10.0, *)
    @NSCopying open var secondAnchor: NSLayoutAnchor<AnyObject>? { get }

    open var relation: NSLayoutConstraint.Relation { get }

    open var multiplier: CGFloat { get }

    
    /* Unlike the other properties, the constant may be modified after constraint creation.  Setting the constant on an existing constraint performs much better than removing the constraint and adding a new one that's just like the old but for having a new constant.
     */
    open var constant: CGFloat

    
    /* The receiver may be activated or deactivated by manipulating this property.  Only active constraints affect the calculated layout.  Attempting to activate a constraint whose items have no common ancestor will cause an exception to be thrown.  Defaults to NO for newly created constraints. */
    @available(iOS 8.0, *)
    open var isActive: Bool

    
    /* Convenience method that activates each constraint in the contained array, in the same manner as setting active=YES. This is often more efficient than activating each constraint individually. */
    @available(iOS 8.0, *)
    open class func activate(_ constraints: [NSLayoutConstraint])

    
    /* Convenience method that deactivates each constraint in the contained array, in the same manner as setting active=NO. This is often more efficient than deactivating each constraint individually. */
    @available(iOS 8.0, *)
    open class func deactivate(_ constraints: [NSLayoutConstraint])
}

extension NSLayoutConstraint {

    
    /* For ease in debugging, name a constraint by setting its identifier, which will be printed in the constraint's description.
       Identifiers starting with NS or UI are reserved by the system.
     */
    @available(iOS 7.0, *)
    open var identifier: String?
}

// NSLAYOUTCONSTRAINT_H

/*
 UILayoutSupport protocol is implemented by layout guide objects
 returned by UIViewController properties topLayoutGuide and bottomLayoutGuide.
 These guide objects may be used as layout items in the NSLayoutConstraint
 factory methods.
 */

public protocol UILayoutSupport : NSObjectProtocol {

    var length: CGFloat { get } // As a courtesy when not using auto layout, this value is safe to refer to in -viewDidLayoutSubviews, or in -layoutSubviews after calling super

    
    /* Constraint creation conveniences. See NSLayoutAnchor.h for details.
     */
    @available(iOS 9.0, *)
    var topAnchor: NSLayoutYAxisAnchor { get }

    @available(iOS 9.0, *)
    var bottomAnchor: NSLayoutYAxisAnchor { get }

    @available(iOS 9.0, *)
    var heightAnchor: NSLayoutDimension { get }
}
