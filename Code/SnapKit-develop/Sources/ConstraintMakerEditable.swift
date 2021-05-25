//
//  SnapKit
//
//  Copyright (c) 2011-Present SnapKit Team - https://github.com/SnapKit
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if os(iOS) || os(tvOS)
    import UIKit
#else
    import AppKit
#endif

// 各种, 算式操作, 仅仅是添加了一份数据进去而已.
// 添加 attribute, 添加 item, 添加计算式.
// SnapKit 将一份数据, 在各自的业务范围内, 使用了不同的容器进行包装. 让代码具有独立性.
// 如果是自己设计, 可能一个容器类, 做了所有的事情, 或者容器内部有不同的处理者.
// 这里, SnapKit 进行了良好的功能模块分割.

public class ConstraintMakerEditable: ConstraintMakerPrioritizable {

    @discardableResult
    public func multipliedBy(_ amount: ConstraintMultiplierTarget) -> ConstraintMakerEditable {
        self.description.multiplier = amount
        return self
    }
    
    @discardableResult
    public func dividedBy(_ amount: ConstraintMultiplierTarget) -> ConstraintMakerEditable {
        return self.multipliedBy(1.0 / amount.constraintMultiplierTargetValue)
    }
    
    @discardableResult
    public func offset(_ amount: ConstraintOffsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintOffsetTargetValue
        return self
    }
    
    @discardableResult
    public func inset(_ amount: ConstraintInsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintInsetTargetValue
        return self
    }
    
    #if os(iOS) || os(tvOS)
    @discardableResult
    @available(iOS 11.0, tvOS 11.0, *)
    public func inset(_ amount: ConstraintDirectionalInsetTarget) -> ConstraintMakerEditable {
        self.description.constant = amount.constraintDirectionalInsetTargetValue
        return self
    }
    #endif
}
