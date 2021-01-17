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

// Internal data storage
typedef struct {
    NSHTTPCookieAcceptPolicy	_policy;
    NSMutableArray		*_cookies;
} Internal;

#define	this	((Internal*)(self->_NSHTTPCookieStorageInternal))
#define	inst	((Internal*)(o->_NSHTTPCookieStorageInternal))

@interface NSHTTPCookieStorage (Private)
- (void) _updateFromCookieStore;
@end

@implementation NSHTTPCookieStorage

static NSHTTPCookieStorage   *storage = nil;

+ (NSHTTPCookieStorage *) sharedHTTPCookieStorage
{
    if (storage == nil)
    {
        [gnustep_global_lock lock];
        if (storage == nil)
        {
            NSHTTPCookieStorage	*o = nil;
            [o init];
            storage = o;
        }
        [gnustep_global_lock unlock];
    }
    return storage;
}

- init
{
    this->_policy = NSHTTPCookieAcceptPolicyAlways;
    this->_cookies = [NSMutableArray new];
    [self _updateFromCookieStore];
    return self;
}

- (void) dealloc
{
    if (this != 0)
    {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
        RELEASE(this->_cookies);
        NSZoneFree([self zone], this);
    }
    [super dealloc];
}

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
// 删除了过期的 cookie.
- (BOOL) _expireCookies: (BOOL)endUserSession
{
    BOOL changed = NO;
    NSDate *now = [NSDate date];
    unsigned count = [this->_cookies count];
    
    /* FIXME: Handle Max-age */
    while (count-- > 0)
    {
        NSHTTPCookie	*ck = [this->_cookies objectAtIndex: count];
        NSDate *expDate = [ck expiresDate];
        if ((endUserSession && expDate == nil) ||
            (expDate != nil && [expDate compare: now] != NSOrderedDescending))
        {
            [this->_cookies removeObject: ck];
            changed = YES;
        }
    }
    return changed;
}

// 这种 Storage, 就是在开始的时候, 从文件系统里面, 进行反序列化
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
    NS_ENDHANDLER
    if (nil == properties)
        return;
    // 读取出一个 Dict 来, 然后交给  cookie 进行初始化, 再把值装到自己的内部.
    for (i = 0; i < [properties count]; i++)
    {
        NSDictionary *props;
        NSHTTPCookie *cookie;
        
        props = [properties objectAtIndex: i];
        cookie = [NSHTTPCookie cookieWithProperties: props];
        if (NO == [this->_cookies containsObject: cookie])
        {
            [this->_cookies addObject:cookie];
        }
    }
}

// 把内容, 写会到文件系统里面.
- (void) _updateToCookieStore
{
    int i, count;
    NSMutableArray *properties;
    NSString *path = [self _cookieStorePath];
    
    if (path == nil)
    {
        return;
    }
    count = [this->_cookies count];
    properties = [NSMutableArray arrayWithCapacity: count];
    for (i = 0; i < count; i++)
    [properties addObject: [[this->_cookies objectAtIndex: i] properties]];
    [properties writeToFile: path atomically: YES];
}

- (void) _doExpireUpdateAndNotify
{
    [self _expireCookies: NO];
    [self _updateToCookieStore];
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
    return this->_policy;
}

- (NSArray *) cookies
{
    return [[this->_cookies copy] autorelease];
}

- (NSArray *) cookiesForURL: (NSURL *)URL
{
    NSMutableArray *a = [NSMutableArray array];
    NSEnumerator *ckenum = [this->_cookies objectEnumerator];
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
    if ([this->_cookies indexOfObject: cookie] != NSNotFound)
    {
        [this->_cookies removeObject: cookie];
        [self _doExpireUpdateAndNotify];
    }
    else
        NSLog(@"NSHTTPCookieStorage: trying to delete a cookie that is not in the storage");
}

- (void) _setCookieNoNotify: (NSHTTPCookie *)cookie
{
    NSEnumerator *ckenum = [this->_cookies objectEnumerator];
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
    // 先删了, 后加
    if (remove_ck)
        [this->_cookies removeObject: remove_ck];
    [this->_cookies addObject: cookie];
}

- (void) setCookie: (NSHTTPCookie *)cookie
{
    if (this->_policy == NSHTTPCookieAcceptPolicyNever)
        return;
    [self _setCookieNoNotify: cookie];
    [self _doExpireUpdateAndNotify];
}

- (void) setCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{
    this->_policy = cookieAcceptPolicy;
}

- (void) setCookies: (NSArray *)cookies
             forURL: (NSURL *)URL
    mainDocumentURL: (NSURL *)mainDocumentURL
{
    BOOL     changed = NO;
    unsigned count = [cookies count];
    
    if (count == 0 || this->_policy == NSHTTPCookieAcceptPolicyNever)
        return;
    
    while (count-- > 0)
    {
        NSHTTPCookie	*ck = [cookies objectAtIndex: count];
        
        if (this->_policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
            && [[URL host] hasSuffix: [mainDocumentURL host]] == NO)
            continue;
        
        [self _setCookieNoNotify: ck];
        changed = YES;
    }
    if (changed)
        [self _doExpireUpdateAndNotify];
}

@end

