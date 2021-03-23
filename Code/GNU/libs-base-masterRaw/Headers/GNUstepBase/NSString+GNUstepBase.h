#ifndef	INCLUDED_NSString_GNUstepBase_h
#define	INCLUDED_NSString_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSString.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

/**
 * Provides some additional (non-standard) utility methods.
 */
@interface NSString (GNUstepBase)

/**
 * Alternate way to invoke <code>stringWithFormat</code> if you have or wish
 * to build an explicit <code>va_list</code> structure.
 */
+ (id) stringWithFormat: (NSString*)format
              arguments: (va_list)argList NS_FORMAT_FUNCTION(1,0);

/**
 * Returns a string formed by removing the prefix string from the
 * receiver.  Raises an exception if the prefix is not present.
 */
- (NSString*) stringByDeletingPrefix: (NSString*)prefix;

/**
 * Returns a string formed by removing the suffix string from the
 * receiver.  Raises an exception if the suffix is not present.
 */
- (NSString*) stringByDeletingSuffix: (NSString*)suffix;

/**
 * Returns a string formed by removing leading white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingLeadSpaces;

/**
 * Returns a string formed by removing trailing white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingTailSpaces;

/**
 * Returns a string formed by removing both leading and trailing
 * white space from the receiver.
 */
- (NSString*) stringByTrimmingSpaces;

/**
 * Returns a string in which any (and all) occurrences of
 * replace in the receiver have been replaced with by.
 * Returns the receiver if replace
 * does not occur within the receiver.  NB. an empty string is
 * not considered to exist within the receiver.
 */
- (NSString*) stringByReplacingString: (NSString*)replace
                           withString: (NSString*)by;

/**
 * An obsolete name for -substringWithRange: ... deprecated.
 */
- (NSString*) substringFromRange: (NSRange)aRange;

@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSString_GNUstepBase_h */

