struct PropertyInfo {
    let key: String
    let type: Any.Type
    let address: UnsafeMutableRawPointer
    let bridged: Bool
}
