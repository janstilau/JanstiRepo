#ifndef __NSURLConnection_h_GNUSTEP_BASE_INCLUDE
#define __NSURLConnection_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSCachedURLResponse;
@class NSData;
@class NSError;
@class NSURLAuthenticationChallenge;
@class NSURLRequest;
@class NSURLResponse;

/*
 The interface for NSURLConnection is sparse, providing only the controls to start and cancel asynchronous loads of a URL request. You perform most of your configuration on the URL request object itself.
 NSURLConnection 的接口很少, 仅仅提供了开始和结束 load 的控制.
 During a request, the connection maintains a strong reference to its delegate. It releases that strong reference when the connection finishes loading, fails, or is canceled.
 */
    
/**
 */
@interface NSURLConnection : NSObject
{
#if	GS_EXPOSE(NSURLConnection)
  void *_NSURLConnectionInternal;
#endif
}

/**
 * Performs a preliminary check to see if a load of the specified
 * request can be handled by an instance of this class.<br />
 * The results of this method may be invalidated by subsequent
 * changes to the request or changes to the registered protocols
 * etc.
 */
+ (BOOL) canHandleRequest: (NSURLRequest *)request;

/**
 * Allocates and returns the autoreleased instance which it initialises
 * using the -initWithRequest:delegate: method.
 */
+ (NSURLConnection *) connectionWithRequest: (NSURLRequest *)request
				   delegate: (id)delegate;

/**
 * Cancel the asynchronous load in progress (if any) for this connection.
 */
- (void) cancel;

/** <init />
 * Initialises the receiver with the specified request (performing
 * a deep copy so that the request does not change during loading)
 * and delegate.<br />
 * This automatically initiates an asynchronous load for the request.<br />
 * Processing of the request is done in the thread which calls this
 * method, so the thread must run its current run loop
 * (in NSDefaultRunLoopMode) for processing to continue/complete.<br />
 * The delegate will receive callbacks informing it of the progress
 * of the load.<br />
 * This method breaks with convention and retains the delegate object,
 * releasing it when the connection finished loading, fails, or is cancelled.
 */
- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate;

@end



/**
 * This category is an informal protocol specifying how an NSURLConnection
 * instance will communicate with its delegate to inform it of (and allow
 * it to manage) the progress of a load request.<br />
 
 * A load operation is performed by asynchronous I/O using the
 * run loop of the thread in which it was initiated, so all callbacks
 * will occur in that thread.<br />
 
 这也就是, connection 必须要在一个有着 runloop 的 thread 才能执行的原因.
 
 * The process of loading a resource occurs as follows -<br />
 * <list>
 *   <item>
 *     Any number of -connection:willSendRequest:redirectResponse:
 *     messages may be sent to the delegate before any other messages
 *     in this list are sent.  This permits a chain of redirects to
 *     be followed before eventual loading of 'real' data. // 在得到响应头数据之后, 如果响应头里面是重定向, 就会到达这里.
 *   </item>
 
 *   <item>
 *     A -connection:didReceiveAuthenticationChallenge: message may be
 *     sent to the delegate (where authentication is required) before
 *     response data can be downloaded. // 这是得到响应头之后进行的处理.
 *   </item>
 
 *   <item>
 *     Any number of -connection:didReceiveResponse: messages
 *     may be be sent to the delegate before a
 *     -connection:didReceiveData: message.  Usually there is exactly one
 *     of these, but for multipart/x-mixed-replace there may be multiple
 *     responses for each part, and if an error occurs in the download
 *     the delegate may not receive a response at all.<br />
 *     Delegates should discard previously handled data when they
 *     receive a new response. // 在得到完整的响应头之后, 会把响应头信息给代理, 然后继续下载 data
 *   </item>
 
 *   <item>
 *     Any number of -connection:didReceiveData: messages may
 *     be sent before the load completes as described below.
 *   </item>
 *   <item>
 *     A single -connection:willCacheResponse: message may
 *     be sent to the delegate after any -connection:didReceiveData:
 *     messages are sent but before a -connectionDidFinishLoading: message
 *     is sent. // 在得到完整的响应头之后, 就开始下载响应体的内容.
 *   </item>
 
 *   <item>
 *     Unless the NSURLConnection receives a -cancel message,
 *     the delegate will receive one and only one of
 *     -connectionDidFinishLoading:, or
 *     -connection:didFailWithError: message, but never
 *     both.<br />
 *     Once either of these terminal messages is sent the
 *     delegate will receive no further messages from the 
 *     NSURLConnection.
 *   </item>
 * </list>
 */
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7,GS_API_LATEST) && GS_API_VERSION(11300,GS_API_LATEST)
@protocol NSURLConnectionDelegate <NSObject>

