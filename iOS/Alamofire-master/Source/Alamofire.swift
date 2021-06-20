/// Reference to `Session.default` for quick bootstrapping and examples.
public let AF = Session.default

/// Current Alamofire version. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
// 在库的设计上, 应该设计这样的一个标识.
let version = "5.2.2"
