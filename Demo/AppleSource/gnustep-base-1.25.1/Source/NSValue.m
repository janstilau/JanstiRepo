#import "common.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSData.h"

@interface	GSPlaceholderValue : NSValue
@end

@class	GSValue;
@interface GSValue : NSObject	// Help the compiler
@end
@class	GSNonretainedObjectValue;
@interface GSNonretainedObjectValue : NSObject	// Help the compiler
@end
@class	GSPointValue;
@interface GSPointValue : NSObject	// Help the compiler
@end
@class	GSPointerValue;
@interface GSPointerValue : NSObject	// Help the compiler
@end
@class	GSRangeValue;
@interface GSRangeValue : NSObject	// Help the compiler
@end
@class	GSRectValue;
@interface GSRectValue : NSObject	// Help the compiler
@end
@class	GSSizeValue;
@interface GSSizeValue : NSObject	// Help the compiler
@end
@class	NSDataStatic;		// Needed for decoding.
@interface NSDataStatic : NSData	// Help the compiler
@end


static Class	NSValueClass;
static Class	concreteClass;
static Class	nonretainedObjectValueClass;
static Class	pointValueClass;
static Class	pointerValueClass;
static Class	rangeValueClass;
static Class	rectValueClass;
static Class	sizeValueClass;
static Class	GSPlaceholderValueClass;


static GSPlaceholderValue	*defaultPlaceholderValue;
static NSMapTable		*placeholderMap;
static NSLock			*placeholderLock;

@implementation NSValue

+ (void) initialize
{
  if (self == [NSValue class])
    {
      NSValueClass = self;
      [NSValueClass setVersion: 3];	// Version 3
      concreteClass = [GSValue class];
      nonretainedObjectValueClass = [GSNonretainedObjectValue class];
      pointValueClass = [GSPointValue class];
      pointerValueClass = [GSPointerValue class];
      rangeValueClass = [GSRangeValue class];
      rectValueClass = [GSRectValue class];
      sizeValueClass = [GSSizeValue class];
      GSPlaceholderValueClass = [GSPlaceholderValue class];

      /*
       * Set up infrastructure for placeholder values.
       */
      defaultPlaceholderValue = (GSPlaceholderValue*)
	NSAllocateObject(GSPlaceholderValueClass, 0, NSDefaultMallocZone());
      [[NSObject leakAt: (id*)&defaultPlaceholderValue] release];
      placeholderMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSNonRetainedObjectMapValueCallBacks, 0);
      [[NSObject leakAt: (id*)&placeholderMap] release];
      placeholderLock = [NSLock new];
      [[NSObject leakAt: (id*)&placeholderLock] release];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSValueClass)
    {
      if (z == NSDefaultMallocZone() || z == 0)
	{
	  /*
	   * As a special case, we can return a placeholder for a value
	   * in the default malloc zone extremely efficiently.
	   */
	  return defaultPlaceholderValue; // 其实和类簇一样, alloc 返回一个对象, 然后这个对象在返回实际的值.
	}
      else
	{
	  id	obj;

	  /*
	   * For anything other than the default zone, we need to
	   * locate the correct placeholder in the (lock protected)
	   * table of placeholders.
	   */
	  [placeholderLock lock];
	  obj = (id)NSMapGet(placeholderMap, (void*)z);
	  if (obj == nil)
	    {
	      /*
	       * There is no placeholder object for this zone, so we
	       * create a new one and use that.
	       */
	      obj = (id)NSAllocateObject(GSPlaceholderValueClass, 0, z);
	      NSMapInsert(placeholderMap, (void*)z, (void*)obj);
	    }
	  [placeholderLock unlock];
	  return obj;
	}
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
}

// NSCopying - always a simple retain.

- (id) copy
{
  return RETAIN(self); // 因为 NSValue 都是不可变的对象.
}

- (id) copyWithZone: (NSZone *)zone
{
  return RETAIN(self);
}

/* Returns the concrete class associated with the type encoding */
+ (Class) valueClassWithObjCType: (const char *)type
{
  Class	theClass = concreteClass;

  /* Let someone else deal with this error */
  if (!type)
    return theClass;

  /* Try for an exact type match.
   */
  if (strcmp(@encode(id), type) == 0)
    theClass = nonretainedObjectValueClass;
  else if (strcmp(@encode(NSPoint), type) == 0)
    theClass = pointValueClass;
  else if (strcmp(@encode(void *), type) == 0)
    theClass = pointerValueClass;
  else if (strcmp(@encode(NSRange), type) == 0)
    theClass = rangeValueClass;
  else if (strcmp(@encode(NSRect), type) == 0)
    theClass = rectValueClass;
  else if (strcmp(@encode(NSSize), type) == 0)
    theClass = sizeValueClass;

  /* Try for equivalent types match.
   */
  else if (GSSelectorTypesMatch(@encode(id), type))
    theClass = nonretainedObjectValueClass;
  else if (GSSelectorTypesMatch(@encode(NSPoint), type))
    theClass = pointValueClass;
  else if (GSSelectorTypesMatch(@encode(void *), type))
    theClass = pointerValueClass;
  else if (GSSelectorTypesMatch(@encode(NSRange), type))
    theClass = rangeValueClass;
  else if (GSSelectorTypesMatch(@encode(NSRect), type))
    theClass = rectValueClass;
  else if (GSSelectorTypesMatch(@encode(NSSize), type))
    theClass = sizeValueClass;

  return theClass;
}