#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (NSURLConnectionDelegate)
#endif

#else
@interface NSObject (NSURLConnectionDelegate)
#endif

/**
 * Instructs the delegate that authentication for challenge has
 * been cancelled for the request loading on connection.
 */
- (void) connection: (NSURLConnection *)connection
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge;

/*
 * Called when an NSURLConnection has failed to load successfully.
 */
- (void) connection: (NSURLConnection *)connection
   didFailWithError: (NSError *)error;

/**
 * Called when an NSURLConnection has finished loading successfully.
 */
- (void) connectionDidFinishLoading: (NSURLConnection *)connection;

/**
 * Called when an authentication challenge is received ... the delegate
 * should send -useCredential:forAuthenticationChallenge: or
 * -continueWithoutCredentialForAuthenticationChallenge: or
 * -cancelAuthenticationChallenge: to the challenge sender when done.
 */
- (void) connection: (NSURLConnection *)connection
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge;

/**
 * Called when content data arrives during a load operations ... this
 * may be incremental or may be the compolete data for the load.
 */
- (void) connection: (NSURLConnection *)connection
     didReceiveData: (NSData *)data;

/**
 * Called when enough information to build a NSURLResponse object has
 * been received.
 */
- (void) connection: (NSURLConnection *)connection
 didReceiveResponse: (NSURLResponse *)response;

/**
 * Called with the cachedResponse to be stored in the cache.
 * The delegate can inspect the cachedResponse and return a modified
 * copy if if wants changed to what whill be stored.<br />
 * If it returns nil, nothing will be stored in the cache.
 */
- (NSCachedURLResponse *) connection: (NSURLConnection *)connection
  willCacheResponse: (NSCachedURLResponse *)cachedResponse;

/**
 * Informs the delegate that the connection must change the URL of
 * the request in order to continue with the load operation.<br />
 * This allows the delegate to inspect and/or modify a copy of the request
 * before the connection continues loading it.  Normally the delegate
 * can return the request unmodifield.<br />
 * The redirection can be rejectected by the delegate calling -cancel
 * or returning nil.<br />
 * Cancelling the load will simply stop it, but returning nil will
 * cause it to complete with a redirection failure.<br />
 * As a special case, this method may be called with a nil response, // response 可能是 nil, 因为在刚开始的时候, 系统可能发觉request有问题, 然后进行了URL的修正.
 * indicating a change of URL made internally by the system rather than
 * due to a response from the server.
 */
- (NSURLRequest *) connection: (NSURLConnection *)connection
	      willSendRequest: (NSURLRequest *)request
	     redirectResponse: (NSURLResponse *)response;
@end

/**
 * An interface to perform synchronous loading of URL requests.
 */
@interface NSURLConnection (NSURLConnectionSynchronousLoading)

/**
 * Performs a synchronous load of request and returns the
 * [NSURLResponse] in response.<br />
 * Returns the result of the load or nil if the load failed.
 */
+ (NSData *) sendSynchronousRequest: (NSURLRequest *)request // 异步发送请求, 然后将 response 在输出参数中进行记录.
		  returningResponse: (NSURLResponse **)response
			      error: (NSError **)error;

@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif
