#ifndef __NSNull_h_GNUSTEP_BASE_INCLUDE
#define __NSNull_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSObject.h>

/*
 * An object to use as a placeholder - in collections for instance.
 */
@interface	NSNull : NSObject <NSCoding, NSCopying>
+ (NSNull*) null;
@end

#endif	/* GS_API_MACOSX */

#endif	/* __NSNull_h_GNUSTEP_BASE_INCLUDE */
