#import "common.h"
#import "Foundation/NSRunLoop.h"

@class NSDate;

@interface GSRunLoopWatcher: NSObject // 这个东西, 是当输入源来看的.
{
@public
  BOOL			_invalidated;
  BOOL			checkBlocking;
  void			*data;
  id			receiver;
  RunLoopEventType	type;
  unsigned 		count;
}
- (id) initWithType: (RunLoopEventType)type
	   receiver: (id)anObj
	       data: (void*)data;
/**
 * Returns a boolean indicating whether the receiver needs the loop to
 * block to wait for input, or whether the loop can run through at once.
 * It also sets *trigger to say whether the receiver should be triggered
 * once the input test has been done or not.
 */
- (BOOL) runLoopShouldBlock: (BOOL*)trigger;
@end

#endif /* __GSRunLoopWatcher_h_GNUSTEP_BASE_INCLUDE */
