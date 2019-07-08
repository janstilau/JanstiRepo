#ifndef __NSURLAuthenticationChallenge_h_GNUSTEP_BASE_INCLUDE
#define __NSURLAuthenticationChallenge_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSError;
@class NSURLAuthenticationChallenge;
@class NSURLCredential;
@class NSURLProtectionSpace;
@class NSURLResponse;

/**
 * A challenge sender (usually an NSURLProtocol subclass handling a
 * connection/download) provides these methods to permit a client to
 * control authentication.
 */
@protocol NSURLAuthenticationChallengeSender <NSObject>

/**
 * Cancels the authenticatiopn challenge, ensuring that the load operation
 * will fail to retrieve data, completing with only the response headers
 * containing the challenge having been read from the server.
 */
- (void) cancelAuthenticationChallenge:
  (NSURLAuthenticationChallenge *)challenge;

/**
 * Tells the sender to continue the load without providing a new credential
 * for it to use ... if the challenge already had a proposed credential,
 * the sender may elect to use it.
 */
- (void) continueWithoutCredentialForAuthenticationChallenge:
  (NSURLAuthenticationChallenge *)challenge;

/**
 * Tells the sender to continue the load using the new credential
 * provided by this method.
 */
- (void) useCredential: (NSURLCredential *)credential
  forAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge;

@end

/**
 * Class to represent an authentication challenge and indicate when the
 * challenge is complete.
 */
@interface NSURLAuthenticationChallenge : NSObject
{
    NSURLProtectionSpace                *space;
    NSURLCredential                *credential;
    int                        previousFailureCount;
    NSURLResponse                    *response;
    NSError                    *error;
    id<NSURLAuthenticationChallengeSender>    sender;
}

/**
 * Returns the error with which the reciver was initialised or nil
 * if it was not initialised with an error.<br />
 * The error may indicate the nature of the authentication failure.
 */
- (NSError *) error;

/**
 * Returns the response with which the receiver was initialised.<br />
 * This response contains the authentication failure corresponding to
 * this challenge object.<br />
 * If there was no failure or response, returns nil.
 */
- (NSURLResponse *) failureResponse;

/**
 * Initialises a new challenge by copying information from an old one.
 */
- (id) initWithAuthenticationChallenge:
  (NSURLAuthenticationChallenge *)challenge
				sender:
  (id<NSURLAuthenticationChallengeSender>)sender;

/**
 * Returns the receiver initialised in the specified protection space and
 * with the specified credential.  The previousFailureCount says how many
 * requests have failed the challenge and response provide information
 * about the last failure (which caused this challenge to be created).<br />
 * The error provides information about the authentication failure and
 * the sender is the object to receive callbacks.
 */
- (id) initWithProtectionSpace: (NSURLProtectionSpace *)space
	    proposedCredential: (NSURLCredential *)credential
	  previousFailureCount: (NSInteger)previousFailureCount
	       failureResponse: (NSURLResponse *)response
			 error: (NSError *)error
			sender: (id<NSURLAuthenticationChallengeSender>)sender;

/**
 * Returns the count of failed authentication attempts.
 */
- (NSInteger) previousFailureCount;

/**
 * Returns a proposed credential to answer the challenge.<br />
 * If there is no credential available, this returns nil.<br />
 * The credential may come from storage or from the URL itsself.
 */
- (NSURLCredential *) proposedCredential;

/**
 * Returns the protection space needing authentication.
 */
- (NSURLProtectionSpace *) protectionSpace;

/**
 * Returns the sender of the challenge ... the object to which callbacks
 * should be made while processing the challenge.
 */
- (id<NSURLAuthenticationChallengeSender>) sender;

@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif
