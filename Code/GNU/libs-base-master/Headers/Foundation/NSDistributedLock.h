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
  NSDate	*_lockTime; // 有值, 代表已经取得了锁.
  NSLock	*_localLock; // 这个锁, 是为了防止当前进程里面, 多个线程同时在进行分布式锁的加锁解锁操作.
    // 分布式锁要解决多进程之间的操作, 首先把进程内部的线程管理好.
}

+ (NSDistributedLock*) lockWithPath: (NSString*)aPath;
- (id) initWithPath: (NSString*)aPath;

- (void) breakLock;
- (NSDate*) lockDate;
- (BOOL) tryLock;
- (void) unlock;

@end

#endif /* __NSDistributedLock_h_GNUSTEP_BASE_INCLUDE */
