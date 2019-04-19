#ifndef __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif
    
    @class NSArray;
    @class NSMutableArray;
    @class NSSet;
    @class NSMutableSet;
    @class NSDictionary;
    @class NSError;
    @class NSString;
    
    /** An exception for an unknown key in [NSObject(NSKeyValueCoding)]. */
    GS_EXPORT NSString* const NSUndefinedKeyException;
    
    /**
     whereby 就是 bywhere
     
     KVC 是一种机制, 可以使得对象的字段可以用一种通用的方式进行访问, 这种方式是和字符串的 key 值一起使用的.
     通过这种方式, 就可以不再使用字段相关的方法了. KVC 失去了编译时的方法检查, 但是在某些情况下能够带来灵活性.
     
     * <p>This describes an informal protocol for <em>key-value coding</em>, a
     * mechanism whereby the fields of an object may be accessed and set using
     * generic methods in conjunction with string keys rather than field-specific
     * methods.  Key-based access loses compile-time validity checking, but can be
     * convenient in certain kinds of situations.</p>
     *
     
     KVC 是通过 NSObject 的分类完成的. 特定的类可以重写实现来达到自己的目的.
     
     * <p>The basic methods are implemented as a category of the [NSObject] class,
     * but other classes override those default implementations to perform more
     * specific operations.</p>
     */
    @interface NSObject (NSKeyValueCoding)

/**
 控制, 该类在使用 kvc 的时候, 可不可以直接访问实例变量的值. 这种情况一般出现在类中没有找到对应的方法的时候.
 * Controls whether the NSKeyValueCoding methods may attempt to
 * access instance variables directly.
 * NSObject's implementation returns YES.
 */
+ (BOOL) accessInstanceVariablesDirectly;

/**
 * Controls whether -storedValueForKey: and -takeStoredValue:forKey: may use
 * the stored accessor mechanism.  If not the calls get redirected to
 * -valueForKey: and -takeValue:forKey: effectively changing the search order
 * of private/public accessor methods and instance variables.
 * NSObject's implementation returns YES.
 */
+ (BOOL) useStoredAccessor;

/**
 返回一个字典, 这个字段的 keys 是传入的这些值. 默认情况下, value 是通过各个key 值的 valueForKey 函数取得的, 如果 valueForKey nil, 返回 NSNull
 * Returns a dictionary built from values obtained for the specified keys.<br />
 * By default this is derived by calling -valueForKey: for each key.
 * Any nil values obtained are represented by an [NSNull] instance.
 */
- (NSDictionary*) dictionaryWithValuesForKeys: (NSArray*)keys;

/**
 * Returns a mutable array value for a given key. This method:
 * <list>
 *  <item>Searches the receiver for methods matching the patterns
 *   insertObject:in&lt;Key&gt;AtIndex: and
 *   removeObjectFrom&lt;Key&gt;AtIndex:. If both
 *   methods are found, each message sent to the proxy array will result in the
 *   invocation of one or more of these methods. If
 *   replaceObjectIn&lt;Key&gt;AtIndex:withObject:
 *   is also found in the receiver it
 *   will be used when appropriate for better performance.</item>
 *  <item>If the set of methods is not found, searches the receiver for a the
 *   method set&lt;Key&gt;:. Each message sent to the proxy array will result in
 *   the invocation of set&lt;Key&gt;:</item>
 *  <item>If the previous do not match, and accessInstanceVariablesDirectly
 *   returns YES, searches for an instance variable matching _&lt;key&gt; or
 *   &lt;key&gt; (in that order). If the instance variable is found,
 *   messages sent
 *   to the proxy object will be forwarded to the instance variable.</item>
 *  <item>If none of the previous are found, raises an NSUndefinedKeyException
 *  </item>
 * </list>
 */
- (NSMutableArray*) mutableArrayValueForKey: (NSString*)aKey;

/**
 * Returns a mutable array value for the given key path.
 */
- (NSMutableArray*) mutableArrayValueForKeyPath: (NSString*)aKey;

