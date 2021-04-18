#ifndef __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSCoder.h>
#import	<Foundation/NSMapTable.h>
#import	<Foundation/NSPropertyList.h>

@class NSMutableDictionary, NSMutableData, NSData, NSString;

/*
 KeyArchiver 里面, 考虑了循环引用的问题.
 
 在最终的存储中, 是把所有的对象, 放到了一个数组中进行了存储.
 A.B.C
 C.A
 那么最终, 是有一个数组里面存储了 [A,B,C,D] 对应的 Dict
 而 A 中的 Dict, B 对应的是一个 Dict, 里面会有一个 Id 值, 代表着 B 对象在 数组中的位置.
 同时 A 中的 Dict, 也会保存类的名字, 以及类的继承关系.
 对于基本数据类型, 也就是 number, string, dict, array, 会直接存储到 A 的 Dict 里面. 对于 Obj, 则是用 Obj 的 refDict 进行替换.
 
 解档的时候, 也是同样的流程,
 以 B 为例
 首先, A 解档 B 的时候, 首先是找到 B 的 RefDict, 里面读取 B 在 Array 里面的真实信息 BInfoDict.
 decodeIntForKey, 就是从 BInfoDict 里面查找对应的 value 转化成为 Int.
 当解档 C 的时候, 就是从 BInfoDict 里面, 读取 C 的 RefDic, 再去 Array 里面读取出 CInfoDict.
 
 以上整个过程, 会记录已经归档解档的对象, 如果归档解档的对象, 已经有了对应的 Ref 数据, 则会直接返回, 防止同样的一个 Obj 再次归档, 或者同样的一个 Id 再次解档.
 */

/*
 *  NSKeyedArchiver, a concrete subclass of NSCoder, provides a way to encode objects (and scalar values) into an architecture-independent suitable for storage in a file.
 这里说的很清楚, archiver 会把类型存储到自己的内部. 
 * When you archive a set of objects, the archiver writes the class information and instance variables for each object to the archive. The companion class NSKeyedUnarchiver decodes the data in an archive and creates a set of objects equivalent to the original set.
 A keyed archive differs from a non-keyed archive in that all the objects and values encoded into the archive have names, or keys. When decoding a non-keyed archive, the decoder must decode values in the same order the original encoder used. When decoding a keyed archive, the decoder requests values by name, meaning it can decode values out of sequence or not at all. Keyed archives, therefore, provide better support for forward and backward compatibility.
 The keys given to encoded values must be unique only within the scope of the currently-encoding object. A keyed archive is hierarchical, so the keys used by object A to encode its instance variables don’t conflict with the keys used by object B. This is true even if A and B are instances of the same class. Within a single object, however, the keys used by a subclass can conflict with keys used in its superclasses.
 An NSArchiver object can write the archive data to a file or to a mutable-data object (an instance of NSMutableData) that you provide
 */
@interface NSKeyedArchiver : NSCoder
{
@private
    NSMutableData	*_destinateData;		/* Data to write into.		*/
    id		_delegate;	/* Delegate controls operation.	*/
    NSMapTable	*_clsMap;	/* Map classes to names.	*/
    GSIMapTable	_cIdMap;	/* Conditionally coded.		*/
    GSIMapTable	_uIdMap;	/* Unconditionally coded.	*/
    GSIMapTable	_repMap;	/* Mappings for objects.	*/
    unsigned	_keyNum;	/* Counter for keys in object.	*/
    NSMutableDictionary	*_encodingGraph;	/* Object being encoded.	*/
    NSMutableArray	*_encodingObjArray;	/* Array of objects.		*/
    NSPropertyListFormat	_format;
    BOOL _requiresSecureCoding;
}

/**
 * Encodes anObject and returns the resulting data object.
 */
+ (NSData*) archivedDataWithRootObject: (id)anObject;


#if OS_API_VERSION(MAC_OS_X_VERSION_10_13,GS_API_LATEST)
/**
 * Encodes anObject and returns the resulting data object.  Allows
 * secure coding if specified.  Returns an error if an object
 * violates secure coding rules.
 */
+ (NSData *) archivedDataWithRootObject: (id)anObject
                  requiringSecureCoding: (BOOL)requiresSecureCoding
                                  error: (NSError **)error;
#endif

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
 * Returns whether the current instance of the archiver needs secure
 * coding.
 */
- (BOOL) requiresSecureCoding;

/**
 * Sets whether the current instance of the archiver needs secure
 * coding.
 */
- (void) setRequiresSecureCoding: (BOOL)flag;

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
              length: (NSUInteger)length
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
#if	GS_EXPOSE(NSKeyedUnarchiver)
@private
    NSDictionary	*_archive;
    id		_delegate;	/* Delegate controls operation.	*/
    NSMapTable	*_clsMap;	/* Map classes to names.	*/
    NSArray	*_objects;	/* All encoded objects.		*/
    NSDictionary	*_keyMap;	/* Local object name table.	*/
    unsigned	_cursor;	/* Position in object.		*/
    NSString	*_archiverClass;
    NSString	*_version;
#ifndef	_IN_NSKEYEDUNARCHIVER_M
#define	GSIArray	void*
#endif
    GSIArray		_cachedDecodeObjs; /* Decoded objects.		*/
#ifndef	_IN_NSKEYEDUNARCHIVER_M
#undef	GSIArray
#endif
    NSZone	*_zone;		/* Zone for allocating objs.	*/
    BOOL          _requiresSecureCoding;
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
 * Returns whether the current instance of the archiver needs secure
 * coding.
 */
- (BOOL) requiresSecureCoding;

/**
 * Sets whether the current instance of the archiver needs secure
 * coding.
 */
- (void) setRequiresSecureCoding: (BOOL)flag;

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
@interface	NSKeyedArchiver (Internal)
- (void) _encodeArrayOfObjects: (NSArray*)anArray forKey: (NSString*)aKey;
- (void) _encodePropertyList: (id)anObject forKey: (NSString*)aKey;
@end

/**
 * Internal methods.  Do not use.
 */
@interface	NSKeyedUnarchiver (Internal)
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

#endif	/* GS_API_MACOSX */
#endif	/* __NSKeyedArchiver_h_GNUSTEP_BASE_INCLUDE */

