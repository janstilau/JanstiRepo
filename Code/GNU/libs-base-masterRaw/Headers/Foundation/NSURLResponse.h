#ifndef __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#define __NSURLResponse_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif


@class NSDictionary;
@class NSString;
@class NSURL;

#define NSURLResponseUnknownLength ((long long)-1)

/*
 The metadata associated with the response to a URL load request, independent of protocol and URL scheme.
 文档里面的描述很清楚, 这个类, 不是响应的全部内容, 仅仅是元信息.
 
 URLResponse objects don’t contain the actual bytes representing the content of a URL. Instead, the data is returned either a piece at a time through delegate calls or in its entirety when the request completes, depending on the method and class used to initiate the request.
 */
// Response 里面没有 body 信息, response 仅仅是对响应头的一个封装而已.
@interface NSURLResponse :  NSObject <NSCoding, NSCopying>
{
    /*
     Some protocol implementations report the content length as part of the response, but not all protocols guarantee to deliver that amount of data. Your app should be prepared to deal with more or less data.
     一般来说, Http 请求, 会返回该值, 该值在 Content-Length  中传递.
     */
    long long        expectedContentLength;
    NSURL            *URL;
    /*
     The MIME type of the response.
     Mime type 是元信息, 客户端根据这个值去处理 data 的内容.
     */
    NSString        *MIMEType;
    
    NSString        *textEncodingName;
    NSString        *statusText; // Http 的字段
    NSMutableDictionary    *headers; // Http 的字段
    int            statusCode; // Http 的字段
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

#if	defined(__cplusplus)
}
#endif

#endif

#endif
