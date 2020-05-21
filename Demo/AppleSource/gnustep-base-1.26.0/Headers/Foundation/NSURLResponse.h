#ifndef __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#define __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST)

#import	<Foundation/NSObject.h>

@class NSDictionary;
@class NSString;
@class NSURL;

#define NSURLResponseUnknownLength ((long long)-1)

/**
 The metadata associated with the response to a URL load request, independent of protocol and URL scheme.
 所以, body 的内容, 其实不是在 response 里面的.
 */
@interface NSURLResponse :  NSObject <NSCoding, NSCopying>
{
    long long        expectedContentLength; // data 的 length
    NSURL            *URL; // The URL for the response.
    NSString        *MIMEType; // data 的类型
    NSString        *textEncodingName;
    NSString        *statusText; // 200
    NSMutableDictionary    *headers; /* _GSMutableInsensitiveDictionary */
    int            statusCode;
}

/**
 * Returns the expected content length of the receiver or -1 if
 * there is no idea of what the content length might be.<br />
 * This value is advisory, not a definitive length.
 */
- (long long) expectedContentLength;

/**
 * Initialises the receiver with the URL, MIMEType, expected length and
 * text encoding name provided.
 */
- (id) initWithURL: (NSURL *)URL
          MIMEType: (NSString *)MIMEType
expectedContentLength: (NSInteger)length
  textEncodingName: (NSString *)name;

- (id) initWithURL: (NSURL*)URL
        statusCode: (NSInteger)statusCode
       HTTPVersion: (NSString*)HTTPVersion
      headerFields: (NSDictionary*)headerFields;
#endif

/**
 * Returns the receiver's MIME type.
 */
- (NSString *) MIMEType;

/**
 * Returns a suggested file name for storing the response data, with
 * suggested names being found in the following order:<br />
 * <list>
 *   <item>content-disposition header</item>
 *   <item>last path component of URL</item>
 *   <item>host name from URL</item>
 *   <item>'unknown'</item>
 * </list>
 * If possible, an extension based on the MIME type of the response
 * is also appended.<br />
 * The result should always be a valid file name.
 */
- (NSString *) suggestedFilename;

/**
 * Returns the name of the character set used where response data is text
 */
- (NSString *) textEncodingName;

/**
 * Returns the receiver's URL.
 */
- (NSURL *) URL;

@end


/**
 * HTTP specific additions to an NSURLResponse
 */
@interface NSHTTPURLResponse :  NSURLResponse

/**
 * Returns a string representation of a status code.
 */
+ (NSString *) localizedStringForStatusCode: (NSInteger)statusCode;

/**
 * Returns a dictionary containing all the HTTP header fields.
 */
- (NSDictionary *) allHeaderFields;

/**
 * Returns the HTTP status code for the response.
 */
- (NSInteger) statusCode;

@end

#endif
#endif
