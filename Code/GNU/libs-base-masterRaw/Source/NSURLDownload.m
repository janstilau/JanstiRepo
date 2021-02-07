#import "common.h"

#define	EXPOSE_NSURLDownload_IVARS	1
#import "GSURLPrivate.h"

@interface	GSURLDownload : NSObject <NSURLProtocolClient>
{
@public
  NSURLDownload		*_parent;	// Not retained
  NSURLRequest		*_request;
  NSURLProtocol		*_protocol;
  NSData		*_resumeData;
  NSString		*_path;
  id			_delegate;
  BOOL			_deletesFileUponFailure;
  BOOL			_allowOverwrite;
}
@end
 
#define	this	((GSURLDownload*)(self->_NSURLDownloadInternal))
#define	inst	((GSURLDownload*)(o->_NSURLDownloadInternal))

@implementation	NSURLDownload

+ (BOOL) canResumeDownloadDecodedWithEncodingMIMEType: (NSString *)MIMEType
{
  return NO;	// FIXME
}

- (void) dealloc
{
  RELEASE(this);
  [super dealloc];
}

- (void) cancel
{
  [this->_protocol stopLoading];
  DESTROY(this->_protocol);
}

- (BOOL) deletesFileUponFailure
{
  return this->_deletesFileUponFailure;
}

- (id) initWithRequest: (NSURLRequest *)request delegate: (id)delegate
{
  NSData	*resumeData = nil;
  return [self initWithResumeData: resumeData delegate: delegate path: nil];
}

- (id) initWithResumeData: (NSData *)resumeData
		 delegate: (id)delegate
		     path: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      this->_resumeData = [resumeData copy];
      this->_delegate = [delegate retain];
      this->_path = [path copy];
      // FIXME ... start connection
    }
  return self;
}

- (NSURLRequest *) request
{
  return this->_request;
}

- (NSData *) resumeData
{
  return nil;	// FIXME
}

- (void) setDeletesFileUponFailure: (BOOL)deletesFileUponFailure
{
  this->_deletesFileUponFailure = deletesFileUponFailure;
}

- (void) setDestination: (NSString *)path allowOverwrite: (BOOL)allowOverwrite
{
  ASSIGN(this->_path, path);
  this->_allowOverwrite = allowOverwrite;
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

- (void) dealloc
{
  RELEASE(_protocol);
  RELEASE(_resumeData);
  RELEASE(_request);
  RELEASE(_delegate);
  RELEASE(_path);
  [super dealloc];
}

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

