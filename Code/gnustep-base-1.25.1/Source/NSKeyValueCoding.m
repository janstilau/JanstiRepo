#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"

/* For the NSKeyValueMutableArray and NSKeyValueMutableSet classes
 */
#include "NSKeyValueMutableArray.m"
#include "NSKeyValueMutableSet.m"

/* For backward compatibility NSUndefinedKeyException is actually the same
 * as the older NSUnknownKeyException
 */
NSString* const NSUnknownKeyException = @"NSUnknownKeyException";
NSString* const NSUndefinedKeyException = @"NSUnknownKeyException";


/* this should move into autoconf once it's accepted */
#define WANT_DEPRECATED_KVC_COMPAT 1

#ifdef WANT_DEPRECATED_KVC_COMPAT

static IMP      takePath = 0;
static IMP      takeValue = 0;
static IMP      takePathKVO = 0;
static IMP      takeValueKVO = 0;

static inline void setupCompat()
{
  if (takePath == 0)
    {
      Class  c = NSClassFromString(@"GSKVOBase");

      takePathKVO = [c instanceMethodForSelector:
        @selector(takeValue:forKeyPath:)];
      takePath = [NSObject instanceMethodForSelector:
        @selector(takeValue:forKeyPath:)];
      takeValueKVO = [c instanceMethodForSelector:
        @selector(takeValue:forKey:)];
      takeValue = [NSObject instanceMethodForSelector:
        @selector(takeValue:forKey:)];
    }
}

#endif

static void
SetValueForKey(NSObject *self, id anObject, const char *key, unsigned size)
{
  SEL		sel = 0;
  const char	*type = 0;
  int		off = 0;

  if (size > 0)
    {
      const char	*name;
      char		buf[size + 6];
      char		lo;
      char		hi;

      strncpy(buf, "_set", 4);
      strncpy(&buf[4], key, size); // 首先是 _setKey
        
    
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo; // 这里是set 后面的大写字母变化.
      buf[4] = hi;
      buf[size + 4] = ':';
      buf[size + 5] = '\0';  // buf 里面现在shi setKey:

      name = &buf[1];	// setKey:
      type = NULL;
      sel = sel_getUid(name); // 这个方法, 是把一个 c 字符串, 注册到 runtime 系统里面
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  name = buf;	// _setKey:
	  sel = sel_getUid(name); // 这里, 会取得 sel 的值,
	  if (sel == 0 || [self respondsToSelector: sel] == NO) // 如果, 这个类没有这个 sel, 那么就是下面的直接进行内存的读取了.
	    {
	      sel = 0;
	      if ([[self class] accessInstanceVariablesDirectly] == YES)
		{
		  buf[size + 4] = '\0';
		  buf[3] = '_';
		  buf[4] = lo;
		  name = &buf[3];	// _key
		  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO) // 如果没有找到这个值,
		    {
		      buf[4] = hi;
		      buf[3] = 's';
		      buf[2] = 'i';
		      buf[1] = '_';
		      name = &buf[1];	// _isKey
		      if (GSObjCFindVariable(self,
			name, &type, &size, &off) == NO) // 就找这个值. 如果还没有, 就找这个值.
			{
			  buf[4] = lo;
			  name = &buf[4];	// key
			  if (GSObjCFindVariable(self,
			    name, &type, &size, &off) == NO) // 还是找值.
			    {
			      buf[4] = hi;
			      buf[3] = 's';
			      buf[2] = 'i';
			      name = &buf[2];	// isKey
			      GSObjCFindVariable(self,
				name, &type, &size, &off); // 还是找值.
			    }
			}
		    }
		}
	    }
	  else
	    {
	      GSOnceFLog(@"Key-value access using _setKey: is deprecated:");
	    }
	}
    }
  GSObjCSetVal(self, key, anObject, sel, type, size, off);
}

