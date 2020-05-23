#ifndef __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE
#import    <GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#if    defined(__cplusplus)
extern "C" {
#endif
    
#import    <Foundation/NSCoder.h>
#import    <Foundation/NSMapTable.h>
#import    <Foundation/NSPropertyList.h>
    
    
    
/*
 
 
 @interface A : NSError <NSCoding>
 
 @property (nonatomic, strong) A *value;
 @property (nonatomic, assign) int age;
 @property (nonatomic, strong) NSString *desc;
 @property (nonatomic, strong) NSString *title;
 
 @end
 
 @implementation A
 
 - (instancetype)initWithCoder:(NSCoder *)aDecoder {
 self = [super init];
 if (self) {
 _value = [aDecoder decodeObjectForKey:@"relation"];
 _age = [aDecoder decodeIntegerForKey:@"age"];
 _title = [aDecoder decodeObjectForKey:@"title"];
 _desc = [aDecoder decodeObjectForKey:@"desc"];
 }
 return self;
 }
 
 - (void)encodeWithCoder:(NSCoder *)aCoder {
 [aCoder encodeObject:_value forKey:@"relation"];
 [aCoder encodeInteger:_age forKey:@"age"];
 [aCoder encodeObject:_title forKey:@"title"];
 [aCoder encodeObject:_desc forKey:@"desc"];
 }
 
 @end
 
 A *value_1 = [[A alloc] init];
 A *value_2 = [[A alloc] init];
 value_1.value = value_2;
 value_1.age = 1;
 value_1.title = @"1_ttitle";
 value_1.desc = @"1 desc";
 value_2.value = value_1;
 value_2.age = 2;
 value_2.title = @"2_title";
 value_2.desc = @"2_desc";
 
 BOOL result = [NSKeyedArchiver archiveRootObject:value_1 toFile:@"/Users/justinlau/Work/Character/temp.plist"];
 NSLog(@"%@", @(result));
 A *unValues = [NSKeyedUnarchiver unarchiveObjectWithFile:@"/Users/justinlau/Work/Character/temp.plist"];

 上面是一个小的 demo, 归档解档成功了.
 这个类过程过于复杂, 只看最后的结果. 下面的 NSKeyedArchiver.plist 是归档之后的结果. 从结果上来看, KeyedArchiver 这个类是把所有的需要进行归档的对象, 都放到了一个数组里面, 然后之间的关系就用了数组的下标进行提现. 这个数组是从 1 开始计数的, 并且这个数组里面, 处理记录对象, 还记录了类对象的信息, 类对象的信息就是类的名称以及类的继承关系. 对于自定义的数据类型, 例如上面 A 对象, 里面记录这个类的 class, 然后用一个 id 指代这个 class 到底是哪个类对象. 然后, 对象里面的指针关系, 也是用的 id 的方式, 指代数组里面的某个对象. 这里, id 都是用的下标的这种方式.
 通过这种方式, 所有的需要进行归档的对象, 只会归档一次. 这就避免了循环归档和重复归档的过程.
 在解档的时候, 如果我来实现这块逻辑, 会通过数组里面的信息, 首先 alloc 所有的数组里面的对象, 建立的对象的类型, 就根据里面记录的类信息进行创建. 这仅仅是 alloc, 对象里面能够确定的也就是一个 isa 指针. 然后, 就可以数组中各个对象的具体进行, 进行初始化的工作. 这个舒适化工作, 铁定是调用了 decodeObjectForKey, 在这个逻辑里面, 如果是基本数据类型, 直接进行成员变量的赋值操作, 如果是关系指针的成员变量, 那就根据这个 key 所记录的 id 信息, 去数组的响应位置, 取响应的指针, 然后进行赋值.
 
 在没有归档前的对象里面, 所有的对象都在内存里面, 然后所有的关系是通过指针进行确定的. 我们把内存看做一个超级大的数组, 所有的对象, 都是独一无二没有第二份的. 但是我们在归档的时候, 是不可能有这么一个无线的空间的, 所以我们将所有要归档的对象, 放到一个数组里面, 相当于我们手动的对这个数组大内存进行了压缩, 压缩后的所有对象, 都是我们要进行归档的对象. 这样, 数组的下标就可以充当指针的作用, 指代关系类型的成员变量的值.
 这种技巧, 应该是很常见的.
 
 在 id 的存储的过程中, 归档文件是用 CF$UID 进行存储的, 这样在 plist 文件打开的时候, 是看不到这个 entry 的. 这应该是 xcode 的隐藏配置.

 
 */
    
    @class NSMutableDictionary, NSMutableData, NSData, NSString;
    
    /**
     *  Implements <em>keyed</em> archiving of object graphs.  This archiver
     *  should be used instead of [NSArchiver] for new implementations.  Classes
     *  implementing [(NSCoding)] should check the [NSCoder-allowsKeyedCoding]
     *  method and if the response is YES, encode/decode their fields using the
     *  <code>...forKey:</code> [NSCoder] methods, which provide for more robust
     *  forwards and backwards compatibility.
     */
    @interface NSKeyedArchiver : NSCoder
{
#if    GS_EXPOSE(NSKeyedArchiver)
@private
    NSMutableData    *_data;        /* Data to write into.        */
    id        _delegate;    /* Delegate controls operation.    */
    NSMapTable    *_clsMap;    /* Map classes to names.    */
#ifndef    _IN_NSKEYEDARCHIVER_M
#define    GSIMapTable    void*
#endif
    GSIMapTable    _cIdMap;    /* Conditionally coded.        */
    GSIMapTable    _uIdMap;    /* Unconditionally coded.    */
    GSIMapTable    _replaceMentMap;    /* Mappings for objects.    */
#ifndef    _IN_NSKEYEDARCHIVER_M
#undef    GSIMapTable
#endif
    unsigned    _keyNum;    /* Counter for keys in object.    */
    NSMutableDictionary    *_encodeObjectDictM;    /* Object being encoded.    */
    NSMutableArray    *_encodeObjectsArrayM;    /* Array of objects.        */
    NSPropertyListFormat    _format;
#endif
#if     GS_NONFRAGILE
#else
    /* Pointer to private additional data used to avoid breaking ABI
     * when we don't have the non-fragile ABI available.
     * Use this mechanism rather than changing the instance variable
     * layout (see Source/GSInternal.h for details).
     */
@private id _internal GS_UNUSED_IVAR;
#endif
}

/**
 * Encodes anObject and returns the resulting data object.
 */
+ (NSData*) archivedDataWithRootObject: (id)anObject;

/**
 * Encodes anObject and writes the resulting data ti aPath.
 */
+ (BOOL) archiveRootObject: (id)anObject toFile: (NSString*)aPath;

/**
 * Returns the class name with which the NSKeyedArchiver class will encode
 * instances of aClass, or nil if no name mapping has been set using the
 * +setClassName:forClass: method.
 */
+ (NSString*) classNameForClass: (Class)aClass;

/**
 * Sets the class name with which the NSKeyedArchiver class will encode
 * instances of aClass.  This mapping is used only if no class name
 * mapping has been set for the individual instance of NSKeyedArchiver
 * being used.<br />
 * The value of aString must be the name of an existing class.<br />
 * If the value of aString is nil, any mapping for aClass is removed.
 */
+ (void) setClassName: (NSString*)aString forClass: (Class)aClass;

/**
 * Returns any mapping for the name of aClass which was previously set
 * for the receiver using the -setClassName:forClass: method.<br />
 * Returns nil if no such mapping exists, even if one has been set
 * using the class method +setClassName:forClass:
 */
- (NSString*) classNameForClass: (Class)aClass;

/**
 * Returns the delegate set for the receiver, or nil of none is set.
 */
- (id) delegate;

/**
 * Encodes aBool and associates the encoded value with aKey.
 */
- (void) encodeBool: (BOOL)aBool forKey: (NSString*)aKey;

/**
 * Encodes the data of the specified length and pointed to by aPointer,
 * and associates the encoded value with aKey.
 */
- (void) encodeBytes: (const uint8_t*)aPointer
              length: (int)length
              forKey: (NSString*)aKey;

/**
 * Encodes anObject and associates the encoded value with aKey, but only
 * if anObject has already been encoded using -encodeObject:forKey:
 */
- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey;

/**
 * Encodes aDouble and associates the encoded value with aKey.
 */
- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey;

/**
 * Encodes aFloat and associates the encoded value with aKey.
 */
- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey;

/**
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey;

/**
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey;

/**
 * Encodes anInteger and associates the encoded value with aKey.
 */
- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey;

/**
 * Encodes anObject and associates the encoded value with aKey.
 */
- (void) encodeObject: (id)anObject forKey: (NSString*)aKey;

/**
 * Ends the encoding process and causes the encoded archive to be placed
 * in the mutable data object supplied when the receiver was initialised.<br />
 * This method must be called at the end of encoding, and nothing may be
 * encoded after this method is called.
 */
- (void) finishEncoding;

/**
 * Initialise the receiver to encode an archive into the supplied
 * data object.
 */
- (id) initForWritingWithMutableData: (NSMutableData*)data;

/**
 * Returns the output format of the archived data ... this should default
 * to the MacOS-X binary format, but we don't support that yet, so the
 * -setOutputFormat: method should be used to set a supported format.
 */
- (NSPropertyListFormat) outputFormat;

/**
 * Sets the name with which instances of aClass are encoded.<br />
 * The value of aString must be the name of an existing class.
 */
- (void) setClassName: (NSString*)aString forClass: (Class)aClass;

/**
 * Sets the receivers delegate.  The delegate should conform to the
 * NSObject(NSKeyedArchiverDelegate) informal protocol.<br />
 * NB. the delegate is not retained, so you must ensure that it is not
 * deallocated before the archiver has finished with it.
 */
- (void) setDelegate: (id)anObject;

/**
 * Specifies the output format of the archived data ... this should default
 * to the MacOS-X binary format, but we don't support that yet, so the
 * -setOutputFormat: method should be used to set a supported format.
 */
- (void) setOutputFormat: (NSPropertyListFormat)format;

@end
    
    
    
    /**
     *  Implements <em>keyed</em> unarchiving of object graphs.  The keyed archiver
     *  should be used instead of [NSArchiver] for new implementations.  Classes
     *  implementing [(NSCoding)] should check the [NSCoder-allowsKeyedCoding]
     *  method and if the response is YES, encode/decode their fields using the
     *  <code>...forKey:</code> [NSCoder] methods, which provide for more robust
     *  forwards and backwards compatibility.
     */
    @interface NSKeyedUnarchiver : NSCoder
{
#if    GS_EXPOSE(NSKeyedUnarchiver)
@private
    NSDictionary    *_archive;
    id        _delegate;    /* Delegate controls operation.    */
    NSMapTable    *_clsMap;    /* Map classes to names.    */
    NSArray    *_objects;    /* All encoded objects.        */
    NSDictionary    *_keyMap;    /* Local object name table.    */
    unsigned    _cursor;    /* Position in object.        */
    NSString    *_archiverClass;
    NSString    *_version;
#ifndef    _IN_NSKEYEDUNARCHIVER_M
#define    GSIArray    void*
#endif
    GSIArray        _objMap; /* Decoded objects.        */
#ifndef    _IN_NSKEYEDUNARCHIVER_M
#undef    GSIArray
#endif
    NSZone    *_zone;        /* Zone for allocating objs.    */
#endif
#if     GS_NONFRAGILE
#else
    /* Pointer to private additional data used to avoid breaking ABI
     * when we don't have the non-fragile ABI available.
     * Use this mechanism rather than changing the instance variable
     * layout (see Source/GSInternal.h for details).
     */
@private id _internal GS_UNUSED_IVAR;
#endif
}

/**
 * Returns class substituted for class name specified by aString when
 * encountered in the archive being decoded from, or nil if there is no
 * specific translation mapping.  Each instance also maintains a translation
 * map, which is searched first for a match during decoding.
 */
+ (Class) classForClassName: (NSString*)aString;

/**
 * Sets class substituted for class name specified by aString when
 * encountered in the archive being decoded from, or nil if there is no
 * specific translation mapping.  Each instance also maintains a translation
 * map, which is searched first for a match during decoding.
 */
+ (void) setClass: (Class)aClass forClassName: (NSString*)aString;

/**
 *  Decodes from byte array in data and returns resulting root object.
 */
+ (id) unarchiveObjectWithData: (NSData*)data;

/**
 *  Decodes from file contents at aPath and returns resulting root object.
 */
+ (id) unarchiveObjectWithFile: (NSString*)aPath;

/**
 * Returns class substituted for class name specified by aString when
 * encountered in the archive being decoded from, or nil if there is no
 * specific translation mapping.  The class as a whole also maintains a
 * translation map, which is searched on decoding if no match found here.
 */
- (Class) classForClassName: (NSString*)aString;

/**
 * Sets class substituted for class name specified by aString when
 * encountered in the archive being decoded from, or nil if there is no
 * specific translation mapping.  Each instance also maintains a translation
 * map, which is searched first for a match during decoding.
 */
- (BOOL) containsValueForKey: (NSString*)aKey;

/**
 * Sets class substituted for class name specified by aString when
 * encountered in the archive being decoded from, or nil if there is no
 * specific translation mapping.  Each instance also maintains a translation
 * map, which is searched first for a match during decoding.
 */
- (void) setClass: (Class)aClass forClassName: (NSString*)aString;

/**
 * Returns a boolean value associated with aKey.  This value must previously
 * have been encoded using -encodeBool:forKey:
 */
- (BOOL) decodeBoolForKey: (NSString*)aKey;

/**
 * Returns a pointer to a byte array associated with aKey.<br />
 * Returns the length of the data in aLength.<br />
 * This value must previously have been encoded using
 * -encodeBytes:length:forKey:
 */
- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
                      returnedLength: (NSUInteger*)length;

/**
 * Returns a double value associated with aKey.  This value must previously
 * have been encoded using -encodeDouble:forKey: or -encodeFloat:forKey:
 */
- (double) decodeDoubleForKey: (NSString*)aKey;

/**
 * Returns a float value associated with aKey.  This value must previously
 * have been encoded using -encodeFloat:forKey: or -encodeDouble:forKey:<br />
 * Precision may be lost (or an exception raised if the value will not fit
 * in a float) if the value was encoded using -encodeDouble:forKey:,
 */
- (float) decodeFloatForKey: (NSString*)aKey;

/**
 * Returns an integer value associated with aKey.  This value must previously
 * have been encoded using -encodeInt:forKey:, -encodeInt32:forKey:, or
 * -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in an integer.
 */
- (int) decodeIntForKey: (NSString*)aKey;

/**
 * Returns a 32-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in a 32-bit integer.
 */
- (int32_t) decodeInt32ForKey: (NSString*)aKey;

/**
 * Returns a 64-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.
 */
- (int64_t) decodeInt64ForKey: (NSString*)aKey;

/**
 * Returns an object value associated with aKey.  This value must
 * previously have been encoded using -encodeObject:forKey: or
 * -encodeConditionalObject:forKey:
 */
- (id) decodeObjectForKey: (NSString*)aKey;

/**
 * Returns the delegate of the unarchiver.
 */
- (id) delegate;

/**
 * Tells receiver that you are done retrieving from archive, so the delegate
 * should be allowed to perform close-up operations.
 */
- (void) finishDecoding;

/**
 * Prepare to read data from key archive (created by [NSKeyedArchiver]).
 * Be sure to call -finishDecoding when done.
 */
- (id) initForReadingWithData: (NSData*)data;

/**
 * Sets the receivers delegate.  The delegate should conform to the
 * NSObject(NSKeyedUnarchiverDelegate) informal protocol.<br />
 * NB. the delegate is not retained, so you must ensure that it is not
 * deallocated before the unarchiver has finished with it.
 */
- (void) setDelegate: (id)delegate;

@end
    
    /**
     * Internal methods.  Do not use.
     */
    @interface    NSKeyedArchiver (Internal)
- (void) _encodeArrayOfObjects: (NSArray*)anArray forKey: (NSString*)aKey;
- (void) _encodePropertyList: (id)anObject forKey: (NSString*)aKey;
@end
    
    /**
     * Internal methods.  Do not use.
     */
    @interface    NSKeyedUnarchiver (Internal)
- (id) _decodeArrayOfObjectsForKey: (NSString*)aKey;
- (id) _decodePropertyListForKey: (NSString*)aKey;
- (BOOL) replaceObject: (id)oldObj withObject: (id)newObj;
@end
    
    
    /* Exceptions */
    GS_EXPORT NSString * const NSInvalidArchiveOperationException;
    GS_EXPORT NSString * const NSInvalidUnarchiveOperationException;
    
    
    /**
     * Informal protocol implemented by delegates of [NSKeyedArchiver].
     */
    @interface NSObject (NSKeyedArchiverDelegate)

/**
 * Sent when encoding of anObject has completed <em>except</em> in the case
 * of conditional encoding.
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver didEncodeObject: (id)anObject;

/**
 * Sent when anObject is about to be encoded (or conditionally encoded)
 * and provides the receiver with an opportunity to change the actual
 * object stored into the archive by returning a different value (otherwise
 * it should return anObject).<br />
 * The method is not called for encoding of nil or for encoding of any
 * object for which has already been called.<br />
 * The method is called <em>after</em> the -replacementObjectForKeyedArchiver:
 * method.
 */
- (id) archiver: (NSKeyedArchiver*)anArchiver willEncodeObject: (id)anObject;

/**
 * Sent when the encoding process is complete.
 */
- (void) archiverDidFinish: (NSKeyedArchiver*)anArchiver;

/**
 * Sent when the encoding process is about to finish.
 */
- (void) archiverWillFinish: (NSKeyedArchiver*)anArchiver;

/**
 * Sent whenever object replacement occurs during encoding, either by the
 * -replacementObjectForKeyedArchiver: method or because the delegate has
 * returned a changed value using the -archiver:willEncodeObject: method.
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver
willReplaceObject: (id)anObject
       withObject: (id)newObject;

@end
    
    
    
    /**
     * Informal protocol implemented by delegates of [NSKeyedUnarchiver].
     */
    @interface NSObject (NSKeyedUnarchiverDelegate)

/**
 * Sent if the named class is not available during decoding.<br />
 * The value of aName is the class name being decoded (after any name mapping
 * has been applied).<br />
 * The classNames array contains the original name of the class encoded
 * in the archive, and is followed by each of its superclasses in turn.<br />
 * The delegate may either return a class object for the unarchiver to use
 * to continue decoding, or may return nil to abort the decoding process.
 */
- (Class) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
cannotDecodeObjectOfClassName: (NSString*)aName
     originalClasses: (NSArray*)classNames;

/**
 * Sent when anObject is decoded.  The receiver may return either anObject
 * or some other object (including nil).  If a value other than anObject is
 * returned, it is used to replace anObject.
 */
- (id) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  didDecodeObject: (id)anObject;

/**
 * Sent when unarchiving is about to complete.
 */
- (void) unarchiverDidFinish: (NSKeyedUnarchiver*)anUnarchiver;

/**
 * Sent when unarchiving has been completed.
 */
- (void) unarchiverWillFinish: (NSKeyedUnarchiver*)anUnarchiver;

/**
 * Sent whenever object replacement occurs during decoding, eg by the
 * -replacementObjectForKeyedArchiver: method.
 */
- (void) unarchiver: (NSKeyedUnarchiver*)anUnarchiver
  willReplaceObject: (id)anObject
         withObject: (id)newObject;

@end
    
    
    
    /**
     * Methods by which a class may control its archiving by the [NSKeyedArchiver].
     */
    @interface NSObject (NSKeyedArchiverObjectSubstitution)

/**
 * This message is sent to objects being encoded, to allow them to choose
 * to be encoded a different class.  If this returns nil it is treated as
 * if it returned the class of the object.<br />
 * After this method is applied, any class name mapping set in the archiver
 * is applied to its result.<br />
 * The default implementation returns the result of the -classForArchiver
 * method.
 */
- (Class) classForKeyedArchiver;

/**
 * This message is sent to objects being encoded, to allow them to choose
 * to be encoded a different object by returning the alternative object.<br />
 * The default implementation returns the result of calling
 * the -replacementObjectForArchiver: method with a nil argument.<br />
 * This is called only if no mapping has been set up in the archiver already.
 */
- (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver*)archiver;

@end
    
    /**
     * Methods by which a class may control its unarchiving by the
     * [NSKeyedArchiver].
     */
    @interface NSObject (NSKeyedUnarchiverObjectSubstitution)

/**
 * Sent during unarchiving to permit classes to substitute a different
 * class for decoded instances of themselves.<br />
 * Default implementation returns the receiver.<br />
 * Overrides the mappings set up within the receiver.
 */
+ (Class) classForKeyedUnarchiver;

@end
    
    /**
     *  Methods for encoding/decoding points, rectangles, and sizes.
     */
    @interface NSCoder (NSGeometryKeyedCoding)
/**
 * Encodes an <code>NSPoint</code> object.
 */
- (void) encodePoint: (NSPoint)aPoint forKey: (NSString*)aKey;

/**
 * Encodes an <code>NSRect</code> object.
 */
- (void) encodeRect: (NSRect)aRect forKey: (NSString*)aKey;

/**
 * Encodes an <code>NSSize</code> object.
 */
- (void) encodeSize: (NSSize)aSize forKey: (NSString*)aKey;

/**
 * Decodes an <code>NSPoint</code> object.
 */
- (NSPoint) decodePointForKey: (NSString*)aKey;

/**
 * Decodes an <code>NSRect</code> object.
 */
- (NSRect) decodeRectForKey: (NSString*)aKey;

/**
 * Decodes an <code>NSSize</code> object.
 */
- (NSSize) decodeSizeForKey: (NSString*)aKey;
@end
    
#if    defined(__cplusplus)
}
#endif

#endif    /* GS_API_MACOSX */
#endif    /* __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE */

