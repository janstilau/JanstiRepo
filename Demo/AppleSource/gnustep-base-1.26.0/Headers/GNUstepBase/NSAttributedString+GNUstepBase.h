#ifndef	INCLUDED_NSAttributedString_GNUstepBase_h
#define	INCLUDED_NSAttributedString_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSAttributedString.h>


#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface      NSAttributedString (GNUstepBase)
/**
 * Deprecated synonym for attributedSubstringFromRange:
 * for consistency with NSString
 */
- (NSAttributedString*) attributedSubstringWithRange: (NSRange)aRange;
@end

#endif	/* OS_API_VERSION */
#endif	/* INCLUDED_NSAttributedString_GNUstepBase_h */
