
#ifndef __NSNull_h_GNUSTEP_BASE_INCLUDE
#define __NSNull_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSObject.h>

/*
 
 NSNull 就是一个单例, 把这个单例当做是空的标志.
 */
@interface	NSNull : NSObject <NSCoding, NSCopying>
+ (NSNull*) null;
@end

#endif	/* GS_API_MACOSX */

#endif	/* __NSNull_h_GNUSTEP_BASE_INCLUDE */
