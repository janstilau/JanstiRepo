#import "common.h"
#define	EXPOSE_NSKeyedArchiver_IVARS	1
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSScanner.h"
#import "Foundation/NSValue.h"

#import "GSPrivate.h"

@class	GSString;

/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_KTYPES	GSUNION_PTR | GSUNION_OBJ | GSUNION_CLS | GSUNION_NSINT
#define	GSI_MAP_VTYPES	GSUNION_PTR | GSUNION_OBJ | GSUNION_NSINT
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_HASH(M, X)	((X).nsu)
#define	GSI_MAP_EQUAL(M, X,Y)	((X).ptr == (Y).ptr)
#undef	GSI_MAP_NOCLEAN
#define	GSI_MAP_RETAIN_KEY(M, X)	RETAIN(X.obj)	
#define	GSI_MAP_RELEASE_KEY(M, X)	RELEASE(X.obj)


#include "GNUstepBase/GSIMap.h"


#define	_IN_NSKEYEDARCHIVER_M	1
#import "Foundation/NSKeyedArchiver.h"
#undef	_IN_NSKEYEDARCHIVER_M

/* Exceptions */

/**
 * An archiving error has occurred.
 */
NSString * const NSInvalidArchiveOperationException
= @"NSInvalidArchiveOperationException";

static NSMapTable	*globalClassMap = 0;

static Class	NSStringClass = 0;
static Class	NSScannerClass = 0;
static SEL	scanFloatSel;
static SEL	scanStringSel;
static SEL	scannerSel;
static BOOL	(*scanFloatImp)(NSScanner*, SEL, CGFloat*);
static BOOL	(*scanStringImp)(NSScanner*, SEL, NSString*, NSString**);
static id 	(*scannerImp)(Class, SEL, NSString*);

static inline void
setupCache(void)
{
    if (NSStringClass == 0)
    {
        NSStringClass = [NSString class];
        NSScannerClass = [NSScanner class];
        if (sizeof(CGFloat) == sizeof(double))
        {
            scanFloatSel = @selector(scanDouble:);
        }
        else
        {
            scanFloatSel = @selector(scanFloat:);
        }
        scanStringSel = @selector(scanString:intoString:);
        scannerSel = @selector(scannerWithString:);
        scanFloatImp = (BOOL (*)(NSScanner*, SEL, CGFloat*))
        [NSScannerClass instanceMethodForSelector: scanFloatSel];
        scanStringImp = (BOOL (*)(NSScanner*, SEL, NSString*, NSString**))
        [NSScannerClass instanceMethodForSelector: scanStringSel];
        scannerImp = (id (*)(Class, SEL, NSString*))
        [NSScannerClass methodForSelector: scannerSel];
    }
}

#define	CHECKKEY \
if ([aKey isKindOfClass: [NSString class]] == NO) \
{ \
[NSException raise: NSInvalidArgumentException \
format: @"%@, bad key '%@' in %@", \
NSStringFromClass([self class]), aKey, NSStringFromSelector(_cmd)]; \
} \
if ([aKey hasPrefix: @"$"] == YES) \
{ \
aKey = [@"$" stringByAppendingString: aKey]; \
} \
if ([_enc objectForKey: aKey] != nil) \
{ \
[NSException raise: NSInvalidArgumentException \
format: @"%@, duplicate key '%@' in %@", \
NSStringFromClass([self class]), aKey, NSStringFromSelector(_cmd)]; \
}

/*
 * Make a dictionary referring to the object at ref in the array of all objects.
 */
static NSDictionary *makeReference(unsigned ref)
{
    NSNumber	*n;
    NSDictionary	*d;
    
    n = [NSNumber numberWithUnsignedInt: ref];
    d = [NSDictionary dictionaryWithObject: n forKey:  @"CF$UID"];
    return d;
}

@interface	NSKeyedArchiver (Private)
- (id) _encodeObject: (id)anObject conditional: (BOOL)conditional;
@end

@implementation	NSKeyedArchiver (Internal)
/**
 * Internal method used to encode an array relatively efficiently.<br />
 * Some MacOS-X library classes seem to use this.
 */
- (void) _encodeArrayOfObjects: (NSArray*)anArray forKey: (NSString*)aKey
{
    id		o;
    CHECKKEY
    
    if (anArray == nil)
    {
        o = makeReference(0);
    }
    else
    {
        NSMutableArray	*m;
        unsigned		c;
        unsigned		i;
        
        c = [anArray count];
        m = [NSMutableArray arrayWithCapacity: c];
        for (i = 0; i < c; i++)
        {
            o = [self _encodeObject: [anArray objectAtIndex: i] conditional: NO];
            [m addObject: o];
        }
        o = m;
    }
    [_encodeObjectDictM setObject: o forKey: aKey];
}

- (void) _encodePropertyList: (id)anObject forKey: (NSString*)aKey
{
    CHECKKEY
    [_encodeObjectDictM setObject: anObject forKey: aKey];
}
@end

@implementation	NSKeyedArchiver (Private)
/*
 * The real workhorse of the archiving process ... this deals with all
 * archiving of objects. It returns the object to be stored in the
 * mapping dictionary (_enc).
 */
// 这里, conditional 这个值, 没有进行理会. 现在不太明白 conditional 的作用到底是什么, 它仅仅在 encodeConditionalObject: 的时候被调用, 现在这两个函数已经被删除了.
- (id) _encodeObject: (id)anObject conditional: (BOOL)conditional
{
    id			original = anObject;
    GSIMapNode		node;
    id			objectInfo = nil;	// Encoded object
    NSMutableDictionary	*idEncodeInfos = nil;
    NSDictionary		*refObject;
    unsigned		uid = 0;		// Reference to nil
    
    if (anObject != nil)
    {
        /*
         * Obtain replacement object for the value being encoded.
         * Notify delegate of progress and set up new mapping if necessary.
         */
        node = GSIMapNodeForKey(_replaceMentMap, (GSIMapKey)anObject);
        if (node == 0)
        {
            // 这里是, NSObject 拥有 replacementObjectForArchiver 这个函数, 可以返回一个对象. 这个对象可以代替自己, 作为归档的对象. 这是 NSObject 提供的一个机制. 在这里, replacementObjectForArchiver 被使用了.
            // 并且, 归档解档其实是有代理的, 这里, 也进行了响应的代理的通知.
            anObject = [original replacementObjectForKeyedArchiver: self];
            if (_delegate != nil)
            {
                if (anObject != nil)
                {
                    anObject = [_delegate archiver: self
                                  willEncodeObject: anObject];
                }
                if (original != anObject)
                {
                    [_delegate archiver: self
                      willReplaceObject: original
                             withObject: anObject];
                }
            }
            GSIMapAddPair(_replaceMentMap, (GSIMapKey)original, (GSIMapVal)anObject);
        }
        else
        {
            /*
             * If the object has a replacement, use it.
             */
            anObject = node->value.obj;
        }
    }
    
    // 到这里, anObject 就代表着是最终的要进行归档的对象了, 不管是元对象, 还是元对象的替代品.
    if (anObject != nil)
    {
        node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)anObject);
        if (node == 0)
        {
            Class    c = [anObject classForKeyedArchiver];
            
            // 如果是基本的数据类型进行归档.
            if (c == [NSString class]
                || c == [NSNumber class]
                || c == [NSDate class]
                || c == [NSData class]
                )
            {
                objectInfo = anObject;
            }
            else // 如果是对象归档.
            {
                // We store a dictionary describing the object.
                idEncodeInfos = [NSMutableDictionary new];
                objectInfo = idEncodeInfos;
            }
            
            uid = [_encodeObjectsArrayM count];
            GSIMapAddPair(_uIdMap,
                          (GSIMapKey)anObject, (GSIMapVal)(NSUInteger)uid);
            [_encodeObjectsArrayM addObject: objectInfo];
        }
        else
        {
            uid = node->value.nsu;
        }
    }
    
    /*
     * Build an object to reference the encoded value of anObject
     */
    refObject = makeReference(uid);
    
    /*
     * objectInfo is a dictionary describing the object.
     */
    if (objectInfo != nil && idEncodeInfos == objectInfo)
    {
        Class			clazz = [anObject class];
        NSString			*classname;
        Class			mapped;
        
        /*
         * Map the class of the object to the actual class it is encoded as.
         * First ask the object, then apply any name mappings to that value.
         */
        mapped = [anObject classForKeyedArchiver];
        if (mapped != nil)
        {
            clazz = mapped;
        }
        
        classname = [self classNameForClass: clazz];
        if (classname == nil)
        {
            classname = [[self class] classNameForClass: clazz];
        }
        if (classname == nil)
        {
            classname = NSStringFromClass(clazz);
        }
        else
        {
            clazz = NSClassFromString(classname);
        }
        
        /*
         * At last, get the object to encode itself.  Save and restore the
         * current object scope of course.
         */
        // 保存环境
        NSMutableDictionary    *savedEnc = _encodeObjectDictM;
        unsigned            savedKeyNum = _keyNum;
        _encodeObjectDictM = idEncodeInfos;
        _keyNum = 0;
        [anObject encodeWithCoder: self]; // 调用每个对象的自定义的方法进行归档.
        // 现在, idEncodeInfos 里面就是归档之后的信息了. 这里面铁定有递归调用.
        // 恢复环境
        _keyNum = savedKeyNum;
        _encodeObjectDictM = savedEnc;
        
        /*
         * This is ugly, but it seems to be the way MacOS-X does it ...
         * We create class information by storing it directly into the
         * table of all objects, and making a reference so we can look
         * up the table entry by class pointer.
         * A much cleaner way to do it would be by encoding the class
         * normally, but we are trying to be compatible.
         *
         * Also ... we encode the class *after* encoding the instance,
         * simply because that seems to be the way MacOS-X does it and
         * we want to maximise compatibility (perhaps they had good reason?)
         */
        node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)clazz);
        if (node == 0)
        {
            NSMutableDictionary	*cDict;
            NSMutableArray	*hierarchy;
            
            uid = [_encodeObjectsArrayM count];
            GSIMapAddPair(_uIdMap,
                          (GSIMapKey)clazz, (GSIMapVal)(NSUInteger)uid);
            cDict = [[NSMutableDictionary alloc] initWithCapacity: 2];
            
            /*
             * record class name
             */
            [cDict setObject: classname forKey: @"$classname"];
            
            /*
             * Record the class hierarchy for this object.
             */
            hierarchy = [NSMutableArray new];
            while (clazz != 0)
            {
                Class	next = [clazz superclass];
                
                [hierarchy addObject: NSStringFromClass(clazz)];
                if (next == clazz)
                {
                    break;
                }
                clazz = next;
            }
            [cDict setObject: hierarchy forKey: @"$classes"];
            RELEASE(hierarchy);
            [_encodeObjectsArrayM addObject: cDict];
            RELEASE(cDict);
        }
        else
        {
            uid = node->value.nsu;
        }
        
        /*
         * Now create a reference to the class information and store it
         * in the object description dictionary for the object we just encoded.
         */
        [idEncodeInfos setObject: makeReference(uid) forKey: @"$class"];
    }
    
    /*
     * If we have encoded the object information, tell the delegaate.
     */
    if (objectInfo != nil && _delegate != nil)
    {
        [_delegate archiver: self didEncodeObject: anObject];
    }
    
    /*
     * Return the dictionary identifying the encoded object.
     */
    return refObject;
}
@end

@implementation	NSKeyedArchiver

/*
 * When I tried this on MacOS 10.3 it encoded the object with the key 'root',
 * so this implementation does the same.
 */
+ (NSData*) archivedDataWithRootObject: (id)anObject
{
    NSMutableData		*m = nil;
    NSKeyedArchiver	*a = nil;
    NSData		*d = nil;
    
    NS_DURING
    {
        m = [[NSMutableData alloc] initWithCapacity: 10240];
        a = [[NSKeyedArchiver alloc] initForWritingWithMutableData: m];
        [a encodeObject: anObject forKey: @"root"];
        [a finishEncoding];
        d = [m copy];
        DESTROY(m);
        DESTROY(a);
    }
    NS_HANDLER
    {
        DESTROY(m);
        DESTROY(a);
        [localException raise];
    }
    NS_ENDHANDLER
    return AUTORELEASE(d);
}

+ (BOOL) archiveRootObject: (id)anObject toFile: (NSString*)aPath
{
    NSAutoreleasePool	*pool = [NSAutoreleasePool new];
    NSData		*d;
    BOOL			result;
    
    d = [self archivedDataWithRootObject: anObject];
    result = [d writeToFile: aPath atomically: YES];
    [pool drain];
    return result;
}

+ (NSString*) classNameForClass: (Class)aClass
{
    return (NSString*)NSMapGet(globalClassMap, (void*)aClass);
}

+ (void) initialize
{
    GSMakeWeakPointer(self, "delegate");
    
    if (globalClassMap == 0)
    {
        globalClassMap =
        NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                         NSObjectMapValueCallBacks, 0);
        [[NSObject leakAt: &globalClassMap] release];
    }
}

+ (void) setClassName: (NSString*)aString forClass: (Class)aClass
{
    if (aString == nil)
    {
        NSMapRemove(globalClassMap, (void*)aClass);
    }
    else
    {
        NSMapInsert(globalClassMap, (void*)aClass, aString);
    }
}

- (BOOL) allowsKeyedCoding
{
    return YES;
}

- (NSString*) classNameForClass: (Class)aClass
{
    return (NSString*)NSMapGet(_clsMap, (void*)aClass);
}

- (void) dealloc
{
    RELEASE(_encodeObjectDictM);
    RELEASE(_encodeObjectsArrayM);
    RELEASE(_data);
    if (_clsMap != 0)
    {
        NSFreeMapTable(_clsMap);
        _clsMap = 0;
    }
    if (_cIdMap)
    {
        GSIMapEmptyMap(_cIdMap);
        if (_uIdMap)
        {
            GSIMapEmptyMap(_uIdMap);
        }
        if (_replaceMentMap)
        {
            GSIMapEmptyMap(_replaceMentMap);
        }
        NSZoneFree(_cIdMap->zone, (void*)_cIdMap);
    }
    [super dealloc];
}

- (id) delegate
{
    return _delegate;
}

// 对于这些基本的数据类型, 都是将他们保存到了 _encodeObjectDictM 中, 过程中经过一个简单的包装, 因为这些基本数据类型, 是没有相互保存的考虑的.
- (void) encodeBool: (BOOL)aBool forKey: (NSString*)aKey
{
    [_encodeObjectDictM setObject: [NSNumber  numberWithBool: aBool] forKey: aKey];
}

- (void) encodeBytes: (const uint8_t*)aPointer
              length: (int)length
              forKey: (NSString*)aKey
{
    [_encodeObjectDictM setObject: [NSData dataWithBytes: aPointer length: length]
             forKey: aKey];
}

- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithDouble: aDouble] forKey: aKey];
}

- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithFloat: aFloat] forKey: aKey];
}

- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithInt: anInteger] forKey: aKey];
}

- (void) encodeInteger: (NSInteger)anInteger forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithInteger: anInteger] forKey: aKey];
}

- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithLong: anInteger] forKey: aKey];
}

- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey
{
    CHECKKEY
    
    [_encodeObjectDictM setObject: [NSNumber  numberWithLongLong: anInteger] forKey: aKey];
}


