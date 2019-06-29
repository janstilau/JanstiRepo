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

static IMP      takePath = 0;
static IMP      takeValue = 0;
static IMP      takePathKVO = 0;
static IMP      takeValueKVO = 0;

static void
SetValueForKey(NSObject *self, id anObject, const char *key, unsigned size)
{
    SEL		sel = 0;
    const char	*type = 0;
    int		off = 0;
    
    if (size > 0)
    {
        const char	*name;
        char		buf[size + 6];
        char		lo;
        char		hi;
        
        strncpy(buf, "_set", 4);
        strncpy(&buf[4], key, size);
        lo = buf[4];
        hi = islower(lo) ? toupper(lo) : lo;
        buf[4] = hi;
        buf[size + 4] = ':';
        buf[size + 5] = '\0';
        
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
                    buf[size + 4] = '\0';
                    buf[3] = '_';
                    buf[4] = lo;
                    name = &buf[3];	// _key
                    if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
                    {
                        buf[4] = hi;
                        buf[3] = 's';
                        buf[2] = 'i';
                        buf[1] = '_';
                        name = &buf[1];	// _isKey
                        if (GSObjCFindVariable(self,
                                               name, &type, &size, &off) == NO)
                        {
                            buf[4] = lo;
                            name = &buf[4];	// key
                            if (GSObjCFindVariable(self,
                                                   name, &type, &size, &off) == NO)
                            {
                                buf[4] = hi;
                                buf[3] = 's';
                                buf[2] = 'i';
                                name = &buf[2];	// isKey
                                GSObjCFindVariable(self,
                                                   name, &type, &size, &off);
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
    GSObjCSetVal(self, key, anObject, sel, type, size, off);
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

/**
 * Default is YES, If this method return No, KVC progress will not access instance variable if corresponding method is not found.
 */
+ (BOOL) accessInstanceVariablesDirectly
{
    return YES;
}


/**
 * Just call every valueForKey with a key. If the value is nil, insert [NSNull null] into the result dictionary.
 */
- (NSDictionary*) dictionaryWithValuesForKeys: (NSArray*)keys
{
    NSMutableDictionary	*dictionary;
    NSEnumerator		*enumerator;
    id			key;
    IMP	o = [NSObject instanceMethodForSelector:
             @selector(valuesForKeys:)];
    if ([self methodForSelector: @selector(valuesForKeys:)] != o)
    {
        /**
         * If subclass has its own imp for valuesForKeys, using it.
         */
        return [self valuesForKeys: keys];
    }
    
    dictionary = [NSMutableDictionary dictionaryWithCapacity: [keys count]];
    enumerator = [keys objectEnumerator];
    while ((key = [enumerator nextObject]) != nil)
    {
        id	value = [self valueForKey: key];
        
        if (value == nil)
        {
            value = [NSNull null];
        }
        [dictionary setObject: value forKey: key];
    }
    return dictionary;
}

- (void) setNilValueForKey: (NSString*)aKey
{
    /**
     * Default is to reise a exception. You can override to just make you app not creash, which is dangerous.
     */
    [NSException raise: NSInvalidArgumentException
                format: @"%@ -- %@ 0x%"PRIxPTR": Given nil value to set for key \"%@\"",
     NSStringFromSelector(_cmd), NSStringFromClass([self class]),
     (NSUInteger)self, aKey];
}


- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    unsigned	size = [aKey length] * 8;
    char		key[size + 1];
    IMP   	o = [self methodForSelector: @selector(takeValue:forKey:)];
    
    if (o != takeValue && o != takeValueKVO)
    {
        (*o)(self, @selector(takeValue:forKey:), anObject, aKey);
        return;
    }
    [aKey getCString: key
           maxLength: size + 1
            encoding: NSUTF8StringEncoding];
    size = strlen(key);
    SetValueForKey(self, anObject, key, size);
}


- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey
{
    NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];
    IMP	        o = [self methodForSelector: @selector(takeValue:forKeyPath:)];
    if (o != takePath && o != takePathKVO)
    {
        (*o)(self, @selector(takeValue:forKeyPath:), anObject, aKey);
        return;
    }
    
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


- (void) setValue: (id)anObject forUndefinedKey: (NSString*)aKey
{
    NSDictionary	*dict;
    NSException	*exp;
    dict = [NSDictionary dictionaryWithObjectsAndKeys:
            (anObject ? (id)anObject : (id)@"(nil)"), @"NSTargetObjectUserInfoKey",
            (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
            nil];
    exp = [NSException exceptionWithName: NSUndefinedKeyException
                                  reason: @"Unable to set value for undefined key"
                                userInfo: dict];
    [exp raise];
}


- (void) setValuesForKeysWithDictionary: (NSDictionary*)aDictionary
{
    NSEnumerator	*enumerator;
    NSString	*key;
    enumerator = [aDictionary keyEnumerator];
    while ((key = [enumerator nextObject]) != nil)
    {
        [self setValue: [aDictionary objectForKey: key] forKey: key];
    }
}


- (BOOL) validateValue: (id*)aValue
                forKey: (NSString*)aKey
                 error: (NSError**)anError
{
    unsigned	size;
    
    if (aValue == 0 || (size = [aKey length] * 8) == 0)
    {
        [NSException raise: NSInvalidArgumentException format: @"nil argument"];
    }
    else
    {
        char		name[size + 16];
        SEL		sel;
        BOOL		(*imp)(id,SEL,id*,id*);
        
        strncpy(name, "validate", 8);
        [aKey getCString: &name[8]
               maxLength: size + 1
                encoding: NSUTF8StringEncoding];
        size = strlen(&name[8]);
        strncpy(&name[size + 8], ":error:", 7);
        name[size + 15] = '\0';
        if (islower(name[8]))
        {
            name[8] = toupper(name[8]);
        }
        sel = sel_getUid(name);
        if (sel != 0 && [self respondsToSelector: sel] == YES)
        {
            imp = (BOOL (*)(id,SEL,id*,id*))[self methodForSelector: sel];
            return (*imp)(self, sel, aValue, anError);
        }
    }
    return YES;
}

- (BOOL) validateValue: (id*)aValue
            forKeyPath: (NSString*)aKey
                 error: (NSError**)anError
{
    NSRange       r = [aKey rangeOfString: @"." options: NSLiteralSearch];
    
    if (r.length == 0)
    {
        return [self validateValue: aValue forKey: aKey error: anError];
    }
    else
    {
        NSString	*key = [aKey substringToIndex: r.location];
        NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];
        
        return [[self valueForKey: key] validateValue: aValue
                                           forKeyPath: path
                                                error: anError];
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

@end

