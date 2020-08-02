@_transparent
public func assert(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = String(),
    file: StaticString = #file, line: UInt = #line
) {
    // Only assert in debug mode.
    if _isDebugAssertConfiguration() { // 如果, 在 debug 模式下
        if !_fastPath(condition()) { // 如果, 条件没有满足, 注意, 这里是一个自动闭包. 所以, 可以传递一个函数进来.
            _assertionFailure("Assertion failed", message(), file: file, line: line,
                              flags: _fatalErrorFlags())
        }
    }
}

/// Checks a necessary condition for making forward progress.
///
/// Use this function to detect conditions that must prevent the program from
/// proceeding, even in shipping code.
/*
 precondition 在 Release 环境下, 也会造成崩溃.
 */
@_transparent
public func precondition(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = String(),
    file: StaticString = #file, line: UInt = #line
) {
    // Only check in debug and release mode. In release mode just trap.
    if _isDebugAssertConfiguration() {
        if !_fastPath(condition()) {
            _assertionFailure("Precondition failed", message(), file: file, line: line,
                              flags: _fatalErrorFlags())
        }
    } else if _isReleaseAssertConfiguration() {
        let error = !condition()
        Builtin.condfail_message(error._value,
                                 StaticString("precondition failure").unsafeRawPointer)
    }
}

/*
直接报错, 不进行 Bool 的判断
Release 模式无效.
*/
@inlinable
@inline(__always)
public func assertionFailure(
    _ message: @autoclosure () -> String = String(),
    file: StaticString = #file, line: UInt = #line
) {
    if _isDebugAssertConfiguration() {
        _assertionFailure("Fatal error", message(), file: file, line: line,
                          flags: _fatalErrorFlags())
    } else if _isFastAssertConfiguration() {
        _conditionallyUnreachable()
    }
}

/*
 直接报错, 不进行 Bool 的判断
 Release 模式有效.
 */
@_transparent
public func preconditionFailure(
    _ message: @autoclosure () -> String = String(),
    file: StaticString = #file, line: UInt = #line
) -> Never {
    // Only check in debug and release mode.  In release mode just trap.
    if _isDebugAssertConfiguration() {
        _assertionFailure("Fatal error", message(), file: file, line: line,
                          flags: _fatalErrorFlags())
    } else if _isReleaseAssertConfiguration() {
        Builtin.condfail_message(true._value,
                                 StaticString("precondition failure").unsafeRawPointer)
    }
    _conditionallyUnreachable()
}

/// Unconditionally prints a given message and stops execution.
///
/// - Parameters:
///   - message: The string to print. The default is an empty string.
///   - file: The file name to print with `message`. The default is the file
///     where `fatalError(_:file:line:)` is called.
///   - line: The line number to print along with `message`. The default is the
///     line number where `fatalError(_:file:line:)` is called.
@_transparent
public func fatalError(
    _ message: @autoclosure () -> String = String(),
    file: StaticString = #file, line: UInt = #line
) -> Never {
    _assertionFailure("Fatal error", message(), file: file, line: line,
                      flags: _fatalErrorFlags())
}

/// Library precondition checks.
///
/// Library precondition checks are enabled in debug mode and release mode. When
/// building in fast mode they are disabled.  In release mode they don't print
/// an error message but just trap. In debug mode they print an error message
/// and abort.
@usableFromInline @_transparent
internal func _precondition(
    _ condition: @autoclosure () -> Bool, _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) {
    // Only check in debug and release mode. In release mode just trap.
    if _isDebugAssertConfiguration() {
        if !_fastPath(condition()) {
            _assertionFailure("Fatal error", message, file: file, line: line,
                              flags: _fatalErrorFlags())
        }
    } else if _isReleaseAssertConfiguration() {
        let error = !condition()
        Builtin.condfail_message(error._value, message.unsafeRawPointer)
    }
}

@usableFromInline @_transparent
internal func _preconditionFailure(
    _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) -> Never {
    _precondition(false, message, file: file, line: line)
    _conditionallyUnreachable()
}

/// If `error` is true, prints an error message in debug mode, traps in release
/// mode, and returns an undefined error otherwise.
/// Otherwise returns `result`.
@_transparent
public func _overflowChecked<T>(
    _ args: (T, Bool),
    file: StaticString = #file, line: UInt = #line
) -> T {
    let (result, error) = args
    if _isDebugAssertConfiguration() {
        if _slowPath(error) {
            _fatalErrorMessage("Fatal error", "Overflow/underflow",
                               file: file, line: line, flags: _fatalErrorFlags())
        }
    } else {
        Builtin.condfail_message(error._value,
                                 StaticString("_overflowChecked failure").unsafeRawPointer)
    }
    return result
}


/// Debug library precondition checks.
///
/// Debug library precondition checks are only on in debug mode. In release and
/// in fast mode they are disabled. In debug mode they print an error message
/// and abort.
/// They are meant to be used when the check is not comprehensively checking for
/// all possible errors.
@usableFromInline @_transparent
internal func _debugPrecondition(
    _ condition: @autoclosure () -> Bool, _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) {
    // Only check in debug mode.
    if _slowPath(_isDebugAssertConfiguration()) {
        if !_fastPath(condition()) {
            _fatalErrorMessage("Fatal error", message, file: file, line: line,
                               flags: _fatalErrorFlags())
        }
    }
}

@usableFromInline @_transparent
internal func _debugPreconditionFailure(
    _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) -> Never {
    if _slowPath(_isDebugAssertConfiguration()) {
        _precondition(false, message, file: file, line: line)
    }
    _conditionallyUnreachable()
}

/// Internal checks.
///
/// Internal checks are to be used for checking correctness conditions in the
/// standard library. They are only enable when the standard library is built
/// with the build configuration INTERNAL_CHECKS_ENABLED enabled. Otherwise, the
/// call to this function is a noop.
@usableFromInline @_transparent
internal func _internalInvariant(
    _ condition: @autoclosure () -> Bool, _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) {
    #if INTERNAL_CHECKS_ENABLED
    if !_fastPath(condition()) {
        _fatalErrorMessage("Fatal error", message, file: file, line: line,
                           flags: _fatalErrorFlags())
    }
    #endif
}

// Only perform the invariant check on Swift 5.1 and later
@_alwaysEmitIntoClient // Swift 5.1
@_transparent
internal func _internalInvariant_5_1(
    _ condition: @autoclosure () -> Bool, _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) {
    #if INTERNAL_CHECKS_ENABLED
    // FIXME: The below won't run the assert on 5.1 stdlib if testing on older
    // OSes, which means that testing may not test the assertion. We need a real
    // solution to this.
    guard #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) else { return }
    _internalInvariant(condition(), message, file: file, line: line)
    #endif
}

@usableFromInline @_transparent
internal func _internalInvariantFailure(
    _ message: StaticString = StaticString(),
    file: StaticString = #file, line: UInt = #line
) -> Never {
    _internalInvariant(false, message, file: file, line: line)
    _conditionallyUnreachable()
}
