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
  [_encodeObject setObject: o forKey: aKey];
}

- (void) _encodePropertyList: (id)anObject forKey: (NSString*)aKey
{
  CHECKKEY
  [_encodeObject setObject: anObject forKey: aKey];
}
@end


@implementation	NSKeyedArchiver (Private)
/*
 * The real workhorse of the archiving process ... this deals with all
 * archiving of objects. It returns the object to be stored in the
 * mapping dictionary (_enc).
 */

// 最核心的方法.
- (id) _encodeObject: (id)anObject conditional: (BOOL)conditional
{
  id			original = anObject;
  GSIMapNode		node;
  id			objectInfo = nil;	// Encoded object
  NSMutableDictionary	*encodeObjectInfoM = nil;
  NSDictionary		*refObject;
  unsigned		ref = 0;		// Reference to nil

  if (anObject != nil) // 这一段, 是建立 id 对应的关系. 因为, 可能会有循环引用.
    {
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)anObject);
      if (node == 0) // 如果这个值没有被归档过. 就建立 id 的映射.
	{
        Class    c = [anObject classForKeyedArchiver];
        // FIXME ... exactly what classes are stored directly???
        if (c == [NSString class]
            || c == [NSNumber class]
            || c == [NSDate class]
            || c == [NSData class]
            )
        { // 如果是基本数据类型, 那么归档的就是自身的值.
            objectInfo = anObject;
        }
        else
        { // 不然, 又要进行成员变量的归档操作.
            // We store a dictionary describing the object.
            encodeObjectInfoM = [NSMutableDictionary new];
            objectInfo = encodeObjectInfoM;
        }
        
        node = GSIMapNodeForKey(_cIdMap, (GSIMapKey)anObject);
        ref = [_allArchivedObjects count];
        GSIMapAddPair(_uIdMap,
                      (GSIMapKey)anObject, (GSIMapVal)(NSUInteger)ref);
        [_allArchivedObjects addObject: objectInfo];
        RELEASE(encodeObjectInfoM);
	}
      else
	{
	  ref = node->value.nsu;
	}
    }

  /*
   * Build an object to reference the encoded value of anObject
   */
  refObject = makeReference(ref); // 得到的这个字典, 里面现在带有 id 信息, 代表着不同的对象.

  /*
   * objectInfo is a dictionary describing the object. // 如果 encode 一个对象, 它的信息其实还没填进去. 上面的仅仅是确立了对象的 id.
   */
  if (objectInfo != nil)
    {
      NSMutableDictionary	*savedEnc = _encodeObject;
      unsigned			savedKeyNum = _keyNum;
      Class			archiveName = [anObject class];
      NSString			*classname;
      Class			mapped;

      /*
       * Map the class of the object to the actual class it is encoded as.
       * First ask the object, then apply any name mappings to that value.
       */
      mapped = [anObject classForKeyedArchiver]; // 取出被归档对象的类型.
      if (mapped != nil)
	{
	  archiveName = mapped;
	}

      classname = [self classNameForClass: archiveName];
      if (classname == nil)
	{
	  classname = [[self class] classNameForClass: archiveName];
	}
      if (classname == nil)
	{
	  classname = NSStringFromClass(archiveName);
	}
      else
	{
	  archiveName = NSClassFromString(classname);
	}

      /*
       * At last, get the object to encode itself.  Save and restore the
       * current object scope of course.
       */
      _encodeObject = encodeObjectInfoM; // 这里, 体现了命名的重要性, 我不明白为什么GNU 那么牛逼的团队会写出 m 这样垃圾的变量名
      _keyNum = 0; // 在每个 object 进行 encode 的时候, 会替换一下_encodeObject 对象, 所以, 每个对象进行 encode 的时候, 是修改的每个对象匹配的 NSMutableDict .
      [anObject encodeWithCoder: self]; // 这个是每个类索所要实现的方法.
      _keyNum = savedKeyNum;
      _encodeObject = savedEnc;

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
      node = GSIMapNodeForKey(_uIdMap, (GSIMapKey)archiveName);
      if (node == 0)
	{
	  NSMutableDictionary	*cDict;
	  NSMutableArray	*hierarchy;

	  ref = [_allArchivedObjects count];
	  GSIMapAddPair(_uIdMap,
	    (GSIMapKey)archiveName, (GSIMapVal)(NSUInteger)ref);
	  cDict = [[NSMutableDictionary alloc] initWithCapacity: 2];

	  /*
	   * record class name
	   */
	  [cDict setObject: classname forKey: @"$classname"];

	  /*
	   * Record the class hierarchy for this object.
	   */
	  hierarchy = [NSMutableArray new];
	  while (archiveName != 0)
	    {
	      Class	next = [archiveName superclass];

	      [hierarchy addObject: NSStringFromClass(archiveName)];
	      if (next == archiveName)
		{
		  break;
		}
	      archiveName = next;
	    }
	  [cDict setObject: hierarchy forKey: @"$classes"];
	  RELEASE(hierarchy);
	  [_allArchivedObjects addObject: cDict];
	  RELEASE(cDict);
	}
      else
	{
	  ref = node->value.nsu;
	}

      /*
       * Now create a reference to the class information and store it
       * in the object description dictionary for the object we just encoded.
       */
      [encodeObjectInfoM setObject: makeReference(ref) forKey: @"$class"];
    }

  /*
   * Return the dictionary identifying the encoded object.
   */
  return refObject;
}
@end

