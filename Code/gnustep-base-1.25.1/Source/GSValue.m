#import "common.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSCoder.h"

@interface GSValue : NSValue
{
  void *data;
  char *objctype;
}
@end

/* This is the real, general purpose value object.  I've implemented all the
   methods here (like pointValue) even though most likely, other concrete
   subclasses were created to handle these types */

@implementation GSValue

static inline int
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
#if __GNUC__ > 2 && defined(_C_BOOL)
      case _C_BOOL:	return sizeof(_Bool);
#endif
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
      default:		return -1;
    }
}

// Allocating and Initializing

- (id) initWithBytes: (const void *)value
	    objCType: (const char *)type
{
  if (!value || !type)
    {
      NSLog(@"Tried to create NSValue with NULL value or NULL type");
      DESTROY(self);
      return nil;
    }

  self = [super init];
  if (self != nil)
    {
      int	size = typeSize(type); // 这里, 首先根据类型, 把 size 拿到手.

      if (size < 0)
	{
	  NSLog(@"Tried to create NSValue with invalid Objective-C type");
	  DESTROY(self);
	  return nil;
	}
      if (size > 0)
	{
	  data = (void *)NSZoneMalloc([self zone], size);
	  memcpy(data, value, size); // 然后就是简简单单的 memcpy 操作了.
	}
      size = strlen(type);
      objctype = (char *)NSZoneMalloc([self zone], size + 1);
      strncpy(objctype, type, size);
      objctype[size] = '\0'; // 以及最后的, 把 typename 存一下.
        
        // 这里其实没有内存管理的, 或者说, 内存管理就在这个类里面, dealloc 的时候, 释放指针空间, alloc 的时候, 进行 malloc 操作. 因为这个类设计的是, 不可变的, 并且值来自于结构体.
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

  size = (unsigned)typeSize(objctype);
  if (size > 0)
    {
      if (value == 0)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Cannot copy value into NULL buffer"];
	  /* NOT REACHED */
	}
      memcpy(value, data, size); // objctype 已经存放到了自己的内存里面, 这里直接取值, 然后 memcpy 操作.
    }
}

- (NSUInteger) hash
{
  unsigned	size = typeSize(objctype);
  unsigned	hash = 0;

  while (size-- > 0)
    {
      hash += ((unsigned char*)data)[size];
    }
  return hash;// hash, 把所有的内存相加.
}

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
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(void*))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as object", size];
    }
  return *((id *)data);
}

- (NSPoint) pointValue
{
  unsigned	size = (unsigned)typeSize(objctype);

  if (size != sizeof(NSPoint))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Return value of size %u as NSPoint", size];
    }
  return *((NSPoint *)data); // 这里, 就是直接把 backing stroe 值当做 CGPoint 进行了处理, 再次验证了, 类型, 只不过是编程语言的提示语的特点.
}

- (void *) pointerValue
{
  unsigned	size = (unsigned)typeSize(objctype);

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
  unsigned	size = (unsigned)typeSize(objctype);

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

  size = (unsigned)typeSize(objctype);
  rep = [NSData dataWithBytes: data length: size];
  return [NSString stringWithFormat: @"(%s) %@", objctype, [rep description]];
}

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
