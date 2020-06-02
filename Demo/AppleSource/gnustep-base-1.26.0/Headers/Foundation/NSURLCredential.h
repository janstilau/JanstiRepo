#ifndef __NSURLCredential_h_GNUSTEP_BASE_INCLUDE
#define __NSURLCredential_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

@class NSString;

/**
 * Controls how long a credential is retained.
 */
typedef enum {
  NSURLCredentialPersistenceNone,	/** Don't save at all */
  NSURLCredentialPersistenceForSession,	/** Save for current session */
  NSURLCredentialPersistencePermanent,	/** Save forever (on disk) */
  NSURLCredentialPersistenceSynchronizable
} NSURLCredentialPersistence;


/**
 * Represents a user/password credential
 * Credential 不可能是这么简单的东西, 这里 , GNU 只是处理了账号密码这一种情形.
 */
@interface NSURLCredential : NSObject <NSCopying>
{
    NSString            *user;
    NSString            *password;
    NSURLCredentialPersistence    persistence;
    BOOL                hasPassword;
}

/**
 * Returns an autoreleased instance initialised using the
 * -initWithUser:password:persistence: method.
 */
+ (NSURLCredential *) credentialWithUser: (NSString *)user
  password: (NSString *)password
  persistence: (NSURLCredentialPersistence)persistence;

/**
 * Determine whether the credential has a password.
 */
- (BOOL) hasPassword;

/** <init />
 * Initialises and returns the receiver with a user name and password.<br />
 * The user identifies the credential and must be specified but the
 * password may be nil.
 */
- (id) initWithUser: (NSString *)user
	   password: (NSString *)password
	persistence: (NSURLCredentialPersistence)persistence;

/**
 * Tests two credentials for equality ... credentials are considered to
 * be equal if their -user methods return the same value, since you cannot
 * have more than one credential for a suser within an [NSURLProtectionSpace].
 */
- (BOOL) isEqual: (id)other;

/**
 * Returns the password for the receiver.<br />
 * May require prompting of the user to authorize retrieval.<br />
 * May return nil if retrieval of the password fails (eg authorization
 * failure) even if the credential actually has a password.  Call the
 * -hasPassword method to determine whether the credential has a
 * password
 */
- (NSString *) password;

/**
 * Return the presistence of this credential.
 */
- (NSURLCredentialPersistence) persistence;

/**
 * Returns the user string for the receiver
 */
- (NSString *) user;

@end

#endif
#endif