// 对于对象来说, 需要进行去重的处理.
- (void) encodeObject: (id)anObject
{
    NSString	*aKey = [NSString stringWithFormat: @"$%u", _keyNum++];
    anObject = [self _encodeObject: anObject conditional: NO];
    [_encodeObjectDictM setObject: anObject forKey: aKey];
}

- (void) encodeObject: (id)anObject forKey: (NSString*)aKey
{
    anObject = [self _encodeObject: anObject conditional: NO];
    [_encodeObjectDictM setObject: anObject forKey: aKey];
}

- (void) encodePoint: (NSPoint)p
{
    [self encodeValueOfObjCType: @encode(CGFloat) at: &p.x];
    [self encodeValueOfObjCType: @encode(CGFloat) at: &p.y];
}

- (void) encodeRect: (NSRect)r
{
    [self encodeValueOfObjCType: @encode(CGFloat) at: &r.origin.x];
    [self encodeValueOfObjCType: @encode(CGFloat) at: &r.origin.y];
    [self encodeValueOfObjCType: @encode(CGFloat) at: &r.size.width];
    [self encodeValueOfObjCType: @encode(CGFloat) at: &r.size.height];
}

- (void) encodeSize: (NSSize)s
{
    [self encodeValueOfObjCType: @encode(CGFloat) at: &s.width];
    [self encodeValueOfObjCType: @encode(CGFloat) at: &s.height];
}

