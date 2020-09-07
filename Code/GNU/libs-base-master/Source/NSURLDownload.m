#import "common.h"

#define	EXPOSE_NSURLDownload_IVARS	1
#import "GSURLPrivate.h"

/*
 GSURLDownload 还是用到了 NSURLProtocol 作为底层的实际的网络请求的支持.
 */
@interface	GSURLDownload : NSObject <NSURLProtocolClient>
{
@public
    NSURLDownload        *_parent;    // Not retained
    NSURLRequest        *_request;
    NSURLProtocol        *_protocol;
    NSData        *_resumeData;
    NSString        *_path;
    id            _delegate;
    BOOL            _deletesFileUponFailure;
    BOOL            _allowOverwrite;
}
@end
 
@implementation	NSURLDownload

+ (BOOL) canResumeDownloadDecodedWithEncodingMIMEType: (NSString *)MIMEType
{
  return NO;	// FIXME
}

- (void) cancel
{
  [self->_protocol stopLoading];
}

- (BOOL) deletesFileUponFailure
{
  return self->_deletesFileUponFailure;
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
  NSData	*resumeData = nil;

  return [self initWithResumeData: resumeData delegate: delegate path: nil];
}

/*
 这个类, 其实太重要的事没有做.
 */
- (id) initWithResumeData: (NSData *)resumeData
		 delegate: (id)delegate
		     path: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      self->_resumeData = [resumeData copy];
      self->_delegate = [delegate retain];
      self->_path = [path copy];
    }
  return self;
}

- (NSURLRequest *) request
{
  return self->_request;
}

- (NSData *) resumeData
{
  return nil;	// FIXME
}

- (void) setDeletesFileUponFailure: (BOOL)deletesFileUponFailure
{
  self->_deletesFileUponFailure = deletesFileUponFailure;
}

- (void) setDestination: (NSString *)path allowOverwrite: (BOOL)allowOverwrite
{
  ASSIGN(self->_path, path);
  self->_allowOverwrite = allowOverwrite;
}

@end

@implementation NSObject (NSURLDownloadDelegate)

- (void) downloadDidBegin: (NSURLDownload *)download
{
  return;
}

- (void) downloadDidFinish: (NSURLDownload *)download
{
  return;
}

- (void) download: (NSURLDownload *)download
 decideDestinationWithSuggestedFilename: (NSString *)filename
{
  return;
}

- (void) download: (NSURLDownload *)download
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  return;
}

- (void) download: (NSURLDownload *)download
  didCreateDestination: (NSString *)path
{
  return;
}

- (void) download: (NSURLDownload *)download didFailWithError: (NSError *)error
{
  return;
}

- (void) download: (NSURLDownload *)download
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  return;
}

- (void) download: (NSURLDownload *)download
  didReceiveDataOfLength: (NSUInteger)length
{
  return;
}

- (void) download: (NSURLDownload *)download
  didReceiveResponse: (NSURLResponse *)response
{
  return;
}

- (BOOL) download: (NSURLDownload *)download
  shouldDecodeSourceDataOfMIMEType: (NSString *)encodingType
{
  return NO;
}

- (void) download: (NSURLDownload *)download
  willResumeWithResponse: (NSURLResponse *)response
  fromByte: (long long)startingByte
{
  return;
}

- (NSURLRequest *) download: (NSURLDownload *)download
	    willSendRequest: (NSURLRequest *)request
	   redirectResponse: (NSURLResponse *)redirectResponse
{
  return request;
}

@end


@implementation	GSURLDownload

- (void) URLProtocol: (NSURLProtocol *)protocol
  cachedResponseIsValid: (NSCachedURLResponse *)cachedResponse
{
  return;
}

- (void) URLProtocol: (NSURLProtocol *)protocol
    didFailWithError: (NSError *)error
{
  [_delegate download: _parent didFailWithError: error];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
	 didLoadData: (NSData *)data
{
  return;
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [_delegate download: _parent didReceiveAuthenticationChallenge: challenge];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didReceiveResponse: (NSURLResponse *)response
  cacheStoragePolicy: (NSURLCacheStoragePolicy)policy
{
  [_delegate download: _parent didReceiveResponse: response];
  if (policy == NSURLCacheStorageAllowed
    || policy == NSURLCacheStorageAllowedInMemoryOnly)
    {
      
      // FIXME ... cache response here
    }
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  wasRedirectedToRequest: (NSURLRequest *)request
  redirectResponse: (NSURLResponse *)redirectResponse
{
  request = [_delegate download: _parent
		willSendRequest: request
	       redirectResponse: redirectResponse];
  // If we have been cancelled, our protocol will be nil
  if (_protocol != nil)
    {
      if (request == nil)
        {
	  [_delegate downloadDidFinish: _parent];
	}
      else
        {
	  DESTROY(_protocol);
	  // FIXME start new request loading
	}
    }
}

- (void) URLProtocolDidFinishLoading: (NSURLProtocol *)protocol
{
  [_delegate downloadDidFinish: _parent];
}

- (void) URLProtocol: (NSURLProtocol *)protocol
  didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
  [_delegate download: _parent didCancelAuthenticationChallenge: challenge];
}

@end

