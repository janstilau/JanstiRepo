#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"

/* For the NSKeyValueMutableArray and NSKeyValueMutableSet classes
 */
#include "NSKeyValueMutableArray.m"
#include "NSKeyValueMutableSet.m"

/* For backward compatibility NSUndefinedKeyException is actually the same
 * as the older NSUnknownKeyException
 */
NSString* const NSUnknownKeyException = @"NSUnknownKeyException";
NSString* const NSUndefinedKeyException = @"NSUnknownKeyException";


/* this should move into autoconf once it's accepted */
#define WANT_DEPRECATED_KVC_COMPAT 1

#ifdef WANT_DEPRECATED_KVC_COMPAT

static IMP      takePath = 0;
static IMP      takeValue = 0;
static IMP      takePathKVO = 0;
static IMP      takeValueKVO = 0;

static inline void setupCompat()
{
    if (takePath == 0)
    {
        Class  c = NSClassFromString(@"GSKVOBase");
        
        takePathKVO = [c instanceMethodForSelector:
                       @selector(takeValue:forKeyPath:)];
        takePath = [NSObject instanceMethodForSelector:
                    @selector(takeValue:forKeyPath:)];
        takeValueKVO = [c instanceMethodForSelector:
                        @selector(takeValue:forKey:)];
        takeValue = [NSObject instanceMethodForSelector:
                     @selector(takeValue:forKey:)];
    }
}

#endif

// 最重要的方法.
static void
SetValueForKey(NSObject *self, id targetValue, const char *key, unsigned keyLength)
{
    SEL		sel = 0;
    const char	*type = 0;
    int		off = 0;
    
    if (keyLength > 0)
    {
        const char	*name;
        char		buf[keyLength + 6];
        char		lo;
        char		hi;
        
        strncpy(buf, "_set", 4);
        strncpy(&buf[4], key, keyLength);
        lo = buf[4];
        hi = islower(lo) ? toupper(lo) : lo;
        buf[4] = hi;
        buf[keyLength + 4] = ':';
        buf[keyLength + 5] = '\0';
        
        name = &buf[1];	// setKey:
        type = NULL;
        sel = sel_getUid(name);
        if (sel == 0 || [self respondsToSelector: sel] == NO)
        {
            name = buf;	// _setKey:
            sel = sel_getUid(name);
            if (sel == 0 || [self respondsToSelector: sel] == NO)
            {
                sel = 0;
                if ([[self class] accessInstanceVariablesDirectly] == YES)
                {
                    buf[keyLength + 4] = '\0';
                    buf[3] = '_';
                    buf[4] = lo;
                    name = &buf[3];	// _key
                    if (GSObjCFindVariable(self, name, &type, &keyLength, &off) == NO)
                    {
                        buf[4] = hi;
                        buf[3] = 's';
                        buf[2] = 'i';
                        buf[1] = '_';
                        name = &buf[1];	// _isKey
                        if (GSObjCFindVariable(self,
                                               name, &type, &keyLength, &off) == NO)
                        {
                            buf[4] = lo;
                            name = &buf[4];	// key
                            if (GSObjCFindVariable(self,
                                                   name, &type, &keyLength, &off) == NO)
                            {
                                buf[4] = hi;
                                buf[3] = 's';
                                buf[2] = 'i';
                                name = &buf[2];	// isKey
                                GSObjCFindVariable(self,
                                                   name, &type, &keyLength, &off);
                            }
                        }
                    }
                }
            }
            else
            {
                GSOnceFLog(@"Key-value access using _setKey: is deprecated:");
            }
        }
    }
    GSObjCSetVal(self, key, targetValue, sel, type, keyLength, off);
}