- (void) encodeValueOfObjCType: (const char*)type
                            at: (const void*)address
{
    NSString	*aKey;
    id		o;
    
    type = GSSkipTypeQualifierAndLayoutInfo(type);
    if (*type == _C_ID || *type == _C_CLASS)
    {
        [self encodeObject: *(id*)address];
        return;
    }
    
    aKey = [NSString stringWithFormat: @"$%u", _keyNum++];
    switch (*type)
    {
        case _C_SEL:
        {
            // Selectors are encoded by name as strings.
            o = NSStringFromSelector(*(SEL*)address);
            [self encodeObject: o];
        }
            return;
            
        case _C_CHARPTR:
        {
            /*
             * Bizzarely MacOS-X seems to encode char* values by creating
             * string objects and encoding those objects!
             */
            o = [NSString stringWithUTF8String: (char*)address];
            [self encodeObject: o];
        }
            return;
            
        case _C_CHR:
            o = [NSNumber numberWithInt: (NSInteger)*(char*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_UCHR:
            o = [NSNumber numberWithInt: (NSInteger)*(unsigned char*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_SHT:
            o = [NSNumber numberWithInt: (NSInteger)*(short*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_USHT:
            o = [NSNumber numberWithLong: (long)*(unsigned short*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_INT:
            o = [NSNumber numberWithInt: *(int*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_UINT:
            o = [NSNumber numberWithUnsignedInt: *(unsigned int*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_LNG:
            o = [NSNumber numberWithLong: *(long*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_ULNG:
            o = [NSNumber numberWithUnsignedLong: *(unsigned long*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_LNG_LNG:
            o = [NSNumber numberWithLongLong: *(long long*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_ULNG_LNG:
            o = [NSNumber numberWithUnsignedLongLong:
                 *(unsigned long long*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_FLT:
            o = [NSNumber numberWithFloat: *(float*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
        case _C_DBL:
            o = [NSNumber numberWithDouble: *(double*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
            
#if __GNUC__ > 2 && defined(_C_BOOL)
        case _C_BOOL:
            o = [NSNumber numberWithInt: (NSInteger)*(_Bool*)address];
            [_encodeObjectDictM setObject: o forKey: aKey];
            return;
#endif
            
        case _C_STRUCT_B:
            [NSException raise: NSInvalidArgumentException
                        format: @"-[%@ %@]: this archiver cannote encode structs",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
            return;
            
        case _C_ARY_B:
        {
            int		count = atoi(++type);
            
            while (isdigit(*type))
            {
                type++;
            }
            [self encodeArrayOfObjCType: type count: count at: address];
        }
            return;
            
        default:	/* Types that can be ignored in first pass.	*/
            [NSException raise: NSInvalidArgumentException
                        format: @"-[%@ %@]: unknown type encoding ('%c')",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd), *type];
            break;
    }
}

- (void) finishEncoding
{
    NSMutableDictionary	*final;
    NSData		*data;
    NSString		*error;
    
    [_delegate archiverWillFinish: self];
    
    final = [NSMutableDictionary new];
    [final setObject: NSStringFromClass([self class]) forKey: @"$archiver"];
    [final setObject: [NSNumber numberWithInt: 100000] forKey: @"$version"];
    [final setObject: _encodeObjectDictM forKey: @"$top"];
    [final setObject: _encodeObjectsArrayM forKey: @"$objects"];
    // 最终, 是用一个 propertyList 文件进行的存储.
    data = [NSPropertyListSerialization dataFromPropertyList: final
                                                      format: _format
                                            errorDescription: &error];
    RELEASE(final);
    [_data setData: data];
    [_delegate archiverDidFinish: self];
}

- (id) init
{
    Class c = [self class];
    return nil;
}

- (id) initForWritingWithMutableData: (NSMutableData*)data
{
    self = [super init];
    if (self)
    {
        NSZone	*zone = [self zone];
        
        _keyNum = 0;
        _data = RETAIN(data);
        
        _clsMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                   NSObjectMapValueCallBacks, 0);
        /*
         *	Set up map tables.
         */
        _cIdMap = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t)*5);
        _uIdMap = &_cIdMap[1];
        _replaceMentMap = &_cIdMap[2];
        GSIMapInitWithZoneAndCapacity(_cIdMap, zone, 10);
        GSIMapInitWithZoneAndCapacity(_uIdMap, zone, 200);
        GSIMapInitWithZoneAndCapacity(_replaceMentMap, zone, 1);
        
        _encodeObjectDictM = [NSMutableDictionary new];		// Top level mapping dict
        _encodeObjectsArrayM = [NSMutableArray new];		// Array of objects.
        [_encodeObjectsArrayM addObject: @"$null"];		// Placeholder.
        
        _format = NSPropertyListBinaryFormat_v1_0;
    }
    return self;
}

- (NSPropertyListFormat) outputFormat
{
    return _format;
}

- (void) setClassName: (NSString*)aString forClass: (Class)aClass
{
    if (aString == nil)
    {
        NSMapRemove(_clsMap, (void*)aClass);
    }
    else
    {
        NSMapInsert(_clsMap, (void*)aClass, aString);
    }
}

- (void) setDelegate: (id)anObject
{
    _delegate = anObject;		// Not retained.
}

- (void) setOutputFormat: (NSPropertyListFormat)format
{
    _format = format;
}

@end

@implementation NSObject (NSKeyedArchiverDelegate)
/** <override-dummy />
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver didEncodeObject: (id)anObject
{
}
/** <override-dummy />
 */
- (id) archiver: (NSKeyedArchiver*)anArchiver willEncodeObject: (id)anObject
{
    return anObject;
}
/** <override-dummy />
 */
- (void) archiverDidFinish: (NSKeyedArchiver*)anArchiver
{
}
/** <override-dummy />
 */
- (void) archiverWillFinish: (NSKeyedArchiver*)anArchiver
{
}
/** <override-dummy />
 */
- (void) archiver: (NSKeyedArchiver*)anArchiver
willReplaceObject: (id)anObject
       withObject: (id)newObject
{
}
@end

@implementation NSObject (NSKeyedArchiverObjectSubstitution)
- (Class) classForKeyedArchiver
{
    return [self classForArchiver];
}
- (id) replacementObjectForKeyedArchiver: (NSKeyedArchiver*)archiver
{
    return [self replacementObjectForArchiver: nil];
}
@end



@implementation NSCoder (NSGeometryKeyedCoding)
/*
 专门为几何做的处理. 其实就是用规定好的文本来表示.
 */
- (void) encodePoint: (NSPoint)aPoint forKey: (NSString*)aKey
{
    NSString	*val;
    
    val = [NSString stringWithFormat: @"{%g, %g}", aPoint.x, aPoint.y];
    [self encodeObject: val forKey: aKey];
}

- (void) encodeRect: (NSRect)aRect forKey: (NSString*)aKey
{
    NSString	*val;
    
    val = [NSString stringWithFormat: @"{{%g, %g}, {%g, %g}}",
           aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height];
    [self encodeObject: val forKey: aKey];
}

- (void) encodeSize: (NSSize)aSize forKey: (NSString*)aKey
{
    NSString	*val;
    
    val = [NSString stringWithFormat: @"{%g, %g}", aSize.width, aSize.height];
    [self encodeObject: val forKey: aKey];
}

- (NSPoint) decodePointForKey: (NSString*)aKey
{
    NSString	*val = [self decodeObjectForKey: aKey];
    NSPoint	aPoint;
    
    if (val == 0)
    {
        aPoint = NSMakePoint(0, 0);
    }
    else
    {
        NSScanner	*scanner;
        
        setupCache();
        scanner = (*scannerImp)(NSScannerClass, scannerSel, val);
        if (!(*scanStringImp)(scanner, scanStringSel, @"{", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aPoint.x)
            || !(*scanStringImp)(scanner, scanStringSel, @",", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aPoint.y)
            || !(*scanStringImp)(scanner, scanStringSel, @"}", NULL))
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@ -%@]: bad value - '%@'",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
        }
    }
    return aPoint;
}

- (NSRect) decodeRectForKey: (NSString*)aKey
{
    NSString	*val = [self decodeObjectForKey: aKey];
    NSRect	aRect;
    
    if (val == 0)
    {
        aRect = NSMakeRect(0, 0, 0, 0);
    }
    else
    {
        NSScanner	*scanner;
        
        setupCache();
        scanner = (*scannerImp)(NSScannerClass, scannerSel, val);
        if (!(*scanStringImp)(scanner, scanStringSel, @"{", NULL)
            || !(*scanStringImp)(scanner, scanStringSel, @"{", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aRect.origin.x)
            || !(*scanStringImp)(scanner, scanStringSel, @",", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aRect.origin.y)
            || !(*scanStringImp)(scanner, scanStringSel, @"}", NULL)
            || !(*scanStringImp)(scanner, scanStringSel, @",", NULL)
            || !(*scanStringImp)(scanner, scanStringSel, @"{", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aRect.size.width)
            || !(*scanStringImp)(scanner, scanStringSel, @",", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aRect.size.height)
            || !(*scanStringImp)(scanner, scanStringSel, @"}", NULL)
            || !(*scanStringImp)(scanner, scanStringSel, @"}", NULL))
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@ -%@]: bad value - '%@'",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
        }
    }
    return aRect;
}

- (NSSize) decodeSizeForKey: (NSString*)aKey
{
    NSString	*val = [self decodeObjectForKey: aKey];
    NSSize	aSize;
    
    if (val == 0)
    {
        aSize = NSMakeSize(0, 0);
    }
    else
    {
        NSScanner	*scanner;
        
        setupCache();
        scanner = (*scannerImp)(NSScannerClass, scannerSel, val);
        if (!(*scanStringImp)(scanner, scanStringSel, @"{", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aSize.width)
            || !(*scanStringImp)(scanner, scanStringSel, @",", NULL)
            || !(*scanFloatImp)(scanner, scanFloatSel, &aSize.height)
            || !(*scanStringImp)(scanner, scanStringSel, @"}", NULL))
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"[%@ -%@]: bad value - '%@'",
             NSStringFromClass([self class]), NSStringFromSelector(_cmd), val];
        }
    }
    return aSize;
}
@end

