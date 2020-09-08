#ifndef __NSDistributedLock_h_GNUSTEP_BASE_INCLUDE
#define __NSDistributedLock_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

@class	NSDate;
@class	NSLock;
@class	NSString;

/*
 A lock that multiple applications on multiple hosts can use to restrict access to some shared resource, such as a file.
 */
@interface NSDistributedLock : NSObject
{
  NSString	*_lockPath;
  NSDate	*_lockTime;
  NSLock	*_localLock;
}

+ (NSDistributedLock*) lockWithPath: (NSString*)aPath;
- (id) initWithPath: (NSString*)aPath;

- (void) breakLock;
- (NSDate*) lockDate;
- (BOOL) tryLock;
- (void) unlock;

@end

#endif /* __NSDistributedLock_h_GNUSTEP_BASE_INCLUDE */
