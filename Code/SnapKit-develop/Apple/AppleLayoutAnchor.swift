import Foundation

/*    NSLayoutAnchor.h
    Copyright (c) 2015-2018, Apple Inc. All rights reserved.
*/

public var NSLAYOUTANCHOR_H: Int32 { get }

/*
 An NSLayoutAnchor represents an edge or dimension of a layout item.  Its concrete subclasses allow concise creation of constraints.  The idea is that instead of invoking +[NSLayoutConstraint constraintWithItem: attribute: relatedBy: toItem: attribute: multiplier: constant:] directly, you can instead do something like this:
 
 [myView.topAnchor constraintEqualToAnchor:otherView.topAnchor constant:10];
 
 The -constraint* methods are available in multiple flavors to support use of different relations and omission of unused options.
 
 */

/*
    这个类, 就是一个工厂类, 用来定义各种 NSLayoutConstraint 对象.
 */

@available(iOS 9.0, *)
open class NSLayoutAnchor<AnchorType> : NSObject, NSCopying, NSCoding where AnchorType : AnyObject {

    // NSLayoutAnchor conforms to <NSCopying> and <NSCoding> on macOS 10.12, iOS 10, and tvOS 10
    
    // These methods return an inactive constraint of the form thisAnchor = otherAnchor.
    open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint

    open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint

    
    // These methods return an inactive constraint of the form thisAnchor = otherAnchor + constant.
    open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint

    open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint
}

// Axis-specific subclasses for location anchors: top/bottom, leading/trailing, baseline, etc.

@available(iOS 9.0, *)
open class NSLayoutXAxisAnchor : NSLayoutAnchor<NSLayoutXAxisAnchor> {

    
    // A composite anchor for creating constraints relating horizontal distances between locations.
    @available(iOS 10.0, *)
    open func anchorWithOffset(to otherAnchor: NSLayoutXAxisAnchor) -> NSLayoutDimension
}

@available(iOS 9.0, *)
open class NSLayoutYAxisAnchor : NSLayoutAnchor<NSLayoutYAxisAnchor> {

    
    // A composite anchor for creating constraints relating vertical distances between locations.
    @available(iOS 10.0, *)
    open func anchorWithOffset(to otherAnchor: NSLayoutYAxisAnchor) -> NSLayoutDimension
}

// This layout anchor subclass is used for sizes (width & height).

@available(iOS 9.0, *)
open class NSLayoutDimension : NSLayoutAnchor<NSLayoutDimension> {

    // These methods return an inactive constraint of the form thisVariable = constant.
    open func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint

    open func constraint(greaterThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint

    open func constraint(lessThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint

    
    // These methods return an inactive constraint of the form thisAnchor = otherAnchor * multiplier.
    open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint

    open func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint

    
    // These methods return an inactive constraint of the form thisAnchor = otherAnchor * multiplier + constant.
    open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint

    open func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint

    open func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint
}

// NSLAYOUTANCHOR_H

extension NSLayoutXAxisAnchor {

    /* Constraints of the form,
     receiver [= | ≥ | ≤] 'anchor' + 'multiplier' * system space,
     where the value of the system space is determined from information available from the anchors.
     The constraint affects how far the receiver will be positioned trailing 'anchor', per the effective user interface layout direction.
     */
    @available(iOS 11.0, *)
    open func constraint(equalToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint

    @available(iOS 11.0, *)
    open func constraint(greaterThanOrEqualToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint

    @available(iOS 11.0, *)
    open func constraint(lessThanOrEqualToSystemSpacingAfter anchor: NSLayoutXAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint
}

extension NSLayoutYAxisAnchor {

    /* Constraints of the form,
     receiver [= | ≥ | ≤] 'anchor' + 'multiplier' * system space,
     where the value of the system space is determined from information available from the anchors.
     The constraint affects how far the receiver will be positioned below 'anchor'.
     If either the receiver or 'anchor' is the firstBaselineAnchor or lastBaselineAnchor of a view with text content
     then the spacing will depend on the fonts involved and will change when those do.
     */
    @available(iOS 11.0, *)
    open func constraint(equalToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint

    @available(iOS 11.0, *)
    open func constraint(greaterThanOrEqualToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint

    @available(iOS 11.0, *)
    open func constraint(lessThanOrEqualToSystemSpacingBelow anchor: NSLayoutYAxisAnchor, multiplier: CGFloat) -> NSLayoutConstraint
}
