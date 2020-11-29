#import "common.h"
#import "Foundation/NSException.h"
#import "GNUstepBase/NSLock+GNUstepBase.h"
#import "GNUstepBase/GSLock.h"

/**
 * GNUstep specific (non-standard) additions to the NSLock class.
 */

static GSLazyRecursiveLock *local_lock = nil;

/* This class only exists to provide a thread safe mechanism to
   initialize local_lock as +initialize is called under a lock in ObjC
   runtimes.  User code should resort to GS_INITIALIZED_LOCK(), which
   uses the +newLockAt: extension.  */

@interface _GSLockInitializer : NSObject
@end
@implementation _GSLockInitializer
+ (void) initialize
{
  if (local_lock == nil)
    {
      /* As we do not know whether creating custom locks may
	 implicitly create other locks, we use a recursive lock.  */
      local_lock = [GSLazyRecursiveLock new];
    }
}

@end

static inline id
newLockAt(Class self, SEL _cmd, id *location)
{
  if (location == 0)
    {
      [NSException raise: NSInvalidArgumentException
                   format: @"'%@' called with nil location",
		   NSStringFromSelector(_cmd)];
    }

  if (*location == nil)
    {
      if (local_lock == nil)
	{
	  [_GSLockInitializer class];
	}

      [local_lock lock];

      if (*location == nil)
	{
	  *location = [[(id)self alloc] init];
	}

      [local_lock unlock];
    }

  return *location;
}


@implementation NSLock (GNUstepBase)
+ (id) newLockAt: (id *)location
{
  return newLockAt(self, _cmd, location);
}
@end

@implementation NSRecursiveLock (GNUstepBase)
+ (id) newLockAt: (id *)location
{
  return newLockAt(self, _cmd, location);
}
@end

