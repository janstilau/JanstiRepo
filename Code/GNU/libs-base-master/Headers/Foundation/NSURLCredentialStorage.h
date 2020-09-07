#ifndef __NSURLCredentialStorage_h_GNUSTEP_BASE_INCLUDE
#define __NSURLCredentialStorage_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSDictionary;
@class NSString;
@class NSURLCredential;
@class NSURLProtectionSpace;

/**
 * Notification sent when the set of stored credentials changes.
 */
extern NSString *const NSURLCredentialStorageChangedNotification;

/**
 * Provides shared storage of credentials.
 */
@interface NSURLCredentialStorage : NSObject
{
#if	GS_EXPOSE(NSURLCredentialStorage)
    void *_NSURLCredentialStorageInternal;
#endif
}

/**
 * Return the shared credential storage object.
 */
+ (NSURLCredentialStorage *) sharedCredentialStorage;

/**
 * Returns a dictionary of dictionaries ... with [NSURLProtectionSpace]
 * objects as the keys in the outer dictionary, and values which are
 * dictionaries of the credentails within each protection space.
 */
- (NSDictionary *) allCredentials;

/**
 * Returns a dictionary mapping usernames to credentials
 * for the specified protection space.<br />
 * Each username is a unique identifier for a credential
 * within a protection space.
 */
- (NSDictionary *) credentialsForProtectionSpace: (NSURLProtectionSpace *)space;

/**
 * Returns the default credential for the specified protection space, or
 * nil if none is set.
 */
- (NSURLCredential *) defaultCredentialForProtectionSpace:
(NSURLProtectionSpace *)space;

/**
 * Removes the credential from both in-memory and persistent storage
 * for the specified protection space.
 */
- (void) removeCredential: (NSURLCredential *)credential
       forProtectionSpace: (NSURLProtectionSpace *)space;

/**
 * Sets credential in the storage for the protection space specified.<br />
 * This replaces any old value with the same username.
 */
- (void) setCredential: (NSURLCredential *)credential
    forProtectionSpace: (NSURLProtectionSpace *)space;

/**
 * Sets the default credential for the protection space.  Also calls
 * -setCredential:forProtectionSpace: if the credential has not already
 * been set in space.
 */
- (void) setDefaultCredential: (NSURLCredential *)credential
           forProtectionSpace: (NSURLProtectionSpace *)space;

@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif
