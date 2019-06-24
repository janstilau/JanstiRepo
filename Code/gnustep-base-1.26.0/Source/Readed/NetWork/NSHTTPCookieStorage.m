#import "common.h"
#define	EXPOSE_NSHTTPCookieStorage_IVARS	1
#import "GSURLPrivate.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSString.h"
#import "Foundation/NSDistributedNotificationCenter.h"

NSString * const NSHTTPCookieManagerAcceptPolicyChangedNotification
= @"NSHTTPCookieManagerAcceptPolicyChangedNotification";

NSString * const NSHTTPCookieManagerCookiesChangedNotification
= @"NSHTTPCookieManagerCookiesChangedNotification";

NSString *objectObserver = @"org.GNUstep.NSHTTPCookieStorage";

@interface NSHTTPCookieStorage (Private)
- (void) _updateFromCookieStore;
@end

@implementation NSHTTPCookieStorage


+ (id) allocWithZone: (NSZone*)z
{
    return RETAIN([self sharedHTTPCookieStorage]);
}

+ (NSHTTPCookieStorage *) sharedHTTPCookieStorage
{
    static NSHTTPCookieStorage   *shareInstance = nil;
    if (shareInstance == nil)
    {
        [gnustep_global_lock lock]; // use the global_lock.
        if (shareInstance == nil)
        {
            NSHTTPCookieStorage	*o;
            [o init];
            shareInstance = o;
        }
        [gnustep_global_lock unlock];
    }
    return shareInstance;
}

