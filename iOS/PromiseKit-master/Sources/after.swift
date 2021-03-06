import struct Foundation.TimeInterval
import Dispatch

/*
     after(seconds: 1.5).then {
         //…
     }
- Returns: A guarantee that resolves after the specified duration.
*/
/*
    建立一个 Guarantee, 然后在固定的 seconds 之后, 调用这个 Gurantee 的 seal 方法, 将它的状态, 改变为 Resolved.
 */
public func after(seconds: TimeInterval) -> Guarantee<Void> {
    let (rg, seal) = Guarantee<Void>.pending()
    let when = DispatchTime.now() + seconds
    q.asyncAfter(deadline: when) { seal(()) }
    return rg
}

/*
     after(.seconds(2)).then {
         //…
     }

 - Returns: A guarantee that resolves after the specified duration.
*/
public func after(_ interval: DispatchTimeInterval) -> Guarantee<Void> {
    let (rg, seal) = Guarantee<Void>.pending()
    let when = DispatchTime.now() + interval
    q.asyncAfter(deadline: when) { seal(()) }
    return rg
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
