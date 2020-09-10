#import "common.h"
#import "Foundation/NSThread.h"

#if	defined(NeXT_Foundation_LIBRARY)

/* These functions are in NSThread.m in the base library.
 */
NSThread*
GSCurrentThread(void)
{
  return [NSThread currentThread];
}

NSMutableDictionary*
GSCurrentThreadDictionary(void)
{
  return [GSCurrentThread() threadDictionary];
}

#endif

