#import "common.h"
#define	EXPOSE_NSError_IVARS	1
#import	"Foundation/NSDictionary.h"
#import	"Foundation/NSError.h"
#import	"Foundation/NSCoder.h"

NSString* const NSFilePathErrorKey = @"NSFilePath";
NSString* const NSLocalizedDescriptionKey = @"NSLocalizedDescriptionKey";
NSString* const NSStringEncodingErrorKey = @"NSStringEncodingErrorKey";
NSString* const NSURLErrorKey = @"NSURLErrorKey";
NSString* const NSUnderlyingErrorKey = @"NSUnderlyingErrorKey";

NSString* const NSLocalizedFailureReasonErrorKey
  = @"NSLocalizedFailureReasonErrorKey";
NSString* const NSLocalizedRecoveryOptionsErrorKey
  = @"NSLocalizedRecoveryOptionsErrorKey";
NSString* const NSLocalizedRecoverySuggestionErrorKey
  = @"NSLocalizedRecoverySuggestionErrorKey";
NSString* const NSRecoveryAttempterErrorKey
  = @"NSRecoveryAttempterErrorKey";

NSString* const NSURLErrorFailingURLErrorKey = @"NSErrorFailingURLKey";
NSString* const NSURLErrorFailingURLStringErrorKey = @"NSErrorFailingURLStringKey";

NSString* const NSMACHErrorDomain = @"NSMACHErrorDomain";
NSString* const NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
NSString* const NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";
NSString* const NSCocoaErrorDomain = @"NSCocoaErrorDomain";

@implementation	NSError

+ (id) errorWithDomain: (NSString*)aDomain
		  code: (NSInteger)aCode
	      userInfo: (NSDictionary*)aDictionary
{
  NSError	*e = [self allocWithZone: NSDefaultMallocZone()];

  e = [e initWithDomain: aDomain code: aCode userInfo: aDictionary];
  return AUTORELEASE(e);
}

- (NSInteger) code
{
  return _code;
}

- (id) copyWithZone: (NSZone*)z
{
  NSError	*e = [[self class] allocWithZone: z];

  e = [e initWithDomain: _domain code: _code userInfo: _userInfo];
  return e;
}

- (void) dealloc
{
  DESTROY(_domain);
  DESTROY(_userInfo);
  [super dealloc];
}

- (NSString*) description
{
  return [self localizedDescription];
}

- (NSString*) domain
{
  return _domain;
}

- (id) init
{
  return [self initWithDomain: nil code: 0 userInfo: nil];
}

- (id) initWithDomain: (NSString*)aDomain
		 code: (NSInteger)aCode
	     userInfo: (NSDictionary*)aDictionary
{
  if (aDomain == nil)
    {
      NSLog(@"[%@-%@] with nil domain",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      DESTROY(self);
    }
  else if ((self = [super init]) != nil)
    {
      ASSIGN(_domain, aDomain);
      _code = aCode;
      ASSIGN(_userInfo, aDictionary);
    }
  return self;
}

- (NSString *) localizedDescription
{
  NSString	*desc = [_userInfo objectForKey: NSLocalizedDescriptionKey];

  if (desc == nil)
    {
      desc = [NSString stringWithFormat: @"%@ %d", _domain, _code];
    }
  return desc;
}

- (NSString *) localizedFailureReason
{
  return [_userInfo objectForKey: NSLocalizedFailureReasonErrorKey];
}

- (NSArray *) localizedRecoveryOptions
{
  return [_userInfo objectForKey: NSLocalizedRecoveryOptionsErrorKey];
}

- (NSString *) localizedRecoverySuggestion
{
  return [_userInfo objectForKey: NSLocalizedRecoverySuggestionErrorKey];
}

- (id) recoveryAttempter
{
  return [_userInfo objectForKey: NSRecoveryAttempterErrorKey];
}

- (NSDictionary*) userInfo
{
  return _userInfo;
}
@end

