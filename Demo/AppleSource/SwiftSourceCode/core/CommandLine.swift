import SwiftShims

/// Command-line arguments for the current process.
@frozen // namespace
public enum CommandLine {
  /// The backing static variable for argument count may come either from the
  /// entry point or it may need to be computed e.g. if we're in the REPL.
  @usableFromInline
  internal static var _argc: Int32 = Int32()

  /// The backing static variable for arguments may come either from the
  /// entry point or it may need to be computed e.g. if we're in the REPL.
  ///
  /// Care must be taken to ensure that `_swift_stdlib_getUnsafeArgvArgc` is
  /// not invoked more times than is necessary (at most once).
  @usableFromInline
  internal static var _unsafeArgv:
    UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
      =  _swift_stdlib_getUnsafeArgvArgc(&_argc)

  /// Access to the raw argc value from C.
  public static var argc: Int32 {
    _ = CommandLine.unsafeArgv // Force evaluation of argv.
    return _argc
  }

  /// Access to the raw argv value from C. Accessing the argument vector
  /// through this pointer is unsafe.
  public static var unsafeArgv:
    UnsafeMutablePointer<UnsafeMutablePointer<Int8>?> {
    return _unsafeArgv
  }

  /// Access to the Swift command line arguments.
  // Use lazy initialization of static properties to 
  // safely initialize the swift arguments.
  public static var arguments: [String]
    = (0..<Int(argc)).map { String(cString: _unsafeArgv[$0]!) }
}
