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

/*
    标量值, 和类型, 都实现了 ConstraintRelatableTarget. 这样我们在使用 make 的时候, equal 里面可以填数值, 也可以填对象.
    这在方便了调用的同时, 是让 equal 的实现变得复杂了.
 */

public protocol ConstraintRelatableTarget {
}

// equalto 里面, 是依据 ConstraintRelatableTarget 进行的类型匹配. 所以, 可以在里面, 使用各种不同类型的值.

extension Int: ConstraintRelatableTarget {
}

extension UInt: ConstraintRelatableTarget {
}

extension Float: ConstraintRelatableTarget {
}

extension Double: ConstraintRelatableTarget {
}

extension CGFloat: ConstraintRelatableTarget {
}

extension CGSize: ConstraintRelatableTarget {
}

extension CGPoint: ConstraintRelatableTarget {
}

extension ConstraintInsets: ConstraintRelatableTarget {
}

#if os(iOS) || os(tvOS)
@available(iOS 11.0, tvOS 11.0, *)
extension ConstraintDirectionalInsets: ConstraintRelatableTarget {
}
#endif

extension ConstraintItem: ConstraintRelatableTarget {
}

extension ConstraintView: ConstraintRelatableTarget {
}

@available(iOS 9.0, OSX 10.11, *)
extension ConstraintLayoutGuide: ConstraintRelatableTarget {
}
