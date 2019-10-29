#import "common.h"

#import "GSRunLoopWatcher.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPort.h"

@implementation	GSRunLoopWatcher

- (void) dealloc
{
  [super dealloc];
}

- (id) initWithType: (RunLoopEventType)aType
	   receiver: (id)anObj
	       data: (void*)item
{
  _invalidated = NO;
  receiver = anObj; // 回调对象.
  data = item; // 一个 opaque 对象.
  switch (aType)
    {
      case ET_EDESC: 	type = aType;	break;
      case ET_RDESC: 	type = aType;	break;
      case ET_WDESC: 	type = aType;	break;
      case ET_RPORT: 	type = aType;	break;
      case ET_TRIGGER: 	type = aType;	break;
      default: 
	DESTROY(self);
	[NSException raise: NSInvalidArgumentException
		    format: @"NSRunLoop - unknown event type"]; // 这里其实就是做了一个下类型检查, 用 set 不更好吗.
    }

  if ([anObj respondsToSelector: @selector(runLoopShouldBlock:)])
    {
      checkBlocking = YES;
    }

  if (![anObj respondsToSelector: @selector(receivedEvent:type:extra:forMode:)])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"RunLoop listener has no event handling method"];
    }
  return self;
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  if (checkBlocking == YES)
    {
      BOOL result = [(id)receiver runLoopShouldBlock: trigger];
      return result;
    }
  else if (type == ET_TRIGGER)
    {
      *trigger = YES;
      return NO;	// By default triggers may fire immediately
    }
  *trigger = YES;
  return YES;		// By default we must wait for input sources
}
@end