static id ValueForKey(NSObject *self, const char *key, unsigned size)
{
  SEL		sel = 0;
  int		off = 0;
  const char	*type = NULL;

  if (size > 0)
    {
      const char	*name;
      char		buf[size + 5];
      char		lo;
      char		hi;

      strncpy(buf, "_get", 4);
      strncpy(&buf[4], key, size);
      buf[size + 4] = '\0';
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;

      name = &buf[1];	// getKey
      sel = sel_getUid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  buf[4] = lo;
	  name = &buf[4];	// key
	  sel = sel_getUid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
              buf[4] = hi;
              buf[3] = 's';
              buf[2] = 'i';
              name = &buf[2];	// isKey
              sel = sel_getUid(name);
              if (sel == 0 || [self respondsToSelector: sel] == NO)
                {
                  sel = 0;
                }
	    }
	}

      if (sel == 0 && [[self class] accessInstanceVariablesDirectly] == YES)
	{
	  buf[4] = hi;
	  name = buf;	// _getKey
	  sel = sel_getUid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      buf[4] = lo;
	      buf[3] = '_';
	      name = &buf[3];	// _key
	      sel = sel_getUid(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  sel = 0;
		}
	    }
	  if (sel == 0)
	    {
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
                  buf[4] = hi;
                  buf[3] = 's';
                  buf[2] = 'i';
                  buf[1] = '_';
                  name = &buf[1];	// _isKey
		  if (!GSObjCFindVariable(self, name, &type, &size, &off))
                    {
                       buf[4] = lo;
                       name = &buf[4];		// key
		       if (!GSObjCFindVariable(self, name, &type, &size, &off))
                         {
                            buf[4] = hi;
                            buf[3] = 's';
                            buf[2] = 'i';
                            name = &buf[2];	// isKey
                            GSObjCFindVariable(self, name, &type, &size, &off);
                         }
                    }
		}
	    }
	}
    }
  return GSObjCGetVal(self, key, sel, type, size, off);
}


@implementation NSObject(KeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly
{
  return YES; // 默认是 可以用 kvc 访问数据的.
}


- (NSDictionary*) dictionaryWithValuesForKeys: (NSArray*)keys
{
  NSMutableDictionary	*dictionary;
  NSEnumerator		*enumerator;
  id			key;
  dictionary = [NSMutableDictionary dictionaryWithCapacity: [keys count]];
  enumerator = [keys objectEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      id	value = [self valueForKey: key];

      if (value == nil)
	{
	  value = [NSNull null]; // 这里, 就算这个对象没有key 对应的数值, 他还是塞到了返回值中了.
	}
      [dictionary setObject: value forKey: key];
    }
  return dictionary;
}

- (void) setNilValueForKey: (NSString*)aKey // 所以, 在 KVC 的时候, 如果 value 为 nil 默认是抛出异常的.
{
  [NSException raise: NSInvalidArgumentException
    format: @"%@ -- %@ 0x%"PRIxPTR": Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]),
    (NSUInteger)self, aKey];
}
- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
  unsigned	size = [aKey length] * 8;
  char		key[size + 1]; //
  [aKey getCString: key
	 maxLength: size + 1
	  encoding: NSUTF8StringEncoding]; // 首先, 把 NSString 变为了 c 语言的字符串.
  size = strlen(key);
  SetValueForKey(self, anObject, key, size);
}


- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];
  if (r.length == 0)
    {
      [self setValue: anObject forKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];
      
      [[self valueForKey: key] setValue: anObject forKeyPath: path];
        // 根据 . 前面的值进行取值, 然后递归调用这个方法. 前面的 r.length == 0 进行递归的终止.
    }
}


- (void) setValue: (id)anObject forUndefinedKey: (NSString*)aKey // 默认是抛出异常.
{
  NSDictionary	*dict;
  NSException	*exp; 
  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    (anObject ? (id)anObject : (id)@"(nil)"), @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  exp = [NSException exceptionWithName: NSUndefinedKeyException
				reason: @"Unable to set value for undefined key"
			      userInfo: dict];
  [exp raise];
}

// 为什么我们不直接调用这个方法呢, 因为这个方法太危险了. dictionary 的 key, value 的获取是很简单的, 但是直接调用 setValue forKey 太危险了. 因为 NSObject 的默认是进行了异常抛出. 这就是那些框架有用的原因, 它会先拿到 propertyList 的信息, 然后根据这些信息, 如果 Object 里面不该调用 set 方法, 他就不会去调用.
- (void) setValuesForKeysWithDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator;
  NSString	*key;
  enumerator = [aDictionary keyEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      [self setValue: [aDictionary objectForKey: key] forKey: key];
    }
}