/**
 * Returns a mutable set value for a given key. This method:
 * <list>
 *  <item>Searches the receiver for methods matching the patterns
 *   add&lt;Key&gt;Object:, remove&lt;Key&gt;Object:,
 *   add&lt;Key&gt;:, and remove&lt;Key&gt;:, which
 *   correspond to the NSMutableSet methods addObject:, removeObject:,
 *   unionSet:, and minusSet:, respectively. If at least one addition
 *   and one removal method are found, each message sent to the proxy set
 *   will result in the invocation of one or more of these methods. If
 *   intersect&lt;Key&gt;: or set&lt;Key&gt;:
 *   is also found in the receiver, the method(s)
 *   will be used when appropriate for better performance.</item>
 *  <item>If the set of methods is not found, searches the receiver for a the
 *   method set&lt;Key&gt;:. Each message sent to the proxy set will result in
 *   the invocation of set&lt;Key&gt;:</item>
 *  <item>If the previous do not match, and accessInstanceVariablesDirectly
 *   returns YES, searches for an instance variable matching _&lt;key&gt; or
 *   &lt;key&gt; (in that order). If the instance variable is found,
 *   messages sent
 *   to the proxy object will be forwarded to the instance variable.</item>
 *  <item>If none of the previous are found, raises an NSUndefinedKeyException
 *  </item>
 * </list>
 */
- (NSMutableSet*) mutableSetValueForKey: (NSString *)aKey;

/**
 * Returns a mutable set value for the given key path.
 */
- (NSMutableSet*) mutableSetValueForKeyPath: (NSString*)aKey;

/**
 这个方法, 会在 KVC 机制中, 当把一个 nil 赋值给基本数据类型属性的时候出发. 默认情况下, 会引起崩溃.
 * This method is invoked by the NSKeyValueCoding mechanism when an attempt
 * is made to set an null value for a scalar attribute.  This implementation
 * raises an NSInvalidArgument exception.  Subclasses my override this method
 * to do custom handling. (E.g. setting the value to the equivalent of 0.)
 */
- (void) setNilValueForKey: (NSString*)aKey;

/**
 为接受者的 key 相关的属性进行赋值.
 如果value 可以转化为基本数据类型, 那么其中会进行自动转化.
 首先, 会去寻找 setKey 这个方法是否存在, 如果没有找到, 并且, accessInstanceVariablesDirectly 这个方法返回为 YES 的话, 会按照以下名字寻找成员变量.
 _key, _isKey, key, isKey.
 如果set 方法没有找到, 上面的变量也没有找到, 就调用 setValue:forUndefinedKey. 默认这个方法, 会引发一场. 如果属性希望得到的是 基本数据类型, 而 value 是 nil, 那么会调用 setNilValueForKey, 而这个方法, 会引发异常.
 * Sets the value if the attribute associated with the key in the receiver.
 * The object is converted to a scalar attribute where applicable (and
 * -setNilValueForKey: is called if a nil value is supplied).
 * Tries to use a standard accessor of the form setKey: where 'Key' is the
 * supplied argument with the first letter converted to uppercase.<br />
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>_isKey</item>
 *  <item>key</item>
 *  <item>isKey</item>
 * </list>
 * Invokes -setValue:forUndefinedKey: if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accessor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes
 * -setNilValueForKey: .
 */
- (void) setValue: (id)anObject forKey: (NSString*)aKey;

/**
    该方法会获取到最后一个 path 所依附的对象, 获取的方法是, 递归调用 value for key. 这个获取的数据, 是根据 . 进行分割的.
 * Retrieves the object returned by invoking -valueForKey:
 * on the receiver with the first key component supplied by the key path.
 * Then invokes -setValue:forKeyPath: recursively on the
 * returned object with rest of the key path.
 * The key components are delimited by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes -setValue:forKey:.
 */
- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey;

/**
 如果 找不到方法和变量的话, 就调用这个方法, 默认是引起崩溃.
 * Invoked when -setValue:forKey: / -takeStoredValue:forKey: are called with
 * a key which can't be associated with an accessor method or instance
 * variable.  Subclasses may override this method to add custom handling.
 * NSObject raises an NSUndefinedKeyException, with a userInfo dictionary
 * containing NSTargetObjectUserInfoKey with the receiver an
 * NSUnknownUserInfoKey with the supplied key entries.<br />
 * Called when the key passed to -setValue:forKey: cannot be used.
 */
- (void) setValue: (id)anObject forUndefinedKey: (NSString*)aKey;

/**
 通过遍历 aDictionary, 使用 setValueForKey 这种方式.
 * Uses -setValue:forKey: to place the values from aDictionary in the
 * receiver.
 */
- (void) setValuesForKeysWithDictionary: (NSDictionary*)aDictionary;

/**
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.
 * Uses private accessors in favor of the public ones, if the receiver's
 * class allows +useStoredAccessor.  Otherwise this method invokes
 * -valueForKey:.
 * The search order is:<br/>
 * Private accessor methods:
 * <list>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>key</item>
 * </list>
 * Public accessor methods:
 * <list>
 *  <item>getKey</item>
 *  <item>key</item>
 * </list>
 * Invokes -handleTakeValue:forUnboundKey: if no accessor mechanism can be
 * found and raises NSInvalidArgumentException if the accessor method takes
 * takes any arguments or the type is unsupported (e.g. structs).
 */
