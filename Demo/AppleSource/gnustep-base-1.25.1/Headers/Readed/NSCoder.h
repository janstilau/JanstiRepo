#ifndef __NSCoder_h_GNUSTEP_BASE_INCLUDE
#define __NSCoder_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSGeometry.h>
#import	<Foundation/NSSet.h>
#import	<Foundation/NSZone.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSMutableData, NSData, NSString;

/**
 
 An abstract class that serves as the basis for objects that enable archiving of other objects.
 
 
 *  <p>Top-level class defining methods for use when archiving (encoding)
 *  objects to a byte array or file, and when restoring (decoding) objects.
 *  Generally only subclasses of this class are used directly - ,
 
 *  [NSArchiver], [NSUnarchiver]
    [NSKeyedArchiver], [NSKeyedUnarchiver], or
 
  A coder object stores object type information along with the data, so an object decoded from a stream of bytes is normally of the same class as the object that was originally encoded into the stream
 
 */
//

/*
    这个类定义了一些公共的方法, 但是具体应该怎么进行归档解档, 具体的策略并没有在这个类当中.
    这个类定义了一些, 类似于快捷方法的东西. 但是, 这些快捷方法所包装的最根本的方法, 还是需要每个子类进行编写. 而且, 这些快捷方法, 这个父类没有进行包装完全. 例如, Int32, Bool 这些值怎么包装, 都是子类的责任.
    NSCoding 有着两个方法, 一个是 initWithCoder, 一个是 encodeWithCoder. 其实, 就是 encode 和 decode 两个方法, 在这两个方法的内部, 会传入NSCoder 的对象, 然后调用NSCoder 的各个方法, 进行序列化和反序列化, 而序列化之后的数据到底已什么样的方式, 保存在哪里, 完全封装到了 NSCoder 的内部.
 */
    
    // 这个类, 在别的类库里面, 就是 NSSerializer,
@interface NSCoder : NSObject
// Encoding Data

/**
 *  Encodes array of count structures or objects of given type, which may be
 *  obtained through the '<code>@encode(...)</code>' compile-time operator.
 *  Usually this is used for primitives though it can be used for objects as
 *  well.
 
 在 NSArray 的序列化中, 就有 [aCoder encodeArrayOfObjCType: @encode(id) count: count at: a];的调用
 首先, array 是要实现分配出来的.
 
 */

- (void) encodeArrayOfObjCType: (const char*)type
			 count: (NSUInteger)count
			    at: (const void*)array;

/**
 *  Stores bytes directly into archive.  
 */
- (void) encodeBytes: (void*)d length: (NSUInteger)l;

/**
 *  Encode object if it is/will be encoded unconditionally by this coder,
 *  otherwise store a nil.
 */
- (void) encodeConditionalObject: (id)anObject;

/**
 *  Encode an instance of [NSData].
 */
- (void) encodeDataObject: (NSData*)data;

/**
 *  Encodes a generic object.  This will usually result in an
 *  [(NSCoding)-encodeWithCoder:] message being sent to anObject so it
 *  can encode itself.
 */
- (void) encodeObject: (id)anObject;

/**
 *  Encodes a property list by calling [NSSerializer -serializePropertyList:],
 *  then encoding the resulting [NSData] object.
 */
- (void) encodePropertyList: (id)plist;

/**
 *  Encodes a point structure.
 */
- (void) encodePoint: (NSPoint)point;

/**
 *  Encodes a rectangle structure.
 */
- (void) encodeRect: (NSRect)rect;

/**
 *  Store object and objects it refers to in archive (i.e., complete object
 *  graph).
 */
- (void) encodeRootObject: (id)rootObject;

/**
 *  Encodes a size structure.
 */
- (void) encodeSize: (NSSize)size;

/**
 *  Encodes structure or object of given type, which may be obtained
 *  through the '<code>@encode(...)</code>' compile-time operator.  Usually
 *  this is used for primitives though it can be used for objects as well.
 */
- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)address;

/**
 *  Multiple version of [-encodeValueOfObjCType:at:].
 */
- (void) encodeValuesOfObjCTypes: (const char*)types,...;

// Decoding Data

/**
 *  Decodes array of count structures or objects of given type, which may be
 *  obtained through the '<code>@encode(...)</code>' compile-time operator.
 *  Usually this is used for primitives though it can be used for objects as
 *  well.  Objects will be retained and you must release them.
 */
- (void) decodeArrayOfObjCType: (const char*)type
                         count: (NSUInteger)count
                            at: (void*)address;

/**
 *  Retrieve bytes directly from archive.
 */
- (void*) decodeBytesWithReturnedLength: (NSUInteger*)l;

/**
 *  Decode an instance of [NSData].
 */
- (NSData*) decodeDataObject;

/**
 *  Decodes a generic object.  Usually the class will be read from the
 *  archive, an object will be created through an <code>alloc</code> call,
 *  then that class will be sent an [(NSCoding)-initWithCoder:] message.
 */
- (id) decodeObject;

/**
 *  Decodes a property list from the archive previously stored through a call
 *  to [-encodePropertyList:].
 */
- (id) decodePropertyList;

/**
 *  Decodes a point structure.
 */
- (NSPoint) decodePoint;

/**
 *  Decodes a rectangle structure.
 */
- (NSRect) decodeRect;

/**
 *  Decodes a size structure.
 */