@implementation	NSKeyedArchiver

/*
 刚试验了, 果然, keyedArchive 可以进行循环引用的归档解档的工作.
 
 A *aValue = [[A alloc] init];
 B *bValue = [[B alloc] init];
 
 aValue.bValue = bValue;
 bValue.aValue = aValue;
 
 NSData *data = [NSKeyedArchiver archivedDataWithRootObject:aValue];
 
 A *restoreValue = [NSKeyedUnarchiver unarchiveObjectWithData:data];
 NSLog(@"%@", restoreValue);
 NSLog(@"%@", restoreValue.bValue);
 NSLog(@"%@", restoreValue.bValue.aValue);
 */

+ (NSData*) archivedDataWithRootObject: (id)anObject
{
  NSMutableData		*m = nil;
  NSKeyedArchiver	*a = nil;
  NSData		*d = nil;

  NS_DURING
    {
        // 类方法, 只是做了一些实例方法能做的事情, 不过, 它更大的意义在于封装, 不给用户暴露太多的东西, 因为, 类之间的协作, 只有类的设计者才清楚, 让外人知道太多, 外人反而不知道该如何是好.
      m = [[NSMutableData alloc] initWithCapacity: 10240];
      a = [[NSKeyedArchiver alloc] initForWritingWithMutableData: m];
      [a encodeObject: anObject forKey: @"root"]; // 这里, root 当根 key 值.
      [a finishEncoding];
      d = [m copy]; // 这里, 没有直接返回 Mutable 对象.
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
  NSAutoreleasePool	*pool = [NSAutoreleasePool new]; // 自动释放池. 防止内存占用过大.
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
  RELEASE(_encodeObject);
  RELEASE(_allArchivedObjects);
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
      if (_repMap)
	{
	  GSIMapEmptyMap(_repMap);
	}
      NSZoneFree(_cIdMap->zone, (void*)_cIdMap);
    }
  [super dealloc];
}

- (id) delegate
{
  return _delegate;
}

- (NSString*) description
{
  if (_data == nil)
    {
      // For consistency with OSX
      [NSException raise: NSInvalidArgumentException
		  format: @"method sent to uninitialised archiver"];
    }
  return [super description];
}

- (void) encodeArrayOfObjCType: (const char*)aType
			 count: (NSUInteger)aCount
			    at: (const void*)address
{
  id	o;

  o = [[_NSKeyedCoderOldStyleArray alloc] initWithObjCType: aType
						     count: aCount
							at: address];
  [self encodeObject: o];
  RELEASE(o);
}

- (void) encodeBool: (BOOL)aBool forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithBool: aBool] forKey: aKey];
}

- (void) encodeBytes: (const uint8_t*)aPointer
	      length: (NSUInteger)length
	      forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSData dataWithBytes: aPointer length: length]
	   forKey: aKey];
}

- (void) encodeConditionalObject: (id)anObject
{
  NSString	*aKey = [NSString stringWithFormat: @"$%u", _keyNum++];

  anObject = [self _encodeObject: anObject conditional: YES];
  [_encodeObject setObject: anObject forKey: aKey];
}

- (void) encodeConditionalObject: (id)anObject forKey: (NSString*)aKey
{
  CHECKKEY

  anObject = [self _encodeObject: anObject conditional: YES];
  [_encodeObject setObject: anObject forKey: aKey];
}

- (void) encodeDouble: (double)aDouble forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithDouble: aDouble] forKey: aKey];
}

- (void) encodeFloat: (float)aFloat forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithFloat: aFloat] forKey: aKey];
}

- (void) encodeInt: (int)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithInt: anInteger] forKey: aKey];
}

- (void) encodeInteger: (NSInteger)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithInteger: anInteger] forKey: aKey];
}

- (void) encodeInt32: (int32_t)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithLong: anInteger] forKey: aKey];
}

- (void) encodeInt64: (int64_t)anInteger forKey: (NSString*)aKey
{
  CHECKKEY

  [_encodeObject setObject: [NSNumber  numberWithLongLong: anInteger] forKey: aKey];
}

- (void) encodeObject: (id)anObject
{
  NSString	*aKey = [NSString stringWithFormat: @"$%u", _keyNum++]; // 没有提供 key 的, 就用一个计数器代替.

  anObject = [self _encodeObject: anObject conditional: NO];
  [_encodeObject setObject: anObject forKey: aKey];
}

