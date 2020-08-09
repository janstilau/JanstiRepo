//
//  ImportProtocol.h
//  SwiftSourceCode
//
//  Created by JustinLau on 2020/8/9.
//  Copyright © 2020 JustinLau. All rights reserved.
//

#ifndef ImportProtocol_h
#define ImportProtocol_h
/*
 
Strideable, 可比较的, 可以测算距离的, 可以根据距离, 进行前进后退的.
public protocol Strideable: Comparable {
    associatedtype Stride: SignedNumeric, Comparable
    func distance(to other: Self) -> Stride
    func advanced(by n: Stride) -> Self
    static func _step(
        after current: (index: Int?, value: Self),
        from start: Self, by distance: Self.Stride
    ) -> (index: Int?, value: Self)
}
 stride(from:to:by:)
 stride(from:through:by:)
 这两个方法会生成相应的 sequence, 相关的 next, 就是根据是否达到边界, 返回 index 值
 
 */
#endif /* ImportProtocol_h */