- init
{
    _policy = NSHTTPCookieAcceptPolicyAlways;
    _cookies = [NSMutableArray new];
    [[NSDistributedNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(cookiesChangedNotification:)
     name: NSHTTPCookieManagerCookiesChangedNotification
     object: objectObserver];
    [[NSDistributedNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(acceptPolicyChangeNotification:)
     name: NSHTTPCookieManagerAcceptPolicyChangedNotification
     object: objectObserver];
    [self _updateFromCookieStore];
    return self;
}

// Just like business code.
- (NSString *) _cookieStorePath
{
    BOOL isDir;
    NSString *path;
    NSArray *dirs;
    
    dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                               NSUserDomainMask, YES);
    path = [[dirs objectAtIndex: 0] stringByAppendingPathComponent: @"Cookies"];
    if ([[NSFileManager defaultManager]
         fileExistsAtPath: path isDirectory: &isDir] == NO || isDir == NO)
    {
        BOOL ok;
        
        ok = [[NSFileManager defaultManager] createDirectoryAtPath: path
                                       withIntermediateDirectories: YES
                                                        attributes: nil
                                                             error: NULL];
        if (ok == NO)
            return nil;
    }
    path = [path stringByAppendingPathComponent: @"Cookies.plist"];
    return path;
}

/* Remove all cookies that have expired */
/* FIXME: When will we know that the user session expired? */
- (BOOL) _expireCookies: (BOOL)endUserSession
{
    BOOL changed = NO;
    NSDate *now = [NSDate date];
    unsigned count = [_cookies count];
    
    /* FIXME: Handle Max-age */
    while (count-- > 0)
    {
        NSHTTPCookie	*ck = [_cookies objectAtIndex: count];
        NSDate *expDate = [ck expiresDate];
        if ((endUserSession && expDate == nil) ||
            (expDate != nil && [expDate compare: now] != NSOrderedDescending))
        {
            [_cookies removeObject: ck];
            changed = YES;
        }
    }
    return changed;
}


// just like load data form disk. Get saved cookie and reload into memory.
// So the library make the same thing like business code.
- (void) _updateFromCookieStore
{
    int i;
    NSArray *properties;
    NSString *path = [self _cookieStorePath];
    
    if (path == nil)
    {
        return;
    }
    properties = nil;
    NS_DURING
    if (YES == [[NSFileManager defaultManager] fileExistsAtPath: path])
    {
        properties = [[NSString stringWithContentsOfFile: path] propertyList];
    }
    NS_HANDLER
    NSLog(@"NSHTTPCookieStorage: Error reading cookies plist");
    NS_ENDHANDLER
    if (nil == properties)
        return;
    for (i = 0; i < [properties count]; i++)
    {
        NSDictionary *props;
        NSHTTPCookie *cookie;
        
        props = [properties objectAtIndex: i];
        cookie = [NSHTTPCookie cookieWithProperties: props];
        if (NO == [_cookies containsObject: cookie])
        {
            [_cookies addObject:cookie];
        }
    }
}

- (void) _updateToCookieStore
{
    int i, count;
    NSMutableArray *properties;
    NSString *path = [self _cookieStorePath];
    
    if (path == nil)
    {
        return;
    }
    count = [_cookies count];
    properties = [NSMutableArray arrayWithCapacity: count];
    for (i = 0; i < count; i++)
        [properties addObject: [[_cookies objectAtIndex: i] properties]];
    [properties writeToFile: path atomically: YES];
}

- (void) _doExpireUpdateAndNotify
{
    [self _expireCookies: NO];
    [self _updateToCookieStore];
    [[NSDistributedNotificationCenter defaultCenter]
     postNotificationName: NSHTTPCookieManagerCookiesChangedNotification
     object: objectObserver];
}

- (void) cookiesChangedNotification: (NSNotification *)note
{
    if ([note object] == self)
        return;
    [self _updateFromCookieStore];
}

- (void) acceptPolicyChangeNotification: (NSNotification *)note
{
    if ([note object] == self)
        return;
    /* FIXME: Do we need a common place to store the policy? */
}

- (NSHTTPCookieAcceptPolicy) cookieAcceptPolicy
{
    return _policy;
}

- (NSArray *) cookies
{
    return [[_cookies copy] autorelease]; // copy for safe. The internal data will never be modified.
}

- (NSArray *) cookiesForURL: (NSURL *)URL
{
    NSMutableArray *a = [NSMutableArray array];
    NSEnumerator *ckenum = [_cookies objectEnumerator];
    NSHTTPCookie *cookie;
    NSString *receive_domain = [URL host];
    
    while ((cookie = [ckenum nextObject]))
    {
        if ([receive_domain hasSuffix: [cookie domain]])
            [a addObject: cookie];
    }
    return a;
}

- (void) deleteCookie: (NSHTTPCookie *)cookie
{
    if ([_cookies indexOfObject: cookie] != NSNotFound)
    {
        [_cookies removeObject: cookie];
        [self _doExpireUpdateAndNotify];
    }
    else
        NSLog(@"NSHTTPCookieStorage: trying to delete a cookie that is not in the storage");
}

- (void) _setCookieNoNotify: (NSHTTPCookie *)cookie
{
    NSEnumerator *ckenum = [_cookies objectEnumerator];
    NSHTTPCookie *ck, *remove_ck;
    NSString *name = [cookie name];
    NSString *path = [cookie path];
    NSString *domain = [cookie domain];
    
    NSAssert([cookie isKindOfClass: [NSHTTPCookie class]] == YES,
             NSInvalidArgumentException);
    
    remove_ck = nil;
    while ((ck = [ckenum nextObject]))
    {
        if ([name isEqual: [ck name]] && [path isEqual: [ck path]])
        {
            /* The Apple documentation says the domain should match and
             RFC 2965 says they should match, though the original Netscape docs
             doesn't mention that the domain should match, so here, if the
             version is explicitely set to 0, we don't require it */
            id ckv = [[ck properties] objectForKey: NSHTTPCookieVersion];
            if ((ckv && [ckv intValue] == 0) || [domain isEqual: [ck domain]])
            {
                remove_ck = ck;
                break;
            }
        }
    }
    if (remove_ck)
        [_cookies removeObject: remove_ck];
    
    [_cookies addObject: cookie];
}

- (void) setCookie: (NSHTTPCookie *)cookie
{
    if (_policy == NSHTTPCookieAcceptPolicyNever)
        return;
    [self _setCookieNoNotify: cookie];
    [self _doExpireUpdateAndNotify];
}

- (void) setCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{
    _policy = cookieAcceptPolicy;
    [[NSDistributedNotificationCenter defaultCenter]
     postNotificationName: NSHTTPCookieManagerAcceptPolicyChangedNotification
     object: objectObserver];
}

- (void) setCookies: (NSArray *)cookies
             forURL: (NSURL *)URL
    mainDocumentURL: (NSURL *)mainDocumentURL
{
    BOOL     changed = NO;
    unsigned count = [cookies count];
    
    if (count == 0 || _policy == NSHTTPCookieAcceptPolicyNever)
        return;
    
    while (count-- > 0)
    {
        NSHTTPCookie	*ck = [cookies objectAtIndex: count];
        
        if (_policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
            && [[URL host] hasSuffix: [mainDocumentURL host]] == NO)
            continue;
        
        [self _setCookieNoNotify: ck];
        changed = YES;
    }
    if (changed)
        [self _doExpireUpdateAndNotify];
}

@end