- (void) encodeObject: (id)anObject forKey: (NSString*)aKey
{
  CHECKKEY

  anObject = [self _encodeObject: anObject conditional: NO];
  [_encodeObject setObject: anObject forKey: aKey]; // aKey 仅仅是做最后的一个在 Dictionary 的记录的作用.
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
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_UCHR:
	o = [NSNumber numberWithInt: (NSInteger)*(unsigned char*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_SHT:
	o = [NSNumber numberWithInt: (NSInteger)*(short*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_USHT:
	o = [NSNumber numberWithLong: (long)*(unsigned short*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_INT:
	o = [NSNumber numberWithInt: *(int*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_UINT:
	o = [NSNumber numberWithUnsignedInt: *(unsigned int*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_LNG:
	o = [NSNumber numberWithLong: *(long*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_ULNG:
	o = [NSNumber numberWithUnsignedLong: *(unsigned long*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_LNG_LNG:
	o = [NSNumber numberWithLongLong: *(long long*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_ULNG_LNG:
	o = [NSNumber numberWithUnsignedLongLong:
	  *(unsigned long long*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_FLT:
	o = [NSNumber numberWithFloat: *(float*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

      case _C_DBL:
	o = [NSNumber numberWithDouble: *(double*)address];
	[_encodeObject setObject: o forKey: aKey];
	return;

#if __GNUC__ > 2 && defined(_C_BOOL)
      case _C_BOOL:
	o = [NSNumber numberWithInt: (NSInteger)*(_Bool*)address];
	[_encodeObject setObject: o forKey: aKey];
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
// 这个类的思路在于, 一般的额 primitie 可以表示的值, 记录在NSDictionary 里面, 而对于对象来说, 因为可能会有循环引用, 这些东西都记录成为 id 值, 然后将所有的对象, 记录在一个数组里面. 也就是 top 和 objects 里面的内容.
// 最后这个类用 propertyList 进行了存储. 首先, 到了这里, 所有 _encodeObject, _allArchivedObjects 里面的内容, 都是符合 propertyList 存储要求的. 也就是必须是 String, Number, Data 这些 propertyList 知道怎么操作的数据类型才可以. 而这些, 是靠 encodeInt64 这些函数的重写达到的.
// 如此看来, NSKeyedArchiver 最大的作用, 倒不是说进行归档解档这些操作, 而是它建立了一套避免循环的机制.
// 这一点, 在 PropertyList 是不存在的, 为什么呢. 因为 Propertylist 是不允许有对象存在的. 所有的东西, 都要转化成为上面的结构才可以. 实验证明, 如果 propertyList 里面有 一个对象, 进行 write 操作, 最后success的返回值为F alse. 所以, 从根本上来说, proeprtyList 就堵死了循环引用这条路了.
    
  NSMutableDictionary	*final;
  NSData		*data;
  NSString		*error;

  [_delegate archiverWillFinish: self];

  final = [NSMutableDictionary new];
  [final setObject: NSStringFromClass([self class]) forKey: @"$archiver"]; // 首先, 把归档接档的类名存起来,
  [final setObject: [NSNumber numberWithInt: 100000] forKey: @"$version"];
  [final setObject: _encodeObject forKey: @"$top"];
  [final setObject: _allArchivedObjects forKey: @"$objects"];
  data = [NSPropertyListSerialization dataFromPropertyList: final
						    format: _format
					  errorDescription: &error]; // 然后存到了一个 proeprtyList 里面.
  RELEASE(final);
  [_data setData: data];
  [_delegate archiverDidFinish: self];
}

- (id) init
{
  Class c = [self class];
  DESTROY(self);
  [NSException raise: NSInvalidArgumentException
              format: @"-[%@ init]: cannot use -init for initialisation",
              NSStringFromClass(c)];
  return nil;
}

- (id) initForWritingWithMutableData: (NSMutableData*)data
{
  self = [super init];
  if (self)
    {
      NSZone	*zone = [self zone];

      _keyNum = 0;
      _data = RETAIN(data); // 这里, 仅仅是一个存储的作用.

      _clsMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
			  NSObjectMapValueCallBacks, 0);
      /*
       *	Set up map tables.
       */
      _cIdMap = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t)*5);
      _uIdMap = &_cIdMap[1];
      _repMap = &_cIdMap[2];
      GSIMapInitWithZoneAndCapacity(_cIdMap, zone, 10);
      GSIMapInitWithZoneAndCapacity(_uIdMap, zone, 200);
      GSIMapInitWithZoneAndCapacity(_repMap, zone, 1);

      _encodeObject = [NSMutableDictionary new];		// Top level mapping dict
      _allArchivedObjects = [NSMutableArray new];		// Array of objects.
      [_allArchivedObjects addObject: @"$null"];		// Placeholder.

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


// 居然有一个 Archive 的非正式协议. 一直没有用过.
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


// 不太明白上面  - (void) encodePoint: (NSPoint)aPoint; 什么时候回用到, 这里看, 苹果专门为这几种 结构体类型定义了如何进行序列化的方式了.
// 如果, 想要进行序列化一种自定义的种类的时候, 也可以这样做.

@implementation NSCoder (NSGeometryKeyedCoding)
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