static id ValueForKey(NSObject *self, const char *key, unsigned size)
{
    SEL		sel = 0;
    int		off = 0;
    const char	*type = NULL;
    
    if (size > 0)
    {
        const char	*name;
        char		buf[size + 5];
        char		lo;
        char		hi;
        
        strncpy(buf, "_get", 4);
        strncpy(&buf[4], key, size);
        buf[size + 4] = '\0';
        lo = buf[4];
        hi = islower(lo) ? toupper(lo) : lo;
        buf[4] = hi;
        
        name = &buf[1];	// getKey
        sel = sel_getUid(name);
        if (sel == 0 || [self respondsToSelector: sel] == NO)
        {
            buf[4] = lo;
            name = &buf[4];	// key
            sel = sel_getUid(name);
            if (sel == 0 || [self respondsToSelector: sel] == NO)
            {
                buf[4] = hi;
                buf[3] = 's';
                buf[2] = 'i';
                name = &buf[2];	// isKey
                sel = sel_getUid(name);
                if (sel == 0 || [self respondsToSelector: sel] == NO)
                {
                    sel = 0;
                }
            }
        }
        
        if (sel == 0 && [[self class] accessInstanceVariablesDirectly] == YES)
        {
            buf[4] = hi;
            name = buf;	// _getKey
            sel = sel_getUid(name);
            if (sel == 0 || [self respondsToSelector: sel] == NO)
            {
                buf[4] = lo;
                buf[3] = '_';
                name = &buf[3];	// _key
                sel = sel_getUid(name);
                if (sel == 0 || [self respondsToSelector: sel] == NO)
                {
                    sel = 0;
                }
            }
            if (sel == 0)
            {
                if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
                {
                    buf[4] = hi;
                    buf[3] = 's';
                    buf[2] = 'i';
                    buf[1] = '_';
                    name = &buf[1];	// _isKey
                    if (!GSObjCFindVariable(self, name, &type, &size, &off))
                    {
                        buf[4] = lo;
                        name = &buf[4];		// key
                        if (!GSObjCFindVariable(self, name, &type, &size, &off))
                        {
                            buf[4] = hi;
                            buf[3] = 's';
                            buf[2] = 'i';
                            name = &buf[2];	// isKey
                            GSObjCFindVariable(self, name, &type, &size, &off);
                        }
                    }
                }
            }
        }
    }
    return GSObjCGetVal(self, key, sel, type, size, off);
}


@implementation NSObject(KeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly
{
    return YES;
}


- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    unsigned	size = [aKey length] * 8;
    char		key[size + 1];
#ifdef WANT_DEPRECATED_KVC_COMPAT
    IMP   	o = [self methodForSelector: @selector(takeValue:forKey:)];
    
    setupCompat();
    if (o != takeValue && o != takeValueKVO)
    {
        (*o)(self, @selector(takeValue:forKey:), anObject, aKey);
        return;
    }
#endif
    
    [aKey getCString: key
           maxLength: size + 1
            encoding: NSUTF8StringEncoding];
    size = strlen(key);
    SetValueForKey(self, anObject, key, size);
}


- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey
{
    NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];
#ifdef WANT_DEPRECATED_KVC_COMPAT
    IMP	        o = [self methodForSelector: @selector(takeValue:forKeyPath:)];
    
    setupCompat();
    if (o != takePath && o != takePathKVO)
    {
        (*o)(self, @selector(takeValue:forKeyPath:), anObject, aKey);
        return;
    }
#endif
    
    if (r.length == 0)
    {
        [self setValue: anObject forKey: aKey];
    }
    else
    {
        NSString	*key = [aKey substringToIndex: r.location];
        NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];
        
        [[self valueForKey: key] setValue: anObject forKeyPath: path];
    }
}

- (id) valueForKey: (NSString*)aKey
{
    unsigned	size = [aKey length] * 8;
    char		key[size + 1];
    
    [aKey getCString: key
           maxLength: size + 1
            encoding: NSUTF8StringEncoding];
    size = strlen(key);
    return ValueForKey(self, key, size);
}


- (id) valueForKeyPath: (NSString*)aKey
{
    NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];
    
    if (r.length == 0)
    {
        return [self valueForKey: aKey];
    }
    else
    {
        NSString	*key = [aKey substringToIndex: r.location];
        NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];
        
        return [[self valueForKey: key] valueForKeyPath: path];
    }
}


- (id) valueForUndefinedKey: (NSString*)aKey
{
    NSDictionary	*dict;
    NSException	*exp;
    NSString      *reason;
#ifdef WANT_DEPRECATED_KVC_COMPAT
    static IMP	o = 0;
    
    /* Backward compatibility hack */
    if (o == 0)
    {
        o = [NSObject instanceMethodForSelector:
             @selector(handleQueryWithUnboundKey:)];
    }
    if ([self methodForSelector: @selector(handleQueryWithUnboundKey:)] != o)
    {
        return [self handleQueryWithUnboundKey: aKey];
    }
#endif
    dict = [NSDictionary dictionaryWithObjectsAndKeys:
            self, @"NSTargetObjectUserInfoKey",
            (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
            nil];
    reason = [NSString stringWithFormat:
              @"Unable to find value for key \"%@\" of object %@ (%@)",
              aKey, self, [self class]];
    exp = [NSException exceptionWithName: NSUndefinedKeyException
                                  reason: reason
                                userInfo: dict];
    
    [exp raise];
    return nil;
}

#endif

@end

