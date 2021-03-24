import Foundation

// 为 HandyJSON 增加 extension, 这样, 所有继承了 HandyJSON 的 model, 都可以调用 deserialize 了.
// 这几个方法的主要作用是, 将自己的类型, 传递给了 JSONDeserializer
// 这种写法要熟悉, 相比之前, 传递类对象的方式, 泛型的引入, 使用 typename 传递类型会变得非常普遍.
public extension HandyJSON {

    static func deserialize(from dict: NSDictionary?, designatedPath: String? = nil) -> Self? {
        return deserialize(from: dict as? [String: Any], designatedPath: designatedPath)
    }

    static func deserialize(from dict: [String: Any]?, designatedPath: String? = nil) -> Self? {
        return JSONDeserializer<Self>.deserializeFrom(dict: dict, designatedPath: designatedPath)
    }

    static func deserialize(from json: String?, designatedPath: String? = nil) -> Self? {
        return JSONDeserializer<Self>.deserializeFrom(json: json, designatedPath: designatedPath)
    }
}


// Array 的反序列化相关配置.
// 还是把相关的逻辑, 放到了 JSONDeserializer 里面.
public extension Array where Element: HandyJSON {

    static func deserialize(from json: String?, designatedPath: String? = nil) -> [Element?]? {
        return JSONDeserializer<Element>.deserializeModelArrayFrom(json: json, designatedPath: designatedPath)
    }

    static func deserialize(from array: NSArray?) -> [Element?]? {
        return JSONDeserializer<Element>.deserializeModelArrayFrom(array: array)
    }

    static func deserialize(from array: [Any]?) -> [Element?]? {
        return JSONDeserializer<Element>.deserializeModelArrayFrom(array: array)
    }
}

// 这个类, 是真正的 JSON 的反序列化器.
// 所有的方法, 都是 static 方法, 实际上, 最终还是使用到了 T._transform 来生成最终的数据.
// 所以, 这里 T 的泛型, 仅仅是为了传递类型. JSONDeserializer 是一个工具类的概念.
public class JSONDeserializer<T: HandyJSON> {

    public static func deserializeFrom(dict: NSDictionary?, designatedPath: String? = nil) -> T? {
        return deserializeFrom(dict: dict as? [String: Any], designatedPath: designatedPath)
    }

    public static func deserializeFrom(dict: [String: Any]?, designatedPath: String? = nil) -> T? {
        // 首先是数据的读取过程, 这里不太明白, 为什么一直有一个 path. 难道这个类, 会有一个文件缓存的机制???
        var targetDict = dict
        if let path = designatedPath {
            targetDict = getInnerObject(inside: targetDict, by: path) as? [String: Any]
        }
        if let _dict = targetDict {
            // 最终, 是调用 transform 方法, 从 dict 数据里面, 抽取数据, 赋值到自己的属性里面.
            return T._transform(dict: _dict) as? T
        }
        return nil
    }

    /// Finds the internal JSON field in `json` as the `designatedPath` specified, and converts it to Model
    /// `designatedPath` is a string like `result.data.orderInfo`, which each element split by `.` represents key of each layer, or nil
    public static func deserializeFrom(json: String?, designatedPath: String? = nil) -> T? {
        guard let _json = json else {
            return nil
        }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: _json.data(using: String.Encoding.utf8)!, options: .allowFragments)
            if let jsonDict = jsonObject as? NSDictionary {
                return self.deserializeFrom(dict: jsonDict, designatedPath: designatedPath)
            }
        } catch let error {
            InternalLogger.logError(error)
        }
        return nil
    }

    /// Finds the internal dictionary in `dict` as the `designatedPath` specified, and use it to reassign an exist model
    /// `designatedPath` is a string like `result.data.orderInfo`, which each element split by `.` represents key of each layer, or nil
    public static func update(object: inout T, from dict: [String: Any]?, designatedPath: String? = nil) {
        var targetDict = dict
        if let path = designatedPath {
            targetDict = getInnerObject(inside: targetDict, by: path) as? [String: Any]
        }
        if let _dict = targetDict {
            T._transform(dict: _dict, to: &object)
        }
    }

    /// Finds the internal JSON field in `json` as the `designatedPath` specified, and use it to reassign an exist model
    /// `designatedPath` is a string like `result.data.orderInfo`, which each element split by `.` represents key of each layer, or nil
    public static func update(object: inout T, from json: String?, designatedPath: String? = nil) {
        guard let _json = json else {
            return
        }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: _json.data(using: String.Encoding.utf8)!, options: .allowFragments)
            if let jsonDict = jsonObject as? [String: Any] {
                update(object: &object, from: jsonDict, designatedPath: designatedPath)
            }
        } catch let error {
            InternalLogger.logError(error)
        }
    }

    /// if the JSON field found by `designatedPath` in `json` is representing a array, such as `[{...}, {...}, {...}]`,
    /// this method converts it to a Models array
    public static func deserializeModelArrayFrom(json: String?, designatedPath: String? = nil) -> [T?]? {
        guard let _json = json else {
            return nil
        }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: _json.data(using: String.Encoding.utf8)!, options: .allowFragments)
            if let jsonArray = getInnerObject(inside: jsonObject, by: designatedPath) as? [Any] {
                return jsonArray.map({ (item) -> T? in
                    return self.deserializeFrom(dict: item as? [String: Any])
                })
            }
        } catch let error {
            InternalLogger.logError(error)
        }
        return nil
    }

    /// mapping raw array to Models array
    public static func deserializeModelArrayFrom(array: NSArray?) -> [T?]? {
        return deserializeModelArrayFrom(array: array as? [Any])
    }

    /// mapping raw array to Models array
    public static func deserializeModelArrayFrom(array: [Any]?) -> [T?]? {
        guard let _arr = array else {
            return nil
        }
        return _arr.map({ (item) -> T? in
            return self.deserializeFrom(dict: item as? NSDictionary)
        })
    }
}

fileprivate func getInnerObject(inside object: Any?, by designatedPath: String?) -> Any? {
    var result: Any? = object
    var abort = false
    if let paths = designatedPath?.components(separatedBy: "."), paths.count > 0 {
        var next = object as? [String: Any]
        paths.forEach({ (seg) in
            if seg.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "" || abort {
                return
            }
            if let _next = next?[seg] {
                result = _next
                next = _next as? [String: Any]
            } else {
                abort = true
            }
        })
    }
    return abort ? nil : result
}
