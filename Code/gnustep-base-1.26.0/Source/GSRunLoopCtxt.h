#ifndef __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE
#define __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE
#import "common.h"
#import "Foundation/NSException.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSRunLoop.h"

/*
 *      Setup for inline operation of arrays.
 */

#define GSI_ARRAY_TYPES       GSUNION_OBJ

#define GSI_ARRAY_RELEASE(A, X)	[(X).obj release]
#define GSI_ARRAY_RETAIN(A, X)	[(X).obj retain]

#include "GNUstepBase/GSIArray.h"

#ifdef  HAVE_POLL
typedef struct{
    int   limit;
    short *index;
}pollextra;
#endif

@class NSString;
@class GSRunLoopWatcher;

@interface	GSRunLoopCtxt : NSObject
{
@public
    void		*extra;		/** Copy of the RunLoop ivar.		*/
    NSString	*mode;		/** The mode for this context.		*/
    GSIArray	cachedPerformers;	/** The actions to perform regularly.	*/
    unsigned	maxPerformers;
    
    GSIArray	cachedTimers;		/** The timers set for the runloop mode */
    unsigned	maxTimers;
    
    GSIArray	watchers;	/** The inputs set for the runloop mode */
    unsigned	maxWatchers;
    
@private
    NSMapTable	*_efdMap;
    NSMapTable	*_rfdMap;
    NSMapTable	*_wfdMap;
    GSIArray	_trigger;	// Watchers to trigger unconditionally.
    int		fairStart;	// For trying to ensure fair handling.
    BOOL		completed;	// To mark operation as completed.
#ifdef	HAVE_POLL
    unsigned int	pollfds_capacity;
    unsigned int	pollfds_count;
    struct pollfd	*pollfds;
#endif
}
/* Check to see of the thread has been awakened, blocking until it
 * does get awakened or until the limit date has been reached.
 * A date in the past (or nil) results in a check followed by an
 * immediate return.
 */
+ (BOOL) awakenedBefore: (NSDate*)when;
- (void) endEvent: (void*)data
              for: (GSRunLoopWatcher*)watcher;
- (void) endPoll;
- (id) initWithMode: (NSString*)theMode extra: (void*)e;
- (BOOL) pollUntil: (int)milliseconds within: (NSArray*)contexts;
@end

#endif /* __GSRunLoopCtxt_h_GNUSTEP_BASE_INCLUDE */
