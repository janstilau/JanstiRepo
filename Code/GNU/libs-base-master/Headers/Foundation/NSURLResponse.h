#ifndef __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#define __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST)

#import	<Foundation/NSObject.h>


@class NSDictionary;
@class NSString;
@class NSURL;

#define NSURLResponseUnknownLength ((long long)-1)

/*
 这个类, 仅仅是存储一下 响应头信息而已, 响应的 data 信息可能非常大, 服务器端不断的传递到客户端, 而响应头会很小, 可以短时间内, 交给客户端进行处理.
 客户端根据响应头的数据, 做相应的处理, 比如, 将网络交互, 变为 download task 等等.
 */
@interface NSURLResponse :  NSObject <NSCoding, NSCopying>
{
    long long        expectedContentLength;
    NSURL            *URL;
    NSString        *MIMEType;
    NSString        *textEncodingName;
    NSString        *statusText;
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

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7,GS_API_LATEST)
/**
 * Initialises the receiver with the URL, statusCode, HTTPVersion, and
 * headerFields provided.
 */
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
