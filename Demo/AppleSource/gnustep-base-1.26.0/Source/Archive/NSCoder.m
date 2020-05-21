#import "common.h"
#define	EXPOSE_NSCoder_IVARS	1
#import "Foundation/NSData.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSSerialization.h"
#import "Foundation/NSUserDefaults.h"

@implementation NSCoder

#define	MAX_SUPPORTED_SYSTEM_VERSION	1000000

static unsigned	systemVersion = MAX_SUPPORTED_SYSTEM_VERSION;


// 最最最核心的方法, 大部分的 encode 操作, 都是提取 type 值然后归并到这个方法里面.
- (void) encodeValueOfObjCType: (const char*)type
                            at: (const void*)address
{
    [self subclassResponsibility: _cmd];
}


// 最最最核心的方法, 大部分的 decode 的操作, 都是规定到这个方法里面
- (void) decodeValueOfObjCType: (const char*)type
                            at: (void*)address
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeDataObject: (NSData*)data
{
    [self subclassResponsibility: _cmd];
}

- (NSData*) decodeDataObject
{
    [self subclassResponsibility: _cmd];
    return nil;
}

#pragma mark - Encode

// Encoding Data

- (void) encodeArrayOfObjCType: (const char*)type // 这就代表了, array 里面所有的值得类型, 都是 type 类型的
                         count: (NSUInteger)count
                            at: (const void*)array
{
    unsigned	i;
    unsigned	size = objc_sizeof_type(type);
    const char	*where = array;
    IMP		imp;
    
    imp = [self methodForSelector: @selector(encodeValueOfObjCType:at:)];
    for (i = 0; i < count; i++, where += size) // wherer + size, 这就是类型的意义.
    {
        (*imp)(self, @selector(encodeValueOfObjCType:at:), type, where);
    }
}

- (void) encodeBycopyObject: (id)anObject
{
    [self encodeObject: anObject];
}

- (void) encodeByrefObject: (id)anObject
{
    [self encodeObject: anObject];
}

- (void) encodeBytes: (void*)d length: (NSUInteger)l
{
    const char		*type = @encode(unsigned char);
    const unsigned char	*where = (const unsigned char*)d;
    IMP			imp;
    
    imp = [self methodForSelector: @selector(encodeValueOfObjCType:at:)];
    (*imp)(self, @selector(encodeValueOfObjCType:at:),
           @encode(unsigned), &l);
    while (l-- > 0)
        (*imp)(self, @selector(encodeValueOfObjCType:at:), type, where++);
}

- (void) encodeConditionalObject: (id)anObject
{
    [self encodeObject: anObject];
}

- (void) encodeObject: (id)anObject
{
    [self encodeValueOfObjCType: @encode(id) at: &anObject];
}

- (void) encodePropertyList: (id)plist
{
    id    anObject;
    
    anObject = plist ? (id)[NSSerializer serializePropertyList: plist] : nil;
    [self encodeValueOfObjCType: @encode(id) at: &anObject];
}

- (void) encodePoint: (NSPoint)point
{
    [self encodeValueOfObjCType: @encode(NSPoint) at: &point];
}

- (void) encodeRect: (NSRect)rect
{
    [self encodeValueOfObjCType: @encode(NSRect) at: &rect];
}

- (void) encodeRootObject: (id)rootObject
{
    [self encodeObject: rootObject];
}

- (void) encodeSize: (NSSize)size
{
    [self encodeValueOfObjCType: @encode(NSSize) at: &size];
}

- (void) encodeValuesOfObjCTypes: (const char*)types,...
{
    va_list	ap;
    IMP		imp;
    
    imp = [self methodForSelector: @selector(encodeValueOfObjCType:at:)];
    va_start(ap, types);
    while (*types)
    {
        (*imp)(self, @selector(encodeValueOfObjCType:at:), types,
               va_arg(ap, void*));
        types = objc_skip_typespec(types);
    }
    va_end(ap);
}


#pragma makr - Decode
// Decoding Data

- (void) decodeArrayOfObjCType: (const char*)type
                         count: (NSUInteger)count
                            at: (void*)address
{
    unsigned	i;
    unsigned	size = objc_sizeof_type(type);
    char		*where = address;
    IMP		imp;
    
    imp = [self methodForSelector: @selector(decodeValueOfObjCType:at:)];
    
    for (i = 0; i < count; i++, where += size)
    {
        (*imp)(self, @selector(decodeValueOfObjCType:at:), type, where);
    }
}

