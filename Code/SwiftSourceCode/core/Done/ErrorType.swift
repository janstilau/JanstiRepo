import SwiftShims

/// Error 仅仅作为一个类型标识,  它实际上, 没有提出任何的方法限制.
///
/// Using Enumerations as Errors
/// ============================
///
///
/*
 这里就说的很明确, 如果数据类里面, 数据就是根据 enum 不同而变化的, 那么就用关联变量进行保存就可以了.
 如果, 数据是共享的, 那么就不用关联变量进行保存, enum 仅仅作为一个标志位
 */
/*
 所以, 其实 Error 还是有一些 primitiveMethod 的, 不过这些都是内部方法, 都有着自己的默认实现的.
 
 public protocol Error {
 }
 
 这是  Error 的定义, 在暴露给开发者的接口里面, 是上面的写法.
 */
public protocol Error {
    var _domain: String { get }
    var _code: Int { get }
    
    // Note: _userInfo is always an NSDictionary, but we cannot use that type here
    // because the standard library cannot depend on Foundation. However, the
    // underscore implies that we control all implementations of this requirement.
    var _userInfo: AnyObject? { get }
    
    #if _runtime(_ObjC)
    func _getEmbeddedNSError() -> AnyObject?
    #endif
}

#if _runtime(_ObjC)
extension Error {
    /// Default implementation: there is no embedded NSError.
    public func _getEmbeddedNSError() -> AnyObject? { return nil }
}
#endif

#if _runtime(_ObjC)
// Helper functions for the C++ runtime to have easy access to embedded error,
// domain, code, and userInfo as Objective-C values.
@_silgen_name("")
internal func _getErrorDomainNSString<T: Error>(_ x: UnsafePointer<T>)
    -> AnyObject {
        return x.pointee._domain._bridgeToObjectiveCImpl()
}

@_silgen_name("")
internal func _getErrorCode<T: Error>(_ x: UnsafePointer<T>) -> Int {
    return x.pointee._code
}

@_silgen_name("")
internal func _getErrorUserInfoNSDictionary<T: Error>(_ x: UnsafePointer<T>)
    -> AnyObject? {
        return x.pointee._userInfo.map { $0 as AnyObject }
}

// Called by the casting machinery to extract an NSError from an Error value.
@_silgen_name("")
internal func _getErrorEmbeddedNSErrorIndirect<T: Error>(
    _ x: UnsafePointer<T>) -> AnyObject? {
    return x.pointee._getEmbeddedNSError()
}

/// Called by compiler-generated code to extract an NSError from an Error value.
public // COMPILER_INTRINSIC
func _getErrorEmbeddedNSError<T: Error>(_ x: T)
    -> AnyObject? {
        return x._getEmbeddedNSError()
}

/// Provided by the ErrorObject implementation.
@_silgen_name("_swift_stdlib_getErrorDefaultUserInfo")
internal func _getErrorDefaultUserInfo<T: Error>(_ error: T) -> AnyObject?

/// Provided by the ErrorObject implementation.
/// Called by the casting machinery and by the Foundation overlay.
@_silgen_name("_swift_stdlib_bridgeErrorToNSError")
public func _bridgeErrorToNSError(_ error: __owned Error) -> AnyObject
#endif

/// Invoked by the compiler when the subexpression of a `try!` expression
/// throws an error.
@_silgen_name("swift_unexpectedError")
public func _unexpectedError(
    _ error: __owned Error,
    filenameStart: Builtin.RawPointer,
    filenameLength: Builtin.Word,
    filenameIsASCII: Builtin.Int1,
    line: Builtin.Word
) {
    preconditionFailure(
        "'try!' expression unexpectedly raised an error: \(String(reflecting: error))",
        file: StaticString(
            _start: filenameStart,
            utf8CodeUnitCount: filenameLength,
            isASCII: filenameIsASCII),
        line: UInt(line))
}

/// Invoked by the compiler when code at top level throws an uncaught error.
@_silgen_name("swift_errorInMain")
public func _errorInMain(_ error: Error) {
    fatalError("Error raised at top level: \(String(reflecting: error))")
}

/// Runtime function to determine the default code for an Error-conforming type.
/// Called by the Foundation overlay.
@_silgen_name("_swift_stdlib_getDefaultErrorCode")
public func _getDefaultErrorCode<T: Error>(_ error: T) -> Int

extension Error {
    public var _code: Int {
        return _getDefaultErrorCode(self)
    }
    
    public var _domain: String {
        return String(reflecting: type(of: self))
    }
    
    public var _userInfo: AnyObject? {
        #if _runtime(_ObjC)
        return _getErrorDefaultUserInfo(self)
        #else
        return nil
        #endif
    }
}

extension Error where Self: RawRepresentable, Self.RawValue: FixedWidthInteger {
    // The error code of Error with integral raw values is the raw value.
    public var _code: Int {
        if Self.RawValue.isSigned {
            return numericCast(self.rawValue)
        }
        
        let uintValue: UInt = numericCast(self.rawValue)
        return Int(bitPattern: uintValue)
    }
}