- (id) storedValueForKey: (NSString*)aKey;

/**
 * Sets the value associated with the supplied in the receiver.
 * The object is converted to the scalar attribute where applicable.
 * Uses the private accessors in favor of the public ones, if the
 * receiver's class allows +useStoredAccessor .
 * Otherwise this method invokes -takeValue:forKey: .
 * The search order is:<br/>
 * Private accessor methods:
 * <list>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>key</item>
 * </list>
 * Public accessor methods:
 * <list>
 *  <item>setKey:</item>
 * </list>
 * Invokes -handleTakeValue:forUnboundKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accessor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes
 * -unableToSetNilForKey: .
 */
- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey;

/**
 * Iterates over the dictionary invoking -takeStoredValue:forKey:
 * on the receiver for each key-value pair, converting NSNull to nil.
 */
- (void) takeStoredValuesFromDictionary: (NSDictionary*)aDictionary;

/**
 * Sets the value if the attribute associated with the key in the receiver.
 * The object is converted to a scalar attribute where applicable.
 * Uses the public accessors in favor of the private ones.
 * The search order is:<br/>
 * Accessor methods:
 * <list>
 *  <item>setKey:</item>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes -handleTakeValue:forUnboundKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accessor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes
 * -unableToSetNilForKey: .<br />
 * Deprecated ... use -setValue:forKey: instead.
 */
- (void) takeValue: (id)anObject forKey: (NSString*)aKey;

/**
 * Retrieves the object returned by invoking -valueForKey:
 * on the receiver with the first key component supplied by the key path.
 * Then invokes -takeValue:forKeyPath: recursively on the
 * returned object with rest of the key path.
 * The key components are delimited by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes -takeValue:forKey:.<br />
 * Deprecated ... use -setValue:forKeyPath: instead.
 */
- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey;

/**
 * Iterates over the dictionary invoking -takeValue:forKey:
 * on the receiver for each key-value pair, converting NSNull to nil.<br />
 * Deprecated ... use -setValuesForKeysWithDictionary: instead.
 */
- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary;

/**
 * Deprecated ... use -setNilValueForKey: instead.
 */
- (void) unableToSetNilForKey: (NSString*)aKey;


/**
 * Returns a boolean indicating whether the object pointed to by aValue
 * is valid for setting as an attribute of the receiver using the name
 * aKey.  On success (YES response) it may return a new value to be used
 * in aValue.  On failure (NO response) it may return an error in anError.<br />
 * The method works by calling a method of the receiver whose name is of
 * the form validateKey:error: if the receiver has implemented such a
 * method, otherwise it simply returns YES.
 */
- (BOOL) validateValue: (id*)aValue
                forKey: (NSString*)aKey
                 error: (out NSError**)anError;

/**
 * Returns the result of calling -validateValue:forKey:error: on the receiver
 * using aPath to determine the key value in the same manner as the
 * -valueForKeyPath: method.
 */
- (BOOL) validateValue: (id*)aValue
            forKeyPath: (NSString*)aKey
                 error: (out NSError**)anError;

/**
 
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.<br />
 * The search order is:<br/>
 * Accessor methods:
 * <list>
 *  <item>getKey</item>
 *  <item>key</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with private accessors:
 * <list>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * and then instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes -setValue:forUndefinedKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accessor method takes
 * any arguments or the type is unsupported (e.g. structs).
 */
- (id) valueForKey: (NSString*)aKey;

/**
 * Returns the object returned by invoking -valueForKeyPath:
 * recursively on the object returned by invoking -valueForKey:
 * on the receiver with the first key component supplied by the key path.
 * The key components are delimited by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes -valueForKey: .
 */
- (id) valueForKeyPath: (NSString*)aKey;

/**
 * Invoked when -valueForKey: / -storedValueForKey: are called with a key,
 * which can't be associated with an accessor method or instance variable.
 * Subclasses may override this method to add custom handling.  NSObject
 * raises an NSUndefinedKeyException, with a userInfo dictionary containing
 * NSTargetObjectUserInfoKey with the receiver an NSUnknownUserInfoKey with
 * the supplied key entries.<br />
 */
- (id) valueForUndefinedKey: (NSString*)aKey;

/**
 * Iterates over the array sending the receiver -valueForKey:
 * for each object in the array and inserting the result in a dictionary.
 * All nil values returned by -valueForKey: are replaced by the
 * NSNull instance in the dictionary.
 */
- (NSDictionary*) valuesForKeys: (NSArray*)keys;

@end
    
#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif

