
#ifndef __NSURLError_h_GNUSTEP_BASE_INCLUDE
#define __NSURLError_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;

/**
 * The domain for a URL error.
 */
extern NSString * const NSURLErrorDomain;

/**
 * Obtain the URL which caused the failure
 */
extern NSString * const NSErrorFailingURLStringKey;

/**
 * Error codes for URL errors
 */
// 这个类, 仅仅是一些 Code 的定义而已. 使用他们的地方, 在具体的业务逻辑中.
enum
{
    NSURLErrorUnknown = 				-1,
    NSURLErrorCancelled = 			-999,
    NSURLErrorBadURL = 				-1000,
    NSURLErrorTimedOut = 				-1001,
    NSURLErrorUnsupportedURL = 			-1002,
    NSURLErrorCannotFindHost = 			-1003,
    NSURLErrorCannotConnectToHost = 		-1004,
    NSURLErrorNetworkConnectionLost = 		-1005,
    NSURLErrorDNSLookupFailed = 			-1006,
    NSURLErrorHTTPTooManyRedirects = 		-1007,
    NSURLErrorResourceUnavailable = 		-1008,
    NSURLErrorNotConnectedToInternet = 		-1009,
    NSURLErrorRedirectToNonExistentLocation = 	-1010,
    NSURLErrorBadServerResponse = 		-1011,
    NSURLErrorUserCancelledAuthentication = 	-1012,
    NSURLErrorUserAuthenticationRequired = 	-1013,
    NSURLErrorZeroByteResource = 			-1014,
    NSURLErrorFileDoesNotExist = 			-1100,
    NSURLErrorFileIsDirectory = 			-1101,
    NSURLErrorNoPermissionsToReadFile = 		-1102,
    NSURLErrorSecureConnectionFailed = 		-1200,
    NSURLErrorServerCertificateHasBadDate = 	-1201,
    NSURLErrorServerCertificateUntrusted = 	-1202,
    NSURLErrorServerCertificateHasUnknownRoot =	-1203,
    NSURLErrorServerCertificateNotYetValid = 	-1204,
    NSURLErrorClientCertificateRejected = 	-1205,
    NSURLErrorCannotLoadFromNetwork = 		-2000,
    
    NSURLErrorCannotCreateFile = 			-3000,
    NSURLErrorCannotOpenFile = 			-3001,
    NSURLErrorCannotCloseFile = 			-3002,
    NSURLErrorCannotWriteToFile = 		-3003,
    NSURLErrorCannotRemoveFile = 			-3004,
    NSURLErrorCannotMoveFile = 			-3005,
    NSURLErrorDownloadDecodingFailedMidStream =	-3006,
    NSURLErrorDownloadDecodingFailedToComplete =	-3007
};

#if	defined(__cplusplus)
}
#endif

#endif

#endif
