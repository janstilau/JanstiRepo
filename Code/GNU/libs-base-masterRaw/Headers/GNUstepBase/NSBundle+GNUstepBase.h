#ifndef	INCLUDED_NSBundle_GNUstepBase_h
#define	INCLUDED_NSBundle_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSBundle.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface NSBundle(GNUstepBase)
+ (NSString *) pathForLibraryResource: (NSString *)name
                               ofType: (NSString *)ext
                          inDirectory: (NSString *)bundlePath;
@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSBundle_GNUstepBase_h */

