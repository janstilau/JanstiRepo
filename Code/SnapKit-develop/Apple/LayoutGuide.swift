import Foundation

/*
    NSLayoutGuide.h
    Application Kit
    Copyright (c) 2015-2019, Apple Inc.
    All rights reserved.
 */

/* NSLayoutGuides will not show up in the view hierarchy, but may be used as items in an NSLayoutConstraint and represent a rectangle in the layout engine.
 */

@available(macOS 10.11, *)
open class NSLayoutGuide : NSObject, NSCoding, NSUserInterfaceItemIdentification {

    
    // The frame of the NSLayoutGuide in its owningView's coordinate system. Valid by the time the owningView is laid out.
    open var frame: NSRect { get }

    
    // A guide must be added to a view via -[NSView -addLayoutGuide:] before being used in a constraint.  The owningView setter is intended for subclasses to override, and should only be used directly by -addLayoutGuide and -removeLayoutGuide.
    weak open var owningView: NSView?

    
    // For ease of debugging.  'NS' prefix is reserved for system-created layout guides.
    open var identifier: NSUserInterfaceItemIdentifier

    
    /*
     These properties aid concise creation of constraints.  Layout guides can be constrained using simple code like the following:
     [view.topAnchor constraintEqualTo:someLayoutGuide.topAnchor constant:10];
     
     See NSLayoutAnchor.h for more details.
     */
    open var leadingAnchor: NSLayoutXAxisAnchor { get }

    open var trailingAnchor: NSLayoutXAxisAnchor { get }

    open var leftAnchor: NSLayoutXAxisAnchor { get }

    open var rightAnchor: NSLayoutXAxisAnchor { get }

    open var topAnchor: NSLayoutYAxisAnchor { get }

    open var bottomAnchor: NSLayoutYAxisAnchor { get }

    open var widthAnchor: NSLayoutDimension { get }

    open var heightAnchor: NSLayoutDimension { get }

    open var centerXAnchor: NSLayoutXAxisAnchor { get }

    open var centerYAnchor: NSLayoutYAxisAnchor { get }

    
    // For debugging purposes:
    @available(macOS 10.12, *)
    open var hasAmbiguousLayout: Bool { get }

    @available(macOS 10.12, *)
    open func constraintsAffectingLayout(for orientation: NSLayoutConstraint.Orientation) -> [NSLayoutConstraint]
}

/* A layout guide can be used in place of a view for layout purposes.
 */
extension NSView {

    
    @available(macOS 10.11, *)
    open func addLayoutGuide(_ guide: NSLayoutGuide)

    @available(macOS 10.11, *)
    open func removeLayoutGuide(_ guide: NSLayoutGuide)

    
    @available(macOS 10.11, *)
    open var layoutGuides: [NSLayoutGuide] { get } // This array may contain guides owned by the system, and the ordering is not guaranteed.  Please be careful.
}
