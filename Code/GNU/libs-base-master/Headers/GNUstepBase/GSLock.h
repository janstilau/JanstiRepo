#ifndef	INCLUDED_GS_LOCK_H
#define	INCLUDED_GS_LOCK_H

#ifndef NeXT_Foundation_LIBRARY
#import	<Foundation/NSLock.h>
#else
#import <Foundation/Foundation.h>
#endif

#import "GNUstepBase/GSObjCRuntime.h"

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSNotification;

@interface	GSLazyLock : NSLock
{
  int	locked;
}
- (void) _becomeThreaded: (NSNotification*)n;
@end

@interface	GSLazyRecursiveLock : NSRecursiveLock
{
  int	counter;
}
- (void) _becomeThreaded: (NSNotification*)n;
@end

/** Global lock to be used by classes when operating on any global
    data that invoke other methods which also access global; thus,
    creating the potential for deadlock. */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_GS_LOCK_H */
