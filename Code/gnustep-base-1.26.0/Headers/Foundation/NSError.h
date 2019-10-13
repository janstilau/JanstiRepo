#ifndef __NSError_h_GNUSTEP_BASE_INCLUDE
#define __NSError_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_3,GS_API_LATEST)

@class NSArray, NSDictionary, NSString;

/**
 * Error information class.<br />
 * NSError instances are used to pass information about runtime errors
 * from lower levels to higher levels of the program.<br />
 * These should be used instead of exceptions where an error is caused
 * by external factors (such as a resource file not being present)
 * rather than a programming error (where NSException should be used).
 这就是一个简简单单的数据类而已.
 */
@interface NSError : NSObject <NSCopying, NSCoding>
{
    int		_code;
    NSString	*_domain;
    NSDictionary	*_userInfo;
}

/**
 * Creates and returns an autoreleased NSError instance by calling
 * -initWithDomain:code:userInfo:
 */
+ (id) errorWithDomain: (NSString*)aDomain
                  code: (NSInteger)aCode
              userInfo: (NSDictionary*)aDictionary;

/**
 * Return the error code ... which is not globally unique, just unique for
 * a particular domain.
 */
- (NSInteger) code;

/**
 * Return the domain for this instance.
 */
- (NSString*) domain;

/** <init />
 * Initialises the receiver using the supplied domain, code, and info.<br />
 * The domain must be non-nil.
 */
- (id) initWithDomain: (NSString*)aDomain
                 code: (NSInteger)aCode
             userInfo: (NSDictionary*)aDictionary;

/**
 * Return a human readable description for the error.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it generates a generic one from domain
 * and code.
 */
- (NSString *) localizedDescription;

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST)
/**
 * Return a human readable explanation of the reason for the error
 * (if known).  This should normally be a more discursive explanation
 * then the short one provided by the -localizedDescription method.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it returns nil.
 */
- (NSString *) localizedFailureReason;

/**
 * Returns an array of strings to be used as titles of buttons in an
 * alert panel when offering the user optionbs to try to recover from
 * the error.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it returns nil.
 */
- (NSArray *) localizedRecoveryOptions;

/**
 * Returns a string used as the secondary text in an alert panel,
 * suggesting how the user might select an option to attempt to
 * recover from the error.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it returns nil.
 */
- (NSString *) localizedRecoverySuggestion;

/**
 * Not yet useful in GNUstep.<br />
 * The default implementation uses the value from the user info dictionary
 * if it is available, otherwise it returns nil.
 */
- (id) recoveryAttempter;
#endif

/**
 * Return the user info for this instance (or nil if none is set)<br />
 * The <code>NSLocalizedDescriptionKey</code> should locate a human readable
 * description in the dictionary.<br />
 * The <code>NSUnderlyingErrorKey</code> key should locate an
 * <code>NSError</code> instance if an error is available describing any
 * underlying problem.<br />
 */
- (NSDictionary*) userInfo;
@end

#endif

#endif	/* __NSError_h_GNUSTEP_BASE_INCLUDE*/
