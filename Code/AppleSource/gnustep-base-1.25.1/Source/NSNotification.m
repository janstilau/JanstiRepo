#import "common.h"
#define	EXPOSE_NSNotification_IVARS	1
#import "Foundation/NSNotification.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDictionary.h"

@class	GSNotification;
@interface GSNotification : NSObject	// Help the compiler
@end

/**
 *  <p>Represents a notification for posting to an [NSNotificationCenter].
 *  Consists of a name, an object, and an optional dictionary.  The
 *  notification center will check for observers registered to receive
 *  either notifications with the name, the object, or both and pass the
 *  notification instance on to them.</p>
 *  <p>This class is actually the interface for a class cluster, so instances
 *  will be of a (private) subclass.</p>
 
    上面是对于 NSNotification 的描述.
 */

@implementation NSNotification

static Class	abstractClass = 0;
static Class	concreteClass = 0;

// 这里是一个实现技巧, 控制最终真实的对象的一个技巧. 如果这是一个类簇模式, 那么可以在 allocWithZone 中返回一个固定的对象, 然后在 init 里面, 根据参数, 生成真正的子类对象. 不过, 这里只有一个子类, 所以直接返回的是子类. 这里不明白, 为什么要进行子类化, 只有一个子类直接写到原始类里面不得了. 难道是为了扩展???
+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    {
      return (id)NSAllocateObject(concreteClass, 0, z);
    }
  return (id)NSAllocateObject(self, 0, z);
}

// initialize 可以做很多事情. 我觉得, 许多的单例对象可以不存在, 如果真的只有一份的话, 那么用类方法, 和 static 对象完全没有问题.
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
  return [self retain];
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

// 这里, 就是在 init 方法里面, 生成最终的实体类.
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
// 所以说, 在用输出参数的时候, 其实也要进行 release 操作. 不过, 在 ARC 的环境下, 这个其实也不用理会的.
  DESTROY(self);
  return RETAIN(n);
}

@end