- (BOOL) validateValue: (id*)aValue
                forKey: (NSString*)aKey
                 error: (NSError**)anError
{
  unsigned	size;

  if (aValue == 0 || (size = [aKey length] * 8) == 0)
    {
      [NSException raise: NSInvalidArgumentException format: @"nil argument"];
    }
  else
    {
      char		name[size + 16];
      SEL		sel;
      BOOL		(*imp)(id,SEL,id*,id*);

      strncpy(name, "validate", 8);
      [aKey getCString: &name[8]
	     maxLength: size + 1
	      encoding: NSUTF8StringEncoding];
      size = strlen(&name[8]);
      strncpy(&name[size + 8], ":error:", 7);
      name[size + 15] = '\0';
      if (islower(name[8]))
	{
	  name[8] = toupper(name[8]);
	}
      sel = sel_getUid(name);
      if (sel != 0 && [self respondsToSelector: sel] == YES)
	{
	  imp = (BOOL (*)(id,SEL,id*,id*))[self methodForSelector: sel];
	  return (*imp)(self, sel, aValue, anError);
	}
    }
  return YES;
}

- (BOOL) validateValue: (id*)aValue
            forKeyPath: (NSString*)aKey
                 error: (NSError**)anError
{
  NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];

  if (r.length == 0)
    {
      return [self validateValue: aValue forKey: aKey error: anError];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      return [[self valueForKey: key] validateValue: aValue
                                         forKeyPath: path
                                              error: anError];
    }
}


- (id) valueForKey: (NSString*)aKey
{
  unsigned	size = [aKey length] * 8;
  char		key[size + 1];

  [aKey getCString: key
	 maxLength: size + 1
	  encoding: NSUTF8StringEncoding];
  size = strlen(key);
  return ValueForKey(self, key, size);
}


- (id) valueForKeyPath: (NSString*)aKey
{
    
    // 同理, 递归取值.
  NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];

  if (r.length == 0)
    {
      return [self valueForKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      return [[self valueForKey: key] valueForKeyPath: path];
    }
}


- (id) valueForUndefinedKey: (NSString*)aKey
{
  NSDictionary	*dict;
  NSException	*exp;
  NSString      *reason;
  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    self, @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  reason = [NSString stringWithFormat:
    @"Unable to find value for key \"%@\" of object %@ (%@)",
    aKey, self, [self class]];
  exp = [NSException exceptionWithName: NSUndefinedKeyException
				reason: reason
			      userInfo: dict];

  [exp raise];
  return nil;
}


#ifdef WANT_DEPRECATED_KVC_COMPAT

+ (BOOL) useStoredAccessor
{
  return YES;
}

- (id) storedValueForKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      return [self valueForKey: aKey];
    }

  size = [aKey length] * 8;
  if (size > 0)
    {
      SEL		sel = 0;
      const char	*type = NULL;
      int		off = 0;
      const char	*name;
      char		key[size + 1];
      char		buf[size + 5];
      char		lo;
      char		hi;

      strncpy(buf, "_get", 4);
      [aKey getCString: key
	     maxLength: size + 1
	      encoding: NSUTF8StringEncoding];
      size = strlen(key);
      strncpy(&buf[4], key, size);
      buf[size + 4] = '\0';
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;

      name = buf;	// _getKey
      sel = sel_getUid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  buf[3] = '_';
	  buf[4] = lo;
	  name = &buf[3]; // _key
	  sel = sel_getUid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	    }
	}
      if (sel == 0)
	{
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      // _key
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4]; // key
		  GSObjCFindVariable(self, name, &type, &size, &off);
		}
	    }
	  if (type == NULL)
	    {
	      buf[3] = 't';
	      buf[4] = hi;
	      name = &buf[1]; // getKey
	      sel = sel_getUid(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  buf[4] = lo;
		  name = &buf[4];	// key
		  sel = sel_getUid(name);
		  if (sel == 0 || [self respondsToSelector: sel] == NO)
		    {
		      sel = 0;
		    }
		}
	    }
	}
      if (sel != 0 || type != NULL)
	{
	  return GSObjCGetVal(self, key, sel, type, size, off);
	}
    }
  [self handleTakeValue: nil forUnboundKey: aKey];
  return nil;
}


- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      [self takeValue: anObject forKey: aKey];
      return;
    }

  size = [aKey length] * 8;
  if (size > 0)
    {
      SEL		sel;
      const char	*type;
      int		off;
      const char	*name;
      char		key[size + 1];
      char		buf[size + 6];
      char		lo;
      char		hi;

      strncpy(buf, "_set", 4);
      [aKey getCString: key
	     maxLength: size + 1
	      encoding: NSUTF8StringEncoding];
      size = strlen(key);
      strncpy(&buf[4], key, size);
      buf[size + 4] = '\0';
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size + 4] = ':';
      buf[size + 5] = '\0';

      name = buf;	// _setKey:
      type = NULL;
      off = 0;
      sel = sel_getUid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  sel = 0;
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      buf[size + 4] = '\0';
	      buf[4] = lo;
	      buf[3] = '_';
	      name = &buf[3];		// _key
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4];	// key
		  GSObjCFindVariable(self, name, &type, &size, &off);
		}
	    }
	  if (type == NULL)
	    {
	      buf[size + 4] = ':';
	      buf[4] = hi;
	      buf[3] = 't';
	      name = &buf[1];		// setKey:
	      sel = sel_getUid(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  sel = 0;
		}
	    }
	}
      if (sel != 0 || type != NULL)
	{
	  GSObjCSetVal(self, key, anObject, sel, type, size, off);
	  return;
	}
    }
  [self handleTakeValue: anObject forUnboundKey: aKey];
}


- (void) takeStoredValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      id obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeStoredValue: obj forKey: key];
    }
}

- (id) handleQueryWithUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
    self, @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  NSException *exp = [NSException exceptionWithName: NSUndefinedKeyException
				  reason: @"Unable to find value for key"
				  userInfo: dict];

  GSOnceMLog(@"This method is deprecated, use -valueForUndefinedKey:");
  [exp raise];
  return nil;
}


- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
    (anObject ? (id)anObject : (id)@"(nil)"), @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  NSException *exp = [NSException exceptionWithName: NSUndefinedKeyException
				  reason: @"Unable to set value for key"
				  userInfo: dict];
  GSOnceMLog(@"This method is deprecated, use -setValue:forUndefinedKey:");
  [exp raise];
}


- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  SEL		sel = 0;
  const char	*type = 0;
  int		off = 0;
  unsigned	size = [aKey length] * 8;
  char		key[size + 1];

  GSOnceMLog(@"This method is deprecated, use -setValue:forKey:");
  [aKey getCString: key
	 maxLength: size + 1
	  encoding: NSUTF8StringEncoding];
  size = strlen(key);
  if (size > 0)
    {
      const char	*name;
      char		buf[size + 6];
      char		lo;
      char		hi;

      strncpy(buf, "_set", 4);
      strncpy(&buf[4], key, size);
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size + 4] = ':';
      buf[size + 5] = '\0';

      name = &buf[1];	// setKey:
      type = NULL;
      sel = sel_getUid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  name = buf;	// _setKey:
	  sel = sel_getUid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	      if ([[self class] accessInstanceVariablesDirectly] == YES)
		{
		  buf[size + 4] = '\0';
		  buf[3] = '_';
		  buf[4] = lo;
		  name = &buf[4];	// key
		  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		    {
		      name = &buf[3];	// _key
		      GSObjCFindVariable(self, name, &type, &size, &off);
		    }
		}
	    }
	}
    }
  GSObjCSetVal(self, key, anObject, sel, type, size, off);
}


- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSRange	r = [aKey rangeOfString: @"." options: NSLiteralSearch];

  GSOnceMLog(@"This method is deprecated, use -setValue:forKeyPath:");
  if (r.length == 0)
    {
      [self takeValue: anObject forKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      [[self valueForKey: key] takeValue: anObject forKeyPath: path];
    }
}


- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  GSOnceMLog(@"This method is deprecated, use -setValuesForKeysWithDictionary:");
  while ((key = [enumerator nextObject]) != nil)
    {
      id obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeValue: obj forKey: key];
    }
}


- (void) unableToSetNilForKey: (NSString*)aKey
{
  GSOnceMLog(@"This method is deprecated, use -setNilValueForKey:");
  [NSException raise: NSInvalidArgumentException format:
    @"%@ -- %@ 0x%"PRIxPTR": Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]),
    (NSUInteger)self, aKey];
}


- (NSDictionary*) valuesForKeys: (NSArray*)keys
{
  NSMutableDictionary	*dict;
  NSNull		*null = [NSNull null];
  unsigned		count = [keys count];
  unsigned		pos;

  GSOnceMLog(@"This method is deprecated, use -dictionaryWithValuesForKeys:");
  dict = [NSMutableDictionary dictionaryWithCapacity: count];
  for (pos = 0; pos < count; pos++)
    {
      NSString	*key = [keys objectAtIndex: pos];
      id 	val = [self valueForKey: key]; // 这里, 如果 val == nil 应该就退出异常退出了. 但是子类可以复写这个函数.

      if (val == nil)
	{
	  val = null;
	}
      [dict setObject: val forKey: key];
    }
  return AUTORELEASE([dict copy]);
}

#endif

@end

