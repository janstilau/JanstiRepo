#import "common.h"

#define	EXPOSE_NSURLAuthenticationChallenge_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSError.h"

@implementation	NSURLAuthenticationChallenge

+ (id) allocWithZone: (NSZone*)z
{
  NSURLAuthenticationChallenge	*o = [super allocWithZone: z];

  return o;
}

- (void) dealloc
{
  [super dealloc];
}

- (NSError *) error
{
  return error;
}

- (NSURLResponse *) failureResponse
{
  return response;
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
      space = [space copy];
      credential = [credential copy];
      response = [response copy];
      error = [error copy];
      sender = RETAIN(sender);
      previousFailureCount = previousFailureCount;
    }
  return self;
}

- (NSInteger) previousFailureCount
{
  return previousFailureCount;
}

- (NSURLCredential *) proposedCredential
{
  return credential;
}

- (NSURLProtectionSpace *) protectionSpace
{
  return space;
}

- (id<NSURLAuthenticationChallengeSender>) sender
{
  return sender;
}

@end