// Allocating and Initializing

+ (NSValue*) value: (const void *)value
      withObjCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue*) valueWithBytes: (const void *)value
		   objCType: (const char *)type
{
  Class		theClass = [self valueClassWithObjCType: type];
  NSValue	*theObj;

  theObj = [theClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: value objCType: type];
  return AUTORELEASE(theObj);
}
		
+ (NSValue*) valueWithNonretainedObject: (id)anObject
{
  NSValue	*theObj;

  theObj = [nonretainedObjectValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &anObject objCType: @encode(id)];
  return AUTORELEASE(theObj);
}
	
+ (NSValue*) valueWithPoint: (NSPoint)point
{
  NSValue	*theObj;

  theObj = [pointValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &point objCType: @encode(NSPoint)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueWithPointer: (const void *)pointer
{
  NSValue	*theObj;

  theObj = [pointerValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &pointer objCType: @encode(void*)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueWithRange: (NSRange)range
{
  NSValue	*theObj;

  theObj = [rangeValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &range objCType: @encode(NSRange)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueWithRect: (NSRect)rect
{
  NSValue	*theObj;

  theObj = [rectValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &rect objCType: @encode(NSRect)];
  return AUTORELEASE(theObj);
}

+ (NSValue*) valueWithSize: (NSSize)size
{
  NSValue	*theObj;

  theObj = [sizeValueClass allocWithZone: NSDefaultMallocZone()];
  theObj = [theObj initWithBytes: &size objCType: @encode(NSSize)];
  return AUTORELEASE(theObj);
}

// 可以看到, 上面的类方法, 所做的仅仅是帮助我们快速的建立所需要的类. 真正的最后要调用的, 还是 initWithBytes: objCType 这个函数.


// 从通用的字符串表示中, 抓取类型数据.
+ (NSValue*) valueFromString: (NSString *)string
{
  NSDictionary	*dict = [string propertyList];

  if (dict == nil)
    return nil;

  if ([dict objectForKey: @"location"])
    {
      NSRange range;
      range = NSMakeRange([[dict objectForKey: @"location"] intValue],
			[[dict objectForKey: @"length"] intValue]);
      return [NSValueClass valueWithRange: range];
    }
  else if ([dict objectForKey: @"width"] && [dict objectForKey: @"x"])
    {
      NSRect rect;
      rect = NSMakeRect([[dict objectForKey: @"x"] floatValue],
		       [[dict objectForKey: @"y"] floatValue],
		       [[dict objectForKey: @"width"] floatValue],
		       [[dict objectForKey: @"height"] floatValue]);
      return [NSValueClass valueWithRect: rect];
    }
  else if ([dict objectForKey: @"width"])
    {
      NSSize size;
      size = NSMakeSize([[dict objectForKey: @"width"] floatValue],
			[[dict objectForKey: @"height"] floatValue]);
      return [NSValueClass valueWithSize: size];
    }
  else if ([dict objectForKey: @"x"])
    {
      NSPoint point;
      point = NSMakePoint([[dict objectForKey: @"x"] floatValue],
			[[dict objectForKey: @"y"] floatValue]);
      return [NSValueClass valueWithPoint: point];
    }
  return nil;
}

- (id) initWithBytes: (const void*)data objCType: (const char*)type
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Accessing Data
/* All the rest of these methods must be implemented by a subclass */
- (void) getValue: (void *)value
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: [self class]])
    {
      return [self isEqualToValue: other];
    }
  return NO;
}

- (BOOL) isEqualToValue: (NSValue*)other
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (const char *) objCType
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) nonretainedObjectValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void *) pointerValue
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSRange) rangeValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeRange(0,0);
}

- (NSRect) rectValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeRect(0,0,0,0);
}

- (NSSize) sizeValue
{
  [self subclassResponsibility: _cmd];
  return NSMakeSize(0,0);
}

- (NSPoint) pointValue
{
  [self subclassResponsibility: _cmd];
  return NSMakePoint(0,0);
}

