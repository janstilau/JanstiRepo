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

static NSHTTPCookieStorage   *storage = nil;

+ (id) allocWithZone: (NSZone*)z
{
    return RETAIN([self sharedHTTPCookieStorage]);
}

+ (NSHTTPCookieStorage *) sharedHTTPCookieStorage
{
    if (storage == nil)
    {
        [gnustep_global_lock lock];
        [gnustep_global_lock unlock];
    }
    return storage;
}

- init
{
    self->_policy = NSHTTPCookieAcceptPolicyAlways;
    self->_cookieArrayM = [NSMutableArray new];
    [self _updateFromCookieStore]; // 从序列化文件中, 读取之前的 cookie 数据.
    return self;
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
    path = [path stringByAppendingPathComponent: @"Cookies.plist"]; // cookies 的这些信息, 存放到了一个 plist 文件中.
    return path;
}

- (BOOL) _expireCookies: (BOOL)endUserSession // 清理 cookie , 如果时间过期了, 这个方法会在每次进行存储删除的时候调用.
{
    BOOL changed = NO;
    NSDate *now = [NSDate date];
    unsigned count = [self->_cookieArrayM count];
    
    while (count-- > 0) // 这种变修改容器, 变改变 index 的方式, 只能是在对容器的内部实现比较了解的情况下才能使用.
    {
        NSHTTPCookie	*ck = [self->_cookieArrayM objectAtIndex: count];
        NSDate *expDate = [ck expiresDate];
        if ((endUserSession && expDate == nil) ||
            (expDate != nil && [expDate compare: now] != NSOrderedDescending))
        {
            [self->_cookieArrayM removeObject: ck];
            changed = YES;
        }
    }
    return changed;
}

- (void) _updateFromCookieStore
{
    int i;
    NSArray *properties; // 这里标明, cookies 是按照数组存放到了 plist 文件中的.
    NSString *path = [self _cookieStorePath];
    
    if (path == nil)
    {
        return;
    }
    properties = [[NSString stringWithContentsOfFile: path] propertyList];
    if (nil == properties)
        return;
    for (i = 0; i < [properties count]; i++)
    {
        NSDictionary *props;
        NSHTTPCookie *cookie;
        
        props = [properties objectAtIndex: i];
        cookie = [NSHTTPCookie cookieWithProperties: props];
        if (NO == [self->_cookieArrayM containsObject: cookie])
        {
            [self->_cookieArrayM addObject:cookie];
        }
    }
}

- (void) _updateToCookieStore // 每次进行 cookie 的修改, 都要进行这个的调用, 保持序列化的数据一致.
{
    int i, count;
    NSMutableArray *properties;
    NSString *path = [self _cookieStorePath];
    
    if (path == nil)
    {
        return;
    }
    count = [self->_cookieArrayM count];
    properties = [NSMutableArray arrayWithCapacity: count];
    for (i = 0; i < count; i++)
        [properties addObject: [[self->_cookieArrayM objectAtIndex: i] properties]];
    [properties writeToFile: path atomically: YES]; // 数组存储.
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
    return self->_policy;
}

- (NSArray *) cookies
{
    return [[self->_cookieArrayM copy] autorelease];
}

- (NSArray *) cookiesForURL: (NSURL *)URL // 就是遍历, 然后筛选现在存储的 cookie
{
    NSMutableArray *a = [NSMutableArray array];
    NSEnumerator *ckenum = [self->_cookieArrayM objectEnumerator];
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
    if ([self->_cookieArrayM indexOfObject: cookie] != NSNotFound)
    {
        [self->_cookieArrayM removeObject: cookie];
        [self _doExpireUpdateAndNotify];
    }
    else
        NSLog(@"NSHTTPCookieStorage: trying to delete a cookie that is not in the storage");
}

- (void) _setCookieNoNotify: (NSHTTPCookie *)cookie
{
    NSEnumerator *ckenum = [self->_cookieArrayM objectEnumerator];
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
        [self->_cookieArrayM removeObject: remove_ck];
    
    [self->_cookieArrayM addObject: cookie];
}

- (void) setCookie: (NSHTTPCookie *)cookie
{
    if (self->_policy == NSHTTPCookieAcceptPolicyNever)
        return;
    [self _setCookieNoNotify: cookie];
    [self _doExpireUpdateAndNotify];
}

- (void) setCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy
{
    self->_policy = cookieAcceptPolicy;
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
    
    if (count == 0 || self->_policy == NSHTTPCookieAcceptPolicyNever)
        return;
    
    while (count-- > 0)
    {
        NSHTTPCookie	*ck = [cookies objectAtIndex: count];
        
        if (self->_policy == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain &&
            [[URL host] hasSuffix: [mainDocumentURL host]] == NO){ // URL 不是mainDocumentURL的下级 url
            continue;
        }
        [self _setCookieNoNotify: ck];
        changed = YES;
    }
    if (changed)
        [self _doExpireUpdateAndNotify];
}

@end