- (NSSize) decodeSize;

/**
 *  Decodes structure or object of given type, which may be obtained
 *  through the '<code>@encode(...)</code>' compile-time operator.  Usually
 *  this is used for primitives though it can be used for objects as well,
 *  in which case you are responsible for releasing them.
 */
- (void) decodeValueOfObjCType: (const char*)type
			    at: (void*)address;

/**
 *  Multiple version of [-decodeValueOfObjCType:at:].
 */
- (void) decodeValuesOfObjCTypes: (const char*)types,...;

// Managing Zones

/**
 *  Returns zone being used to allocate memory for decoded objects.
 */
- (NSZone*) objectZone;

/**
 *  Sets zone to use for allocating memory for decoded objects.
 */
- (void) setObjectZone: (NSZone*)zone;

// Getting a Version

/**
 *  Returns *Step version, which is not the release version, but a large number,
 *  by specification &lt;1000 for pre-OpenStep.  This implementation returns
 *  a number based on the GNUstep major, minor, and subminor versions.
 */
- (unsigned int) systemVersion;

/**
 *  Returns current version of class (when encoding) or version of decoded
 *  class (decoded).  Version comes from [NSObject -getVersion].
 *  
 */
- (NSInteger) versionForClassName: (NSString*)className;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
/*
 * Include GSConfig.h for typedefs/defines of uint8_t, int32_t int64_t
 */
#import <GNUstepBase/GSConfig.h>


/** <override-subclass />
 * Returns a flag indicating whether the receiver supported keyed coding.
 * the default implementation returns NO.  Subclasses supporting keyed
 * coding must override this to return YES.
 */
- (BOOL) allowsKeyedCoding;

/** <override-subclass />
 * Returns a class indicating whether an encoded value corresponding
 * to aKey exists.
 */
- (BOOL) containsValueForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a boolean value associated with aKey.  This value must previously
 * have been encoded using -encodeBool:forKey:
 */
- (BOOL) decodeBoolForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a pointer to a byte array associated with aKey.<br />
 * Returns the length of the data in aLength.<br />
 * This value must previously have been encoded using
 * -encodeBytes:length:forKey:
 */
- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
		      returnedLength: (NSUInteger*)alength;

/** <override-subclass />
 * Returns a double value associated with aKey.  This value must previously
 * have been encoded using -encodeDouble:forKey: or -encodeFloat:forKey:
 */
- (double) decodeDoubleForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a float value associated with aKey.  This value must previously
 * have been encoded using -encodeFloat:forKey: or -encodeDouble:forKey:<br />
 * Precision may be lost (or an exception raised if the value will not fit
 * in a float) if the value was encoded using -encodeDouble:forKey:,
 */
- (float) decodeFloatForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns an integer value associated with aKey.  This value must previously
 * have been encoded using -encodeInt:forKey:, -encodeInt32:forKey:, or
 * -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in an integer.
 */
- (int) decodeIntForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a 32-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.<br />
 * An exception will be raised if the value does not fit in a 32-bit integer.
 */
- (int32_t) decodeInt32ForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns a 64-bit integer value associated with aKey.  This value must
 * previously have been encoded using -encodeInt:forKey:,
 * -encodeInt32:forKey:, or -encodeInt64:forKey:.
 */
- (int64_t) decodeInt64ForKey: (NSString*)aKey;

/** <override-subclass />
 * Returns an object value associated with aKey.  This value must
 * previously have been encoded using -encodeObject:forKey: or
 * -encodeConditionalObject:forKey:
 */
- (id) decodeObjectForKey: (NSString*)aKey;



/** <override-subclass />
 * Encodes aBool and associates the encoded value with aKey.
 */
- (void) encodeBool: (BOOL) aBool forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes the data of the specified length and pointed to by aPointer,
 * and associates the encoded value with aKey.
 */
- (void) encodeBytes: (const uint8_t*)aPointer
	      length: (NSUInteger)length
	      forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anObject and associates the encoded value with aKey, but only
 * if anObject has already been encoded using -encodeObject:forKey:
 */
- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes aDouble and associates the encoded value with aKey.
 */
- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes aFloat and associates the encoded value with aKey.
 */
- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes an int and associates the encoded value with aKey.
 */
- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes 32 bit integer and associates the encoded value with aKey.
 */
- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes a 64 bit integer and associates the encoded value with aKey.
 */
- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey;

/** <override-subclass />
 * Encodes anObject and associates the encoded value with aKey.
 */
- (void) encodeObject: (id)anObject forKey: (NSString*)aKey;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/** <override-subclass />
 * Encodes an NSInteger and associates the encoded value with key.
 */

- (void) encodeInteger: (NSInteger)anInteger forKey: (NSString *)key;
/** <override-subclass />
 * Decodes an NSInteger associated with the key.
 */
- (NSInteger) decodeIntegerForKey: (NSString *)key;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, assign) BOOL requiresSecureCoding;
#else
- (BOOL) requiresSecureCoding;
- (void) setRequiresSecureCoding: (BOOL)requires;
#endif

- (id) decodeObjectOfClass: (Class)cls forKey: (NSString *)key;
- (id) decodeObjectOfClasses: (NSSet *)classes forKey: (NSString *)key;

#endif
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* __NSCoder_h_GNUSTEP_BASE_INCLUDE */
