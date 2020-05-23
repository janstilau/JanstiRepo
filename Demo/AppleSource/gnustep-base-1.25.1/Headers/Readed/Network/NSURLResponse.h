#ifndef __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#define __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST)

#import	<Foundation/NSObject.h>

/*
 从这里可以看出. NSURLResponse 就是一个纯数据类而已.
 它只是表示的是, HTTP 的响应头信息. 响应体还是需要 data 拼接完毕之后, 解析之后才能够使用.
 */

@class NSDictionary;
@class NSString;
@class NSURL;

#define NSURLResponseUnknownLength ((long long)-1)

/**
 * The response to an NSURLRequest
 */
@interface NSURLResponse :  NSObject <NSCoding, NSCopying>
{
    long long        expectedContentLength;
    NSURL            *URL;
    NSString        *MIMEType;
    NSString        *textEncodingName;
    NSString        *statusText;
    /*
     响应头里面的信息, 其实就是放到了一个字典里面了. 因为就是 keyValue 对应而已, 放到一个字典里面, 容易扩展.
     */
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
