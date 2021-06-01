#if os(iOS) || os(tvOS)
import UIKit
#else
import AppKit
#endif


public extension ConstraintView {
    
    
    /*
        使用 snp_left 是给扩展的类, 增加了方法. 增加了一系列的方法.
        使用 snp 是给扩展的类, 增加了一个属性, 然后在这个属性上, 返回相关内容的数据.
     */
    @available(*, deprecated, renamed:"snp.left")
    var snp_left: ConstraintItem { return self.snp.left }
    
    @available(*, deprecated, renamed:"snp.top")
    var snp_top: ConstraintItem { return self.snp.top }
    
    @available(*, deprecated, renamed:"snp.right")
    var snp_right: ConstraintItem { return self.snp.right }
    
    @available(*, deprecated, renamed:"snp.bottom")
    var snp_bottom: ConstraintItem { return self.snp.bottom }
    
    @available(*, deprecated, renamed:"snp.leading")
    var snp_leading: ConstraintItem { return self.snp.leading }
    
    @available(*, deprecated, renamed:"snp.trailing")
    var snp_trailing: ConstraintItem { return self.snp.trailing }
    
    @available(*, deprecated, renamed:"snp.width")
    var snp_width: ConstraintItem { return self.snp.width }
    
    @available(*, deprecated, renamed:"snp.height")
    var snp_height: ConstraintItem { return self.snp.height }
    
    @available(*, deprecated, renamed:"snp.centerX")
    var snp_centerX: ConstraintItem { return self.snp.centerX }
    
    @available(*, deprecated, renamed:"snp.centerY")
    var snp_centerY: ConstraintItem { return self.snp.centerY }
    
    @available(*, deprecated, renamed:"snp.baseline")
    var snp_baseline: ConstraintItem { return self.snp.baseline }
    
    @available(*, deprecated, renamed:"snp.lastBaseline")
    @available(iOS 8.0, OSX 10.11, *)
    var snp_lastBaseline: ConstraintItem { return self.snp.lastBaseline }
    
    @available(iOS, deprecated, renamed:"snp.firstBaseline")
    @available(iOS 8.0, OSX 10.11, *)
    var snp_firstBaseline: ConstraintItem { return self.snp.firstBaseline }
    
    @available(iOS, deprecated, renamed:"snp.leftMargin")
    @available(iOS 8.0, *)
    var snp_leftMargin: ConstraintItem { return self.snp.leftMargin }
    
    @available(iOS, deprecated, renamed:"snp.topMargin")
    @available(iOS 8.0, *)
    var snp_topMargin: ConstraintItem { return self.snp.topMargin }
    
    @available(iOS, deprecated, renamed:"snp.rightMargin")
    @available(iOS 8.0, *)
    var snp_rightMargin: ConstraintItem { return self.snp.rightMargin }
    
    @available(iOS, deprecated, renamed:"snp.bottomMargin")
    @available(iOS 8.0, *)
    var snp_bottomMargin: ConstraintItem { return self.snp.bottomMargin }
    
    @available(iOS, deprecated, renamed:"snp.leadingMargin")
    @available(iOS 8.0, *)
    var snp_leadingMargin: ConstraintItem { return self.snp.leadingMargin }
    
    @available(iOS, deprecated, renamed:"snp.trailingMargin")
    @available(iOS 8.0, *)
    var snp_trailingMargin: ConstraintItem { return self.snp.trailingMargin }
    
    @available(iOS, deprecated, renamed:"snp.centerXWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerXWithinMargins: ConstraintItem { return self.snp.centerXWithinMargins }
    
    @available(iOS, deprecated, renamed:"snp.centerYWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerYWithinMargins: ConstraintItem { return self.snp.centerYWithinMargins }
    
    @available(*, deprecated, renamed:"snp.edges")
    var snp_edges: ConstraintItem { return self.snp.edges }
    
    @available(*, deprecated, renamed:"snp.size")
    var snp_size: ConstraintItem { return self.snp.size }
    
    @available(*, deprecated, renamed:"snp.center")
    var snp_center: ConstraintItem { return self.snp.center }
    
    @available(iOS, deprecated, renamed:"snp.margins")
    @available(iOS 8.0, *)
    var snp_margins: ConstraintItem { return self.snp.margins }
    
    @available(iOS, deprecated, renamed:"snp.centerWithinMargins")
    @available(iOS 8.0, *)
    var snp_centerWithinMargins: ConstraintItem { return self.snp.centerWithinMargins }
    
    @available(*, deprecated, renamed:"snp.prepareConstraints(_:)")
    func snp_prepareConstraints(_ closure: (_ make: ConstraintMaker) -> Void) -> [Constraint] {
        return self.snp.prepareConstraints(closure)
    }
    
    @available(*, deprecated, renamed:"snp.makeConstraints(_:)")
    func snp_makeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.makeConstraints(closure)
    }
    
    @available(*, deprecated, renamed:"snp.remakeConstraints(_:)")
    func snp_remakeConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.remakeConstraints(closure)
    }
    
    @available(*, deprecated, renamed:"snp.updateConstraints(_:)")
    func snp_updateConstraints(_ closure: (_ make: ConstraintMaker) -> Void) {
        self.snp.updateConstraints(closure)
    }
    
    @available(*, deprecated, renamed:"snp.removeConstraints()")
    func snp_removeConstraints() {
        self.snp.removeConstraints()
    }
    
        
    /*
        SnapKit 的基础, 是引用类型. 所以, 才能将数据交给盒子一个个的进行传递.
     */
    var snp: ConstraintViewDSL {
        return ConstraintViewDSL(view: self)
    }
    
}