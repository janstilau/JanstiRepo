
#ifndef	INCLUDED_NSThread_GNUstepBase_h
#define	INCLUDED_NSThread_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSThread.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface NSThread (GNUstepBase)

@end

GS_EXPORT NSThread *GSCurrentThread(void);
GS_EXPORT NSMutableDictionary *GSCurrentThreadDictionary(void);

#endif	/* OS_API_VERSION */

#endif	/* INCLUDED_NSThread_GNUstepBase_h */

