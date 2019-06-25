#import "common.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSCoder.h"

@interface GSValue : NSValue
{
    void *data; // opaque 类型, 存储值的二进制表示
    char *objctype; // 类型存储. 这里, 其实有点像编程语言, 通过类型来操作二进制数据.
}
@end


@implementation GSValue

static inline unsigned
typeSize(const char* type)
{
    switch (*type)
    {
        case _C_ID:	return sizeof(id);
        case _C_CLASS:	return sizeof(Class);
        case _C_SEL:	return sizeof(SEL);
        case _C_CHR:	return sizeof(char);
        case _C_UCHR:	return sizeof(unsigned char);
        case _C_SHT:	return sizeof(short);
        case _C_USHT:	return sizeof(unsigned short);
        case _C_INT:	return sizeof(int);
        case _C_UINT:	return sizeof(unsigned int);
        case _C_LNG:	return sizeof(long);
        case _C_ULNG:	return sizeof(unsigned long);
        case _C_LNG_LNG:	return sizeof(long long);
        case _C_ULNG_LNG:	return sizeof(unsigned long long);
        case _C_FLT:	return sizeof(float);
        case _C_DBL:	return sizeof(double);
        case _C_PTR:	return sizeof(void*);
        case _C_CHARPTR:	return sizeof(char*);
        case _C_BFLD:
        case _C_ARY_B:
        case _C_UNION_B:
        case _C_STRUCT_B:
        {
            NSUInteger	size;
            
            NSGetSizeAndAlignment(type, &size, 0);
            return (int)size;
        }
        case _C_VOID:	return 0;
        default:		return 0;
    }
}

// Allocating and Initializing
// Here, NSValue alloc a memory to cache the value, and the value type string info.
- (id) initWithBytes: (const void *)value
            objCType: (const char *)type
{
    self = [super init];
    if (self != nil)
    {
        unsigned	size = typeSize(type);
        
        if (size > 0)
        {
            data = (void *)NSZoneMalloc([self zone], size);
            memcpy(data, value, size);
        }
        else
        {
            NSLog(@"Tried to create NSValue with invalid Objective-C type");
            DESTROY(self);
            return nil;
        }
        size = strlen(type);
        objctype = (char *)NSZoneMalloc([self zone], size + 1);
        strncpy(objctype, type, size);
        objctype[size] = '\0';
    }
    return self;
}

- (void) dealloc
{
    if (objctype != 0)
        NSZoneFree([self zone], objctype);
    if (data != 0)
        NSZoneFree([self zone], data);
    [super dealloc];
}

// Accessing Data
- (void) getValue: (void *)value
{
    unsigned	size;
    
    size = typeSize(objctype);
    if (size > 0)
    {
        if (value == 0)
        {
            [NSException raise: NSInvalidArgumentException
                        format: @"Cannot copy value into NULL buffer"];
            /* NOT REACHED */
        }
        memcpy(value, data, size);
    }
}

- (NSUInteger) hash // 这里的 hash, 就是二进制值的每个 byte 相加.
{
    unsigned	size = typeSize(objctype);
    unsigned	hash = 0;
    
    while (size-- > 0)
    {
        hash += ((unsigned char*)data)[size];
    }
    return hash;
}

// pointer, class, primitive type, memory compare.
- (BOOL) isEqualToValue: (NSValue*)aValue
{
    if (aValue == self)
    {
        return YES;
    }
    if (aValue == nil)
    {
        return NO;
    }
    if (object_getClass(aValue) != object_getClass(self))
    {
        return NO;
    }
    if (!GSSelectorTypesMatch(objctype, ((GSValue*)aValue)->objctype))
    {
        return NO;
    }
    if (memcmp(((GSValue*)aValue)->data, data, typeSize(objctype)) != 0)
    {
        return NO;
    }
    return YES;
}

- (const char *)objCType
{
    return objctype;
}

- (id) nonretainedObjectValue
{
    unsigned	size = typeSize(objctype);
    
    if (size != sizeof(void*))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Return value of size %u as object", size];
    }
    return *((id *)data); // 直接返回, 传出去的值没有经过 autorelease.
}

// value is opaque, So you can see it as every type.

- (NSPoint) pointValue
{
    unsigned	size = typeSize(objctype);
    
    if (size != sizeof(NSPoint))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Return value of size %u as NSPoint", size];
    }
    return *((NSPoint *)data);
}

- (void *) pointerValue
{
    unsigned	size = typeSize(objctype);
    
    if (size != sizeof(void*))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Return value of size %u as pointer", size];
    }
    return *((void **)data);
}

- (NSRect) rectValue
{
    unsigned	size = (unsigned)typeSize(objctype);
    
    if (size != sizeof(NSRect))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Return value of size %u as NSRect", size];
    }
    return *((NSRect *)data);
}

- (NSSize) sizeValue
{
    unsigned	size = typeSize(objctype);
    
    if (size != sizeof(NSSize))
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Return value of size %u as NSSize", size];
    }
    return *((NSSize *)data);
}

- (NSString *) description
{
    unsigned	size;
    NSData	*rep;
    
    size = typeSize(objctype);
    rep = [NSData dataWithBytes: data length: size];
    return [NSString stringWithFormat: @"(%s) %@", objctype, [rep description]];
}


// 这里没有用到 keyedArchiver, 猜测是这个类很稳定, 固定的存 size, 存 type, 存data.
- (void) encodeWithCoder: (NSCoder *)coder
{
    NSUInteger	tsize;
    unsigned	size;
    NSMutableData	*d;
    
    size = strlen(objctype)+1;
    [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
    [coder encodeArrayOfObjCType: @encode(signed char) count: size at: objctype];
    NSGetSizeAndAlignment(objctype, 0, &tsize);
    size = tsize;
    d = [NSMutableData new];
    [d serializeDataAt: data ofObjCType: objctype context: nil];
    size = [d length];
    [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
    [coder encodeArrayOfObjCType: @encode(unsigned char)
                           count: size
                              at: [d bytes]];
    RELEASE(d);
}
@end