- (void*) decodeBytesWithReturnedLength: (NSUInteger*)l
{
    unsigned int	count;
    const char	*type = @encode(unsigned char);
    unsigned char	*where;
    unsigned char	*array;
    IMP		imp;
    
    imp = [self methodForSelector: @selector(decodeValueOfObjCType:at:)];
    
    (*imp)(self, @selector(decodeValueOfObjCType:at:),
           @encode(unsigned int), &count);
    *l = (NSUInteger)count;
    array = NSZoneMalloc(NSDefaultMallocZone(), count);
    where = array;
    while (count-- > 0)
    {
        (*imp)(self, @selector(decodeValueOfObjCType:at:), type, where++);
    }
    
    [NSData dataWithBytesNoCopy: array length: count];
    return array;
}

- (id) decodeObject
{
    id	o = nil;
    
    [self decodeValueOfObjCType: @encode(id) at: &o];
    return AUTORELEASE(o);
}

- (id) decodePropertyList
{
    id	o;
    id	d = nil;
    
    [self decodeValueOfObjCType: @encode(id) at: &d];
    if (d != nil)
    {
        o = [NSDeserializer deserializePropertyListFromData: d
                                          mutableContainers: NO];
        RELEASE(d);
    }
    else
    {
        o = nil;
    }
    return o;
}

- (NSPoint) decodePoint
{
    NSPoint	point;
    
    [self decodeValueOfObjCType: @encode(NSPoint) at: &point];
    return point;
}

- (NSRect) decodeRect
{
    NSRect	rect;
    
    [self decodeValueOfObjCType: @encode(NSRect) at: &rect];
    return rect;
}

- (NSSize) decodeSize
{
    NSSize	size;
    
    [self decodeValueOfObjCType: @encode(NSSize) at: &size];
    return size;
}

- (void) decodeValuesOfObjCTypes: (const char*)types,...
{
    va_list	ap;
    IMP		imp;
    
    imp = [self methodForSelector: @selector(decodeValueOfObjCType:at:)];
    va_start(ap, types);
    while (*types)
    {
        (*imp)(self, @selector(decodeValueOfObjCType:at:),
               types, va_arg(ap, void*));
        types = objc_skip_typespec(types);
    }
    va_end(ap);
}


// Getting a Version

- (unsigned) systemVersion
{
    return systemVersion;
}


// Keyed archiving extensions

- (BOOL) requiresSecureCoding
{
    [self subclassResponsibility: _cmd];
    return NO;
}

- (void) setRequiresSecureCoding: (BOOL)secure
{
    [self subclassResponsibility: _cmd];
}

- (BOOL) allowsKeyedCoding
{
    return NO;
}

- (BOOL) containsValueForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return NO;
}

#pragma mark - KeyDecode

- (BOOL) decodeBoolForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return NO;
}

- (const uint8_t*) decodeBytesForKey: (NSString*)aKey
                      returnedLength: (NSUInteger*)alength
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (double) decodeDoubleForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return 0.0;
}

- (float) decodeFloatForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return 0.0;
}

- (int) decodeIntForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (NSInteger) decodeIntegerForKey: (NSString*)key
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (int32_t) decodeInt32ForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (int64_t) decodeInt64ForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (id) decodeObjectForKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (id) decodeObjectOfClass: (Class)cls forKey: (NSString *)aKey
{
    return [self decodeObjectOfClasses: [NSSet setWithObject:(id)cls]
                                forKey: aKey];
}

- (id) decodeObjectOfClasses: (NSSet *)classes forKey: (NSString *)aKey
{
    [self subclassResponsibility: _cmd];
    return nil;
}

#pragma mark - KeyEncode

- (void) encodeBool: (BOOL) aBool forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeBytes: (const uint8_t*)aPointer
              length: (NSUInteger)length
              forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeInteger: (NSInteger)anInteger forKey: (NSString*)key
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

- (void) encodeObject: (id)anObject forKey: (NSString*)aKey
{
    [self subclassResponsibility: _cmd];
}

@end

