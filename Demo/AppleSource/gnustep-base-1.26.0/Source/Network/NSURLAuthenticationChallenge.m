#import "common.h"

#define	EXPOSE_NSURLAuthenticationChallenge_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSError.h"


// Internal data storage
typedef struct {
  NSURLProtectionSpace				*space;
  NSURLCredential				*credential;
  int						previousFailureCount;
  NSURLResponse					*response;
  NSError					*error;
  id<NSURLAuthenticationChallengeSender>	sender;
} Internal;
 
#define	this	((Internal*)(self->_NSURLAuthenticationChallengeInternal))

@implementation	NSURLAuthenticationChallenge

+ (id) allocWithZone: (NSZone*)z
{
  NSURLAuthenticationChallenge	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLAuthenticationChallengeInternal
        = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->space);
      RELEASE(this->credential);
      RELEASE(this->response);
      RELEASE(this->error);
      RELEASE(this->sender);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSError *) error
{
  return this->error;
}

- (NSURLResponse *) failureResponse
{
  return this->response;
}

- (id) initWithAuthenticationChallenge:
  (NSURLAuthenticationChallenge *)challenge
				sender:
  (id<NSURLAuthenticationChallengeSender>)sender
{
  return [self initWithProtectionSpace: [challenge protectionSpace]
		    proposedCredential: [challenge proposedCredential]
		  previousFailureCount: [challenge previousFailureCount]
		       failureResponse: [challenge failureResponse]
				 error: [challenge error]
				sender: sender];
}

- (id) initWithProtectionSpace: (NSURLProtectionSpace *)space
	    proposedCredential: (NSURLCredential *)credential
	  previousFailureCount: (NSInteger)previousFailureCount
	       failureResponse: (NSURLResponse *)response
			 error: (NSError *)error
			sender: (id<NSURLAuthenticationChallengeSender>)sender
{
  if ((self = [super init]) != nil)
    {
      this->space = [space copy];
      this->credential = [credential copy];
      this->response = [response copy];
      this->error = [error copy];
      this->sender = RETAIN(sender);
      this->previousFailureCount = previousFailureCount;
    }
  return self;
}

- (NSInteger) previousFailureCount
{
  return this->previousFailureCount;
}

- (NSURLCredential *) proposedCredential
{
  return this->credential;
}

- (NSURLProtectionSpace *) protectionSpace
{
  return this->space;
}

- (id<NSURLAuthenticationChallengeSender>) sender
{
  return this->sender;
}

@end