- (Class) classForCoder
{
  return NSValueClass;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  NSUInteger	tsize;
  unsigned	size;
  const char	*data;
  const char	*objctype = [self objCType];
  NSMutableData	*d;

    // 如何归档, 就代表着如何解档. 因为这是顺序排列的.
  size = strlen(objctype)+1;
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size]; // 首先, 归档 size
  [coder encodeArrayOfObjCType: @encode(signed char) count: size at: objctype]; // 然后, 归档 type
  if (strncmp("{_NSSize=", objctype, 9) == 0)
    {
      NSSize    v = [self sizeValue];

      [coder encodeValueOfObjCType: objctype at: &v];
      return;
    }
  else if (strncmp("{_NSPoint=", objctype, 10) == 0)
    {
      NSPoint    v = [self pointValue];

      [coder encodeValueOfObjCType: objctype at: &v];
      return;
    }
  else if (strncmp("{_NSRect=", objctype, 9) == 0)
    {
      NSRect    v = [self rectValue];

      [coder encodeValueOfObjCType: objctype at: &v];
      return;
    }
  else if (strncmp("{_NSRange=", objctype, 10) == 0)
    {
      NSRange    v = [self rangeValue];

      [coder encodeValueOfObjCType: objctype at: &v];
      return;
    }

  NSGetSizeAndAlignment(objctype, 0, &tsize);
  data = (void *)NSZoneMalloc([self zone], tsize);
  [self getValue: (void*)data];
  d = [NSMutableData new];
  [d serializeDataAt: data ofObjCType: objctype context: nil];
  size = [d length];
  [coder encodeValueOfObjCType: @encode(unsigned) at: &size];
  NSZoneFree(NSDefaultMallocZone(), (void*)data);
  data = [d bytes];
  [coder encodeArrayOfObjCType: @encode(unsigned char) count: size at: data];
  RELEASE(d);
}

