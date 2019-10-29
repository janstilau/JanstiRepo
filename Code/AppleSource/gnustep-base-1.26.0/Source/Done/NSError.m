#import "common.h"
#define	EXPOSE_NSError_IVARS	1
#import	"Foundation/NSDictionary.h"
#import	"Foundation/NSError.h"
#import	"Foundation/NSCoder.h"

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

- (NSString *) localizedDescription // 仅仅是简单的 userInfo 的一个取值的过程.
{
    NSString *NSLocalizedDescriptionKey;
    NSString	*desc = [_userInfo objectForKey: NSLocalizedDescriptionKey];
    
    if (desc == nil)
    {
        desc = [NSString stringWithFormat: @"%@ %d", _domain, _code];
    }
    return desc;
}

- (NSString *) localizedFailureReason // 仅仅是简单的 userInfo 的一个取值的过程.
{
    NSString *NSLocalizedFailureReasonErrorKey;
    return [_userInfo objectForKey: NSLocalizedFailureReasonErrorKey];
}

- (NSArray *) localizedRecoveryOptions // 仅仅是简单的 userInfo 的一个取值的过程.
{
    return [_userInfo objectForKey: NSLocalizedRecoveryOptionsErrorKey];
}

- (NSString *) localizedRecoverySuggestion // 仅仅是简单的 userInfo 的一个取值的过程.
{
    return [_userInfo objectForKey: NSLocalizedRecoverySuggestionErrorKey];
}

- (id) recoveryAttempter // 仅仅是简单的 userInfo 的一个取值的过程.
{
    return [_userInfo objectForKey: NSRecoveryAttempterErrorKey];
}

- (NSDictionary*) userInfo
{
    return _userInfo;
}
@end

