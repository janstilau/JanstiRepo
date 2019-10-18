#import "common.h"
#define	EXPOSE_NSNotification_IVARS	1
#import "Foundation/NSNotification.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"

@class	GSNotification;
@interface GSNotification : NSObject	// Help the compiler
@end
@implementation NSNotification

static Class	abstractClass = 0;
static Class	concreteClass = 0;

+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    {
      return (id)NSAllocateObject(concreteClass, 0, z);
    }
  return (id)NSAllocateObject(self, 0, z);
}

+ (void) initialize
{
  if (concreteClass == 0)
    {
      abstractClass = [NSNotification class];
      concreteClass = [GSNotification class];
    }
}

/**
 * Create a new autoreleased notification.
 */
+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
			        userInfo: (NSDictionary*)info
{
  return [concreteClass notificationWithName: name
				      object: object
				    userInfo: info];
}

/**
 * Create a new autoreleased notification by calling
 * +notificationWithName:object:userInfo: with a nil user info argument.
 */
+ (NSNotification*) notificationWithName: (NSString*)name
				  object: (id)object
{
  return [concreteClass notificationWithName: name
				      object: object
				    userInfo: nil];
}

/**
 * The abstract class implements a copy as a simple retain ...
 * subclasses override to perform more intelligent copy operations.
 */
- (id) copyWithZone: (NSZone*)zone
{
  return [self retain]; // 这是一个不可变对象, 直接 retain 就可以了
}

/**
 * Return a description of the parts of the notification.
 */
- (NSString*) description
{
  return [[super description] stringByAppendingFormat:
    @" Name: %@ Object: %@ Info: %@",
    [self name], [self object], [self userInfo]];
}

- (id) init
{
  if ([self class] == abstractClass)
    {
      NSZone	*z = [self zone];

      DESTROY(self);
      self = (id)NSAllocateObject (concreteClass, 0, z);
    }
  return self;
}

/**
 *  Returns the notification name.
 */
- (NSString*) name
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 *  Returns the notification object.
 */
- (id) object
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/**
 * Returns the notification user information.
 */
- (NSDictionary*) userInfo
{
  [self subclassResponsibility: _cmd];
  return nil;
}

/*
 * NSCoding protocol - the MacOS-X documentation says it should conform,
 * but how can we meaningfully encode/decode the object and userInfo.
 * We do it anyway - at least it should make sense over DO.
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  id	o;

  o = [self name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
  o = [self object];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
  o = [self userInfo];
  [aCoder encodeValueOfObjCType: @encode(id) at: &o];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSString	*name;
  id		object;
  NSDictionary	*info;
  id		n;

  [aCoder decodeValueOfObjCType: @encode(id) at: &name];
  [aCoder decodeValueOfObjCType: @encode(id) at: &object];
  [aCoder decodeValueOfObjCType: @encode(id) at: &info];
  n = [NSNotification notificationWithName: name object: object userInfo: info];
  RELEASE(name);
  RELEASE(object);
  RELEASE(info);
  DESTROY(self);
  return RETAIN(n);
}

@end