- (id) initWithCoder: (NSCoder *)coder
{
  char		type[64];
  const char	*objctype;
  Class		c;
  id		o;
  NSUInteger	tsize;
  unsigned	size;
  int		ver;

  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
  /*
   * For almost all type encodings, we can use space on the stack,
   * but to handle exceptionally large ones (possibly some huge structs)
   * we have a strategy of allocating and deallocating heap space too.
   */
  if (size <= 64)
    {
      objctype = type;
    }
  else
    {
      objctype = (void*)NSZoneMalloc(NSDefaultMallocZone(), size);
    }
  [coder decodeArrayOfObjCType: @encode(signed char)
			 count: size
			    at: (void*)objctype];
  if (strncmp("{_NSSize=", objctype, 9) == 0)
    c = [NSValueClass valueClassWithObjCType: @encode(NSSize)];
  else if (strncmp("{_NSPoint=", objctype, 10) == 0)
    c = [NSValueClass valueClassWithObjCType: @encode(NSPoint)];
  else if (strncmp("{_NSRect=", objctype, 9) == 0)
    c = [NSValueClass valueClassWithObjCType: @encode(NSRect)];
  else if (strncmp("{_NSRange=", objctype, 10) == 0)
    c = [NSValueClass valueClassWithObjCType: @encode(NSRange)];
  else
    c = [NSValueClass valueClassWithObjCType: objctype];
  o = [c allocWithZone: [coder objectZone]];

  ver = [coder versionForClassName: @"NSValue"];
  if (ver > 2)
    {
      if (c == pointValueClass)
        {
          NSPoint	v;

          [coder decodeValueOfObjCType: @encode(NSPoint) at: &v];
          DESTROY(self);
          return [o initWithBytes: &v objCType: @encode(NSPoint)];
        }
      else if (c == sizeValueClass)
        {
          NSSize	v;

          [coder decodeValueOfObjCType: @encode(NSSize) at: &v];
          DESTROY(self);
          return [o initWithBytes: &v objCType: @encode(NSSize)];
        }
      else if (c == rangeValueClass)
        {
          NSRange	v;

          [coder decodeValueOfObjCType: @encode(NSRange) at: &v];
          DESTROY(self);
          return [o initWithBytes: &v objCType: @encode(NSRange)];
        }
      else if (c == rectValueClass)
        {
          NSRect	v;

          [coder decodeValueOfObjCType: @encode(NSRect) at: &v];
          DESTROY(self);
          return [o initWithBytes: &v objCType: @encode(NSRect)];
        }
    }

  if (ver < 2)
    {
      if (ver < 1)
	{
	  if (c == pointValueClass)
	    {
	      NSPoint	v;

	      [coder decodeValueOfObjCType: @encode(NSPoint) at: &v];
	      o = [o initWithBytes: &v objCType: @encode(NSPoint)];
	    }
	  else if (c == sizeValueClass)
	    {
	      NSSize	v;

	      [coder decodeValueOfObjCType: @encode(NSSize) at: &v];
	      o = [o initWithBytes: &v objCType: @encode(NSSize)];
	    }
	  else if (c == rangeValueClass)
	    {
	      NSRange	v;

	      [coder decodeValueOfObjCType: @encode(NSRange) at: &v];
	      o = [o initWithBytes: &v objCType: @encode(NSRange)];
	    }
	  else if (c == rectValueClass)
	    {
	      NSRect	v;

	      [coder decodeValueOfObjCType: @encode(NSRect) at: &v];
	      o = [o initWithBytes: &v objCType: @encode(NSRect)];
	    }
	  else
	    {
	      unsigned char	*data;

	      [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
	      data = (void *)NSZoneMalloc(NSDefaultMallocZone(), size);
	      [coder decodeArrayOfObjCType: @encode(unsigned char)
				     count: size
					at: (void*)data];
	      o = [o initWithBytes: data objCType: objctype];
	      NSZoneFree(NSDefaultMallocZone(), data);
	    }
	}
      else
	{
	  NSData        *d;
	  unsigned      cursor = 0;

	  /*
	   * For performance, decode small values directly onto the stack,
	   * For larger values we allocate and deallocate heap space.
	   */
	  NSGetSizeAndAlignment(objctype, 0, &tsize);
	  if (tsize <= 64)
	    {
	      unsigned char data[tsize];

	      [coder decodeValueOfObjCType: @encode(id) at: &d];
	      [d deserializeDataAt: data
			ofObjCType: objctype
			  atCursor: &cursor
			   context: nil];
	      o = [o initWithBytes: data objCType: objctype];
	      RELEASE(d);
	    }
	  else
	    {
	      unsigned char *data;

	      data = (void *)NSZoneMalloc(NSDefaultMallocZone(), tsize);
	      [coder decodeValueOfObjCType: @encode(id) at: &d];
	      [d deserializeDataAt: data
			ofObjCType: objctype
			  atCursor: &cursor
			   context: nil];
	      o = [o initWithBytes: data objCType: objctype];
	      RELEASE(d);
	      NSZoneFree(NSDefaultMallocZone(), data);
	    }
	}
    }
  else
    {
      static NSData	*d = nil;
      unsigned  	cursor = 0;

      if (d == nil)
	{
	  d = [NSDataStatic allocWithZone: NSDefaultMallocZone()];
	}
      /*
       * For performance, decode small values directly onto the stack,
       * For larger values we allocate and deallocate heap space.
       */
      NSGetSizeAndAlignment(objctype, 0, &tsize);
      if (tsize <= 64)
	{
	  unsigned char	data[tsize];

	  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
	  {
	    unsigned char	serialized[size];

	    [coder decodeArrayOfObjCType: @encode(unsigned char)
				   count: size
				      at: (void*)serialized];
	    d = [d initWithBytesNoCopy: (void*)serialized
				length: size
			  freeWhenDone: NO];
	    [d deserializeDataAt: data
		      ofObjCType: objctype
			atCursor: &cursor
			 context: nil];
	  }
	  o = [o initWithBytes: data objCType: objctype];
	}
      else
	{
	  void	*data;

	  data = (void *)NSZoneMalloc(NSDefaultMallocZone(), tsize);
	  [coder decodeValueOfObjCType: @encode(unsigned) at: &size];
	  {
	    void	*serialized;

	    serialized = (void *)NSZoneMalloc(NSDefaultMallocZone(), size);
	    [coder decodeArrayOfObjCType: @encode(unsigned char)
				   count: size
				      at: serialized];
	    d = [d initWithBytesNoCopy: serialized length: size];
	    [d deserializeDataAt: data
		      ofObjCType: objctype
			atCursor: &cursor
			 context: nil];
	    NSZoneFree(NSDefaultMallocZone(), serialized);
	  }
	  o = [o initWithBytes: data objCType: objctype];
	  NSZoneFree(NSDefaultMallocZone(), data);
	}
    }
  if (objctype != type)
    {
      NSZoneFree(NSDefaultMallocZone(), (void*)objctype);
    }
  DESTROY(self);
  self = o;
  return self;
}

@end



@implementation	GSPlaceholderValue

- (id) autorelease
{
  NSWarnLog(@"-autorelease sent to uninitialised value");
  return self;		// placeholders never get released.
}

- (void) dealloc
{
  GSNOSUPERDEALLOC;	// placeholders never get deallocated.
}

- (void) getValue: (void*)data
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised value"];
}

- (id) initWithBytes: (const void*)data objCType: (const char*)type
{
  Class		c = [NSValueClass valueClassWithObjCType: type]; // 这里, 得到实际的类, 然后进行初始化.

  self = (id)NSAllocateObject(c, 0, [self zone]);
  return [self initWithBytes: data objCType: type];
}

- (const char*) objCType
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to use uninitialised value"];
  return 0;
}

- (oneway void) release
{
  return;		// placeholders never get released.
}

- (id) retain
{
  return self;		// placeholders never get retained.
}
@end
