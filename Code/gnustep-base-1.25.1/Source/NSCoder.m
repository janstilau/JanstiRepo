#import "common.h"

#if !defined (__GNU_LIBOBJC__)
#  include <objc/encoding.h>
#endif

#define	EXPOSE_NSCoder_IVARS	1
#import "Foundation/NSData.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSSerialization.h"
#import "Foundation/NSUserDefaults.h"

@implementation NSCoder

#define	MAX_SUPPORTED_SYSTEM_VERSION	1000000

static unsigned	systemVersion = MAX_SUPPORTED_SYSTEM_VERSION;

+ (void) initialize
{
  if (self == [NSCoder class])
    {
      unsigned	sv;

      /* The GSCoderSystemVersion user default is provided for testing
       * and to allow new code to communicate (via Distributed Objects)
       * with systems running older versions.
       */
      sv = [[NSUserDefaults standardUserDefaults]
	integerForKey: @"GSCoderSystemVersion"];
      if (sv > 0 && sv <= MAX_SUPPORTED_SYSTEM_VERSION)
	{
	  systemVersion = sv;
	} 
    }
}

- (void) encodeValueOfObjCType: (const char*)type
			    at: (const void*)address
{
  [self subclassResponsibility: _cmd];
}

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

- (NSInteger) versionForClassName: (NSString*)className
{
  [self subclassResponsibility: _cmd];
  return (NSInteger)NSNotFound;
}

// Encoding Data

- (void) encodeArrayOfObjCType: (const char*)type
			 count: (NSUInteger)count
			    at: (const void*)array
{
  unsigned	i;
  unsigned	size = objc_sizeof_type(type); // 利用底层函数, 获取 type 的所占空间大小. 计算出这个空间, 是为了遍历 array. 并不是说, 要把内容写入到 array 里面, 这个函数是 encode, 所以这个函数是把 array 的内存进行取出写到另外的一个位置. 到底写到哪里呢, 是这个类的
  const char	*where = array;
  IMP		imp;

  imp = [self methodForSelector: @selector(encodeValueOfObjCType:at:)];
  for (i = 0; i < count; i++, where += size) // 这里,encodeValueOfObjCType这个函数必须子类复写.
    {
      (*imp)(self, @selector(encodeValueOfObjCType:at:), type, where);
    }
}

- (void) encodeBytes: (void*)d length: (NSUInteger)l
{
  const char		*type = @encode(unsigned char);
  const unsigned char	*where = (const unsigned char*)d;
  IMP			imp;

  imp = [self methodForSelector: @selector(encodeValueOfObjCType:at:)];
  (*imp)(self, @selector(encodeValueOfObjCType:at:),
    @encode(unsigned), &l); // 这里, 首先是把 length 进行了存储, 然后挨个把字节进行序列化. 
  while (l-- > 0)
    (*imp)(self, @selector(encodeValueOfObjCType:at:), type, where++);
}

- (void) encodeConditionalObject: (id)anObject
{
  [self encodeObject: anObject];
}

// object 就是 id 类型. 我们可以看到, 下面的函数就是利用了 encodeValueOfObjectType 这个函数, 而这个函数是需要子类进行重写的. 这其实是父类的功能, 定义重复的代码, 在子类需要特定某些功能的时候, 在进行复写操作.
- (void) encodeObject: (id)anObject
{
  [self encodeValueOfObjCType: @encode(id) at: &anObject];
}

- (void) encodePropertyList: (id)plist
{
  id    anObject;

  anObject = plist ? (id)[NSSerializer serializePropertyList: plist] : nil; // 这里, 将 plist 文件的责任, 转移到了另外一个类中.
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
    // rootObject 的内部, 应该写清楚如何 encode 自己的成员.
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

// Decoding Data
// Decode 的作用和 encode 相反, 通过将二进制的数据复原成为想要的数据类型. 不过, decode 的数据, 要以返回值的形式传出来.
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
// decodeValueOfObjCType:at: 中, at 所指的位置, 应该是写入的位置. 也就是将数据写入到哪里去. 注意, 到哪里入这个动作其实我们都不知道. encode 的时候, 我们提供了数据的内存地址, 然后这个数据被类写入到某个地方, decode 的时候, 我们提供了内存地址用来保存数据, 但是数据从哪里来我们不知道. 序列化的数据究竟在哪里, 这是子类的责任. 但是, 归档解档的操作必须是一一对应的. 这也就是为什么要用 json 和 xml 进行数据传输的原因, 内存的传递, 必须要保证操作的一致性. 不能随意向里面插入数据, 而 json xml 这种 map 的形式, 可以方便扩展, 并且文字化的表示, 也便于调试.
- (void*) decodeBytesWithReturnedLength: (NSUInteger*)length // 这个 length 是传出参数.
{
  unsigned int	count;
  const char	*type = @encode(unsigned char);
  unsigned char	*where;
  unsigned char	*array;
  IMP		imp;

  imp = [self methodForSelector: @selector(decodeValueOfObjCType:at:)];

  (*imp)(self, @selector(decodeValueOfObjCType:at:),
    @encode(unsigned int), &count); // 必须先调用 length 的解档操作, 然后才是实际的数据.
  *length = (NSUInteger)count;
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

// Managing Zones

- (NSZone*) objectZone
{
  return NSDefaultMallocZone();
}

- (void) setObjectZone: (NSZone*)zone
{
  ;
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



#import	"GSPrivate.h"

@implementation	_NSKeyedCoderOldStyleArray
- (const void*) bytes
{
  return _a;
}
- (NSUInteger) count
{
  return _c;
}
- (void) dealloc
{
  DESTROY(_d);
  [super dealloc];
}
- (id) initWithCoder: (NSCoder*)aCoder
{
  id		o;
  void		*address;
  unsigned	i;

  _c = [aCoder decodeIntForKey: @"NS.count"];
  _t[0] = (char)[aCoder decodeIntForKey: @"NS.type"];
  _t[1] = '\0';

  /*
   * We decode the size from the remote end, but discard it as we
   * are probably safer to use the local size of the datatype involved.
   */
  _s = [aCoder decodeIntForKey: @"NS.size"];
  _s = objc_sizeof_type(_t);

  _d = o = [[NSMutableData alloc] initWithLength: _c * _s];
  _a = address = [o mutableBytes];
  for (i = 0; i < _c; i++)
    {
      [aCoder decodeValueOfObjCType: _t at: address];
      address += _s;
    }
  return self;
}

- (id) initWithObjCType: (const char*)t count: (NSInteger)c at: (const void*)a
{
  t = GSSkipTypeQualifierAndLayoutInfo(t);
  _t[0] = *t;
  _t[1] = '\0';
  _s = objc_sizeof_type(_t);
  _c = c;
  _a = a;
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  int	i;

  [aCoder encodeInt: _c forKey: @"NS.count"];
  [aCoder encodeInt: *_t forKey: @"NS.type"];
  [aCoder encodeInt: _s forKey: @"NS.size"];
  for (i = 0; i < _c; i++)
    {
      [aCoder encodeValueOfObjCType: _t at: _a];
      _a += _s;
    }
}

- (NSUInteger) size
{
  return _s;
}

- (const char*) type
{
  return _t;
}
@